# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

AppSweep is a native macOS (14+) app uninstaller written in SwiftUI, built as a plain Swift Package (no Xcode project). UI strings are Traditional Chinese.

## Commands

```bash
swift build                                   # debug build
swift run AppSweep                            # launch the app from source
swift test                                    # all tests (AppSweepCoreTests)
swift test --filter AppSweepCoreTests.ResidualScannerTests/testPathUtilsSafety   # single test
./bundle.sh                                   # release build → AppSweep.app + AppSweep.dmg (ad-hoc signed)
```

- `bundle.sh` regenerates the icon (`scripts/generate_icon.swift` → `Resources/AppIcon.iconset` → `.icns`), writes `Info.plist` inline (version strings live there: `CFBundleShortVersionString`), codesigns ad-hoc, and packages the DMG. `AppSweep.app`, `AppSweep.dmg`, and `.build/` are build outputs.
- Some tests (`testAppScanner`, `testLeftoverScannerDoesNotFlagInstalledApps`) read the real `/Applications` and `~/Library`, so results depend on the machine.

## Architecture

Two targets (see `Package.swift`):

- **`AppSweepCore`** (library, testable, no SwiftUI): models + services.
  - `AppScanner` — enumerates `/Applications`, `~/Applications`, `/System/Applications`, CoreServices apps; parses bundles, reads Spotlight metadata (last used date), detects arch by Mach-O header.
  - `ResidualScanner` — given one `AppInfo`, finds its related files in `~/Library` (caches, containers, prefs, etc.) as `ResidualItem`s tagged with `ResidualCategory`; system-app items are marked `isProtected`.
  - `LeftoverScanner` — finds orphaned `~/Library` data whose owner app is no longer installed, grouped into `LeftoverAppGroup` (matching by bundle ID / reverse-DNS tokens). Also owns `LeftoverSortOption`/`LeftoverFilterMode`.
  - `Uninstaller` — quits the running app, then moves selected items to Trash with a 3-tier fallback: `FileManager.trashItem` → manual move into `~/.Trash` → `NSAppleScript` `do shell script ... with administrator privileges`. Used both for full uninstall and "reset app" (residuals only, keep bundle).
  - `PathUtils.isSafeToDelete` — the single safety gate every deletion passes through (blocks root/system dirs and the top-level `~/Library/*` folders themselves). Any new deletion path must go through it; `testPathUtilsSafety` covers it.
  - All services are `actor`s; models are `Sendable`.
- **`AppSweep`** (executable, SwiftUI): `App/AppState.swift` is the single `@MainActor ObservableObject` holding all UI state (tabs, filters, sort, sheets, toasts) and owning the service actors; views in `Views/` read it. `NavigationTab`, `AppFilterMode`, `AppSortOption` are defined in `AppState.swift`. `Components/` is a custom design system (`Theme.swift` / `AppTheme`, custom segmented control, sort menus, checkbox, storage bar) used instead of native controls — reuse these when adding UI.

Business logic belongs in `AppSweepCore` so it stays testable; the UI target has no tests.
