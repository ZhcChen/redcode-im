import SwiftUI
import RedCodeFeatures

@MainActor
@main
struct RedCodeIOSApp: App {
    @State private var authController = AuthController.simulatorDevelopment()

    var body: some Scene {
        WindowGroup {
            AppRootView(authController: authController)
        }
    }
}
