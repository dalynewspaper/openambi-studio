import SwiftUI
import Intents

@main
struct OpenAmbiStudioApp: App {
    // Shared managers for the entire app
    @StateObject private var audioManager = AudioManager()
    @StateObject private var authManager = AuthManager()
    
    var body: some Scene {
        WindowGroup {
            // App is always accessible - authentication is optional
            ZStack {
                // Root background - extends fully to all edges including safe areas
                AppTheme.background
                    .ignoresSafeArea(.all)
                
                ContentView()
                    .environmentObject(audioManager)
                    .environmentObject(authManager)
                    .onContinueUserActivity("INPlayMediaIntent") { userActivity in
                        // Handle Siri shortcut to play
                        OpenAmbiShortcuts.handleShortcut("toggle", audioManager: audioManager)
                    }
            }
        }
    }
}
