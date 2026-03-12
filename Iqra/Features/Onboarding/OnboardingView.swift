import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    
    private let steps: [OnboardingStep] = [
        OnboardingStep(
            icon: "rotate.right",
            title: "اقلب جوالك",
            subtitle: "Turn your phone landscape",
            body: "ضع جوالك بالعرض أمامك في مكان سجودك، الشاشة للأعلى."
        ),
        OnboardingStep(
            icon: "mic.fill",
            title: "استمع مع الإمام",
            subtitle: "Listen with the Imam",
            body: "التطبيق يستمع للقراءة تلقائياً ويعرض الترجمة فوراً."
        ),
        OnboardingStep(
            icon: "text.aligncenter",
            title: "افهم كلام الله",
            subtitle: "Understand Allah's words",
            body: "الترجمة تظهر بهدوء مع كل آية. لا شيء آخر. فقط المعنى."
        ),
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Step content
                VStack(spacing: 32) {
                    Image(systemName: steps[currentStep].icon)
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundColor(.white)
                        .animation(.easeInOut, value: currentStep)
                    
                    VStack(spacing: 10) {
                        Text(steps[currentStep].title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text(steps[currentStep].subtitle)
                            .font(.system(size: 15, weight: .light))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(1.5)
                            .textCase(.uppercase)
                    }
                    
                    Text(steps[currentStep].body)
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                        .padding(.horizontal, 40)
                }
                .transition(.opacity)
                .id(currentStep)
                
                Spacer()
                
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == currentStep ? Color.white : Color.white.opacity(0.2))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.bottom, 36)
                
                // Button
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if currentStep < steps.count - 1 {
                            currentStep += 1
                        } else {
                            appState.completeOnboarding()
                        }
                    }
                } label: {
                    Text(currentStep < steps.count - 1 ? "التالي" : "ابدأ")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 32)
                }
                .padding(.bottom, 52)
            }
        }
    }
}

struct OnboardingStep {
    let icon: String
    let title: String
    let subtitle: String
    let body: String
}