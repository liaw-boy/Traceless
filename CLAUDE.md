# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Traceless (formerly AppSweep, briefly Uproot) is a native macOS (14+) app uninstaller written in SwiftUI, built as a plain Swift Package (no Xcode project). UI strings are Traditional Chinese.

## Commands

```bash
swift build                                   # debug build
swift run Traceless                              # launch the app from source
swift test                                    # all tests (TracelessCoreTests)
swift test --filter TracelessCoreTests.SafetyRulesTests/testLaunchAgentMatching   # single test
./bundle.sh                                   # release build → Traceless.app + Traceless.dmg (ad-hoc signed)
```

- `bundle.sh` regenerates the icon (`scripts/generate_icon.swift` → `Resources/AppIcon.iconset` → `.icns`), writes `Info.plist` inline (version from `VERSION`; build number derived from it, e.g. 1.1.0 → 10100, because Sparkle compares it), embeds and re-signs `Sparkle.framework` inside-out, strips symbols and refuses to package if the app contains this Mac's home path or user name, then makes the DMG. Hardened runtime is only enabled with a real `SIGN_IDENTITY`: ad-hoc code has no Team ID, so library validation would stop the app loading Sparkle.
- Auto-update is Sparkle 2.10.0 (`App/Updater.swift`, menu 檢查更新…). Feed: `releases/latest/download/appcast.xml`; `SURequireSignedFeed` + `SUVerifyUpdateBeforeExtraction`. The EdDSA private key is only in the release Mac's login keychain (account `traceless`); the public key is in `bundle.sh`. Losing the private key means existing installs can never be updated again.
- Release: bump `VERSION` + `CHANGELOG.md` (`## x.y.z` with `- ` bullets become the update notes), commit, `scripts/release.sh` → `dist/`, then `gh release create vX.Y.Z dist/*`. `TRACELESS_LOCAL_TEST=1` with `SPARKLE_FEED_URL` / `VERSION_OVERRIDE` builds a test app for exercising updates. `Traceless.app`, `*.dmg`, `Resources/AppIcon.*` and `.build/` are git-ignored build outputs. Record user-visible changes in `CHANGELOG.md` and bump `VERSION` when releasing.
- Some tests (`testAppScanner`, `testLeftoverScannerDoesNotFlagInstalledApps`) read the real `/Applications` and `~/Library`, so results depend on the machine.
- Icon is drawn in code by `scripts/generate_icon.swift`: an app tile dissolving into smaller squares, solid white on graphite, simplified fragments at ≤64 px. Preview a dark-mode render with `--dark`.

## Architecture

Two targets (see `Package.swift`):

- **`TracelessCore`** (library, testable, no SwiftUI): models + services.
  - `AppScanner` — enumerates `/Applications`, `~/Applications`, `/System/Applications`, CoreServices apps; parses bundles, reads Spotlight metadata (last used date), detects arch by Mach-O header.
  - `ResidualScanner` — given one `AppInfo`, finds its related files in `~/Library` (caches, containers, prefs, etc.) as `ResidualItem`s tagged with `ResidualCategory`; system-app items are marked `isProtected`.
  - `LeftoverScanner` — finds orphaned `~/Library` data whose owner app is no longer installed, grouped into `LeftoverAppGroup` (matching by bundle ID / reverse-DNS tokens). Also owns `LeftoverSortOption`/`LeftoverFilterMode`.
  - `SystemInspector` — read-only findings macOS won't let us delete: orphaned system extensions (parses `systemextensionsctl list`) and ghost processes (running bundles whose app is gone, or Library helpers whose vendor has no installed app). Ownership of system-level bundles is decided by `CodeSignature` (Team ID + vendor prefix), not by name.
  - `DriverInventory` — powers the 驅動與背景 page: every third-party kext, HAL driver, framework, launchd job, privileged helper, system extension and ghost process as a `DriverItem` with a plain-language `Kind`, owner app (Team ID first, then vendor prefix) and a `Removal` (trash / settings-only / quit).
  - `Uninstaller` — quits the running app, then moves selected items to Trash: `FileManager.trashItem` → move into `~/.Trash` (unique name) → for paths outside home only, one batched `osascript` admin prompt. Paths go through AppleScript `quoted form of`; `SafetyRulesTests` runs the generated script against hostile filenames — keep that test passing if you touch it.
  - `PathUtils.isSafeToDelete` — the single safety gate every deletion passes through (blocks root/system dirs and the top-level `~/Library/*` folders themselves). Any new deletion path must go through it; `PathSafetyTests` and `testPathUtilsSafety` cover it.
  - Matching rules are `static` pure functions (`launchAgentMatches`, `groupContainerMatches`, `launchdJobBelongs`, `AppScanner.shouldSkipSpotlightPath`) so they can be unit-tested without touching the real `~/Library`.
  - All services are `actor`s; models are `Sendable`.
- **`Traceless`** (executable, SwiftUI): `App/AppState.swift` is the single `@MainActor ObservableObject` holding all UI state (tabs, filters, sort, sheets, toasts) and owning the service actors; views in `Views/` read it. `NavigationTab`, `AppFilterMode`, `AppSortOption` are defined in `AppState.swift`. UI has its own design system in `Components/Theme.swift`: `Palette` (dynamic light/dark colours — graphite monochrome: `accent` is near-black in light and near-white in dark, so anything drawn on it uses `onAccent`; red `brick` is reserved for destructive actions), `Font.display` (SF Rounded for names and numbers), `TraceMark` (the icon motif drawn with `Canvas`, same geometry as `scripts/generate_icon.swift`), `Checkbox` (flat, with mixed state), `FilterChips`, `SolidButtonStyle`, `QuietButtonStyle`. Use these instead of stock controls; no gradients or glow. The sidebar must stay a `List`, and the detail column is wrapped in `BelowToolbar` (MainView): on macOS 26 `NavigationSplitView` sometimes lays columns out from the window top while reporting a 52 pt top inset, so the wrapper pads by the reported inset. Keep action-bar labels `.lineLimit(1)`. Appearance (system/light/dark) is `AppearanceMode`, applied via `NSApp.appearance`.

Business logic belongs in `TracelessCore` so it stays testable; the UI target has no tests.
