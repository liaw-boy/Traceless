import SwiftUI

@main
struct AppSweepApp: App {
    var body: some Scene {
        WindowGroup("AppSweep") {
            MainView()
                .frame(minWidth: 980, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()
        }
    }
}
