import SwiftUI

struct TranslationView: View {
    let ayah: Ayah
    
    var body: some View {
        VStack(spacing: 18) {
            // Surah label
            Text("\(ayah.surahName)  ·  \(ayah.ayah)")
                .font(.system(size: 11, weight: .light))
                .foregroundColor(.white.opacity(0.3))
                .tracking(2)
                .textCase(.uppercase)
            
            // Translation
            Text(ayah.translation)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(8)
                .padding(.horizontal, 32)
        }
    }
}