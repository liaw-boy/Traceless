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

- `bundle.sh` regenerates the icon (`scripts/generate_icon.swift` → `Resources/AppIcon.iconset` → `.icns`), writes `Info.plist` inline with the version from `VERSION` and build number = git commit count, codesigns ad-hoc, and packages the DMG. `Traceless.app`, `*.dmg`, `Resources/AppIcon.*` and `.build/` are git-ignored build outputs. Record user-visible changes in `CHANGELOG.md` and bump `VERSION` when releasing.
- Some tests (`testAppScanner`, `testLeftoverScannerDoesNotFlagInstalledApps`) read the real `/Applications` and `~/Library`, so results depend on the machine.
- Icon is drawn in code by `scripts/generate_icon.swift`: an app tile dissolving into smaller squares, solid white on graphite, simplified fragments at ≤64 px. Preview a dark-mode render with `--dark`.

## Architecture

Two targets (see `Package.swift`):

- **`TracelessCore`** (library, testable, no SwiftUI): models + services.
  - `AppScanner` — enumerates `/Applications`, `~/Applications`, `/System/Applications`, CoreServices apps; parses bundles, reads Spotlight metadata (last used date), detects arch by Mach-O header.
  - `ResidualScanner` — given one `AppInfo`, finds its related files in `~/Library` (caches, containers, prefs, etc.) as `ResidualItem`s tagged with `ResidualCategory`; system-app items are marked `isProtected`.
  - `LeftoverScanner` — finds orphaned `~/Library` data whose owner app is no longer installed, grouped into `LeftoverAppGroup` (matching by bundle ID / reverse-DNS tokens). Also owns `LeftoverSortOption`/`LeftoverFilterMode`.
  - `Uninstaller` — quits the running app, then moves selected items to Trash: `FileManager.trashItem` → move into `~/.Trash` (unique name) → for paths outside home only, one batched `osascript` admin prompt. Paths go through AppleScript `quoted form of`; `SafetyRulesTests` runs the generated script against hostile filenames — keep that test passing if you touch it.
  - `PathUtils.isSafeToDelete` — the single safety gate every deletion passes through (blocks root/system dirs and the top-level `~/Library/*` folders themselves). Any new deletion path must go through it; `PathSafetyTests` and `testPathUtilsSafety` cover it.
  - Matching rules are `static` pure functions (`launchAgentMatches`, `groupContainerMatches`, `launchdJobBelongs`, `AppScanner.shouldSkipSpotlightPath`) so they can be unit-tested without touching the real `~/Library`.
  - All services are `actor`s; models are `Sendable`.
- **`Traceless`** (executable, SwiftUI): `App/AppState.swift` is the single `@MainActor ObservableObject` holding all UI state (tabs, filters, sort, sheets, toasts) and owning the service actors; views in `Views/` read it. `NavigationTab`, `AppFilterMode`, `AppSortOption` are defined in `AppState.swift`. UI has its own design system in `Components/Theme.swift`: `Palette` (dynamic light/dark colours — graphite monochrome: `accent` is near-black in light and near-white in dark, so anything drawn on it uses `onAccent`; red `brick` is reserved for destructive actions), `Font.display` (SF Rounded for names and numbers), `TraceMark` (the icon motif drawn with `Canvas`, same geometry as `scripts/generate_icon.swift`), `Checkbox` (flat, with mixed state), `FilterChips`, `SolidButtonStyle`, `QuietButtonStyle`. Use these instead of stock controls; no gradients or glow. The sidebar must stay a `List`: with a plain stack, `NavigationSplitView` on macOS 26 laid every column out under the toolbar.

Business logic belongs in `TracelessCore` so it stays testable; the UI target has no tests.
