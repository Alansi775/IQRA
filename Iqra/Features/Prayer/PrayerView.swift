import SwiftUI

struct PrayerView: View {
    @StateObject private var vm = PrayerViewModel()
    @State private var showExplanation = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                // Language selector (top)
                HStack {
                    Menu {
                        Button("العربية") { vm.selectedLanguage = "arabic" }
                        Button("Türkçe") { vm.selectedLanguage = "turkish" }
                        Button("English") { vm.selectedLanguage = "english" }
                        Button("Français") { vm.selectedLanguage = "french" }
                        Button("Deutsch") { vm.selectedLanguage = "german" }
                        Button("اردو") { vm.selectedLanguage = "urdu" }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "globe")
                                .font(.system(size: 14, weight: .light))
                            Text(languageDisplay())
                                .font(.system(size: 13, weight: .light))
                        }
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(8)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Recognized text (small, subtle)
                if !vm.recognizedText.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("قال الإمام:")
                            .font(.system(size: 11, weight: .light))
                            .foregroundColor(.white.opacity(0.3))
                        Text(vm.recognizedText)
                            .font(.system(size: 14, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(12)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(8)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                
                Spacer()
                
                // EXPLANATION ONLY - HUGE TEXT, CENTERED
                if !vm.explanation.isEmpty {
                    VStack(alignment: .center, spacing: 0) {
                        Text(vm.explanation)
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundColor(.white)
                            .lineSpacing(12)
                            .multilineTextAlignment(.center)
                            .padding(32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.clear)
                    .transition(.opacity)
                    .onAppear {
                        withAnimation(.easeIn(duration: 0.5)) {
                            showExplanation = true
                        }
                    }
                } else {
                    // Idle state
                    VStack(spacing: 12) {
                        Text("اقرأ")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundColor(.white.opacity(0.15))
                        if vm.isListening {
                            Text("listening...")
                                .font(.system(size: 12, weight: .light))
                                .foregroundColor(.white.opacity(0.2))
                                .tracking(2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.opacity)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    // Stop button
                    if vm.isListening {
                        Button {
                            Task { await vm.toggleListening() }
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white.opacity(0.4))
                                .frame(width: 52, height: 52)
                                .background(Color.white.opacity(0.06))
                                .clipShape(Circle())
                        }
                    }
                    
                    // Main microphone button
                    Button {
                        Task { await vm.toggleListening() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(vm.isListening ? Color.white : Color.white.opacity(0.2))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: vm.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(vm.isListening ? .black : .white.opacity(0.7))
                        }
                    }
                    
                    // Placeholder for symmetry
                    if vm.isListening {
                        Color.clear.frame(width: 52, height: 52)
                    }
                }
                .padding(.bottom, 52)
            }
            
            // Error toast
            if let error = vm.errorMessage {
                VStack {
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.top, 60)
                    Spacer()
                }
            }
        }
    }
    
    private func languageDisplay() -> String {
        switch vm.selectedLanguage {
        case "arabic": return "العربية"
        case "turkish": return "Türkçe"
        case "english": return "English"
        case "french": return "Français"
        case "german": return "Deutsch"
        case "urdu": return "اردو"
        default: return "العربية"
        }
    }
}
