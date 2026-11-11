import SwiftUI

@main
struct AppSweepApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
                .frame(minWidth: 1060, idealWidth: 1200, maxWidth: .infinity, minHeight: 680, idealHeight: 760, maxHeight: .infinity)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
