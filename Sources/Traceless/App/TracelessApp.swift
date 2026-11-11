import SwiftUI

@main
struct TracelessApp: App {
    @StateObject private var state = AppState()
    private let updater = AppUpdater()
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppearanceMode.storageKey) private var appearance: AppearanceMode = .system

    var body: some Scene {
        WindowGroup("Traceless") {
            MainView(state: state)
                .frame(minWidth: 1000, minHeight: 640)
                .onAppear { appearance.apply() }
                .onChange(of: appearance) { _, new in new.apply() }
        }
        .defaultSize(width: 1200, height: 780)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("關於 Traceless") { openWindow(id: "about") }
                Button("檢查更新…") { updater.checkForUpdates() }
                    .disabled(!updater.isAvailable)
            }
            SidebarCommands()
            CommandGroup(after: .sidebar) {
                Picker("外觀", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            CommandGroup(before: .sidebar) {
                ForEach(Array(NavigationTab.allCases.enumerated()), id: \.element) { index, tab in
                    Button(tab.rawValue) { state.activeTab = tab }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
            }
        }

        Settings {
            SettingsView()
        }

        Window("關於 Traceless", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}
