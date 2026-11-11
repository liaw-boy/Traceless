import SwiftUI

@main
struct UprootApp: App {
    @StateObject private var state = AppState()

    var body: some Scene {
        WindowGroup("Uproot") {
            MainView(state: state)
                .frame(minWidth: 980, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
            CommandGroup(before: .sidebar) {
                ForEach(Array(NavigationTab.allCases.enumerated()), id: \.element) { index, tab in
                    Button(tab.rawValue) { state.activeTab = tab }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
            }
        }
    }
}
