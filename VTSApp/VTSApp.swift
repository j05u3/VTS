import SwiftUI

@main
struct VTSApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 500, height: 800)
    }
}