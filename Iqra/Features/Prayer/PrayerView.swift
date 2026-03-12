import SwiftUI

struct PrayerView: View {
    @StateObject private var vm = PrayerViewModel()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Recognized text
                if !vm.recognizedText.isEmpty {
                    VStack(alignment: .trailing, spacing: 8) {
                        Text("قال الإمام:")
                            .font(.system(size: 12, weight: .light))
                            .foregroundColor(.white.opacity(0.5))
                        Text(vm.recognizedText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(16)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
                
                // Translation area
                if let ayah = vm.currentAyah {
                    TranslationView(ayah: ayah)
                        .id(ayah.surah * 1000 + ayah.ayah)
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
                }
                
                // Explanation - Large, centered, and prominent
                if !vm.explanation.isEmpty {
                    VStack(alignment: .center, spacing: 12) {
                        Text(vm.explanation)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                            .lineSpacing(6)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                    .background(Color.clear)
                }
                
                Spacer()
                
                // Controls
                HStack(spacing: 40) {
                    // Stop / Reset
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
                    
                    // Main button
                    Button {
                        Task { await vm.toggleListening() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(vm.isListening ? Color.white : Color.white)
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: vm.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 24, weight: .light))
                                .foregroundColor(.black)
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
}
