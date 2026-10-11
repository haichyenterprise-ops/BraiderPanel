import SwiftUI
import FirebaseCore

@main
struct BraiderPanelApp: App {

    @StateObject private var session = SessionManager.shared

    init() {
        FirebaseApp.configure()
        print("[BraiderPanel] Firebase configured: \(FirebaseApp.app() != nil)")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .preferredColorScheme(.light)
        }
    }
}