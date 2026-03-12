import SwiftUI

@main
struct IqraApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            Group {
                switch appState.currentScreen {
                case .onboarding:
                    OnboardingView()
                case .prayer:
                    PrayerView()
                }
            }
            .environmentObject(appState)
            .preferredColorScheme(.dark)
        }
    }
}