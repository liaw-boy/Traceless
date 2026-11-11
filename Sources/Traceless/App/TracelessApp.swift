import SwiftUI

@main
struct TracelessApp: App {
    @StateObject private var state = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup("Traceless") {
            MainView(state: state)
                .frame(minWidth: 1000, minHeight: 640)
        }
        .defaultSize(width: 1200, height: 780)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("關於 Traceless") { openWindow(id: "about") }
            }
            SidebarCommands()
            CommandGroup(before: .sidebar) {
                ForEach(Array(NavigationTab.allCases.enumerated()), id: \.element) { index, tab in
                    Button(tab.rawValue) { state.activeTab = tab }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
            }
        }

        Window("關於 Traceless", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
    }
}
