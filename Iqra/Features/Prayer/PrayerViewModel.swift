import SwiftUI

@MainActor
final class PrayerViewModel: ObservableObject {
    @Published var isListening = false
    @Published var currentAyah: Ayah?
    @Published var recognizedText = ""
    @Published var explanation = ""
    @Published var errorMessage: String?
    
    private let audioService = AudioService()
    private let groqService = GroqService(apiKey: Config.groqAPIKey)
    private let quranService = QuranService.shared
    
    private var lastProcessedAyahId: String = "" // Prevent duplicate Groq calls
    
    func toggleListening() async {
        if isListening {
            stop()
        } else {
            await start()
        }
    }
    
    private func start() async {
        let granted = await audioService.requestPermission()
        guard granted else {
            errorMessage = "يحتاج التطبيق إذن الميكروفون"
            return
        }
        
        // Called when text is recognized from audio
        audioService.onTextRecognized = { [weak self] text in
            Task { await self?.processRecognizedText(text) }
        }
        
        do {
            try audioService.startListening()
            isListening = true
            recognizedText = ""
            explanation = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func stop() {
        audioService.stopListening()
        isListening = false
    }
    
    private func processRecognizedText(_ text: String) async {
        recognizedText = text
        print("📝 Processing text: \(text)")
        
        do {
            // SMART TEXT WINDOW: Focus on LAST 8 words (current verse recognition)
            // Since speech continuously recognizes, new words are added at the end
            // This ensures we find the CURRENT verse being recited, not old accumulated text
            let words = text.split(separator: " ").map { String($0) }
            let textWindow = words.suffix(8).joined(separator: " ")
            let searchText = textWindow.isEmpty ? text : textWindow
            
            print("🔍 Search window: \(searchText)")
            
            // Step 1: Search for the verse in Quran using API
            if let ayah = try await quranService.searchVerse(text: searchText) {
                let ayahId = "\(ayah.surah)-\(ayah.ayah)"
                
                // Always update UI with the found ayah
                withAnimation(.easeInOut(duration: 0.5)) {
                    currentAyah = ayah
                    print("✅ Found ayah: Surah \(ayah.surah), Ayah \(ayah.ayah)")
                }
                
                // CRITICAL: Clear recognized text IMMEDIATELY (not in animation)
                // to prevent accumulation when the imam moves to next verse
                recognizedText = ""
                
                // Calculate word count from ORIGINAL text (for Groq threshold)
                let wordCount = text.split(separator: " ").count
                print("📊 Word count: \(wordCount)")
                
                if wordCount >= 3 && ayahId != lastProcessedAyahId {
                    print("✅ Sending complete verse to Groq (>= 3 words)")
                    lastProcessedAyahId = ayahId
                    
                    // Step 2: Send verse TEXT to Groq for dynamic explanation
                    let explainPrompt = """
                    أنت معلم قرآني بليغ. ساعد المصلي في الصلاة أن يفهم هذه الآية في جملة واحدة قصيرة جداً (أقل من 15 كلمة).
                    ركز على المعنى الجوهري والشعور الروحي، ليس التفاصيل.
                    
                    الآية: \(ayah.arabic)
                    """
                    
                    let explain = try await groqService.explainVerse(prompt: explainPrompt)
                    let explanationText = String(explain)  // Explicit String conversion
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        explanation = explanationText
                        print("✅ Groq explanation: \(explanationText)")
                    }
                } else if wordCount < 3 {
                    print("⏳ Partial verse (< 3 words) - waiting for complete verse before Groq")
                    explanation = "" // Clear explanation while waiting for complete verse
                } else {
                    print("♻️  Same ayah (ID: \(ayahId)) - reusing cached explanation")
                }
            } else {
                print("❌ Could not find matching verse")
            }
        } catch {
            print("❌ Error processing text: \(error)")
            errorMessage = "خطأ في معالجة الآية"
        }
    }
}