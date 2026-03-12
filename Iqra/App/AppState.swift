import SwiftUI

enum AppScreen {
    case onboarding
    case prayer
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen
    
    init() {
        let hasSeenOnboarding = UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
        self.currentScreen = hasSeenOnboarding ? .prayer : .onboarding
    }
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation(.easeInOut) {
            currentScreen = .prayer
        }
    }
}