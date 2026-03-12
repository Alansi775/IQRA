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
            // Calculate word count for threshold check
            let wordCount = text.split(separator: " ").count
            print("📊 Word count: \(wordCount)")
            
            // Skip processing if text is too short
            guard wordCount >= 2 else {
                print("⏳ Waiting for more words...")
                return
            }
            
            // AI-powered verse identification
            // Let LLM guess which verse, get explanation, and prepare for next verse
            print("🧠 Using AI to identify verse...")
            
            let identification = try await groqService.identifyVerseAndExplain(recognizedText: text)
            
            guard !identification.surahName.isEmpty && !identification.ayahNumber.isEmpty else {
                print("⚠️  LLM could not identify verse")
                return
            }
            
            // Create display text from LLM identification
            let displaySurah = identification.surahName
            let displayAyah = identification.ayahNumber
            let displayExplanation = identification.explanation
            let nextVerse = identification.nextVerse
            
            print("✅ Identified: \(displaySurah) \(displayAyah)")
            print("📖 Next verse: \(nextVerse)")
            
            let ayahId = "\(displaySurah)-\(displayAyah)"
            
            // Update UI with identified verse
            currentAyah = Ayah(
                surah: 0,  // Placeholder
                ayah: 0,   // Placeholder
                arabic: displaySurah,  // Display surah name
                translation: nextVerse,  // Show next verse as translation
                surahName: displaySurah
            )
            
            // Clear recognized text immediately
            recognizedText = ""
            
            // Update explanation if we haven't processed this ayah yet
            if ayahId != lastProcessedAyahId && !displayExplanation.isEmpty {
                lastProcessedAyahId = ayahId
                explanation = displayExplanation
                print("✅ Explanation: \(displayExplanation)")
            }
            
        } catch {
            print("❌ Error processing text: \(error)")
            errorMessage = "خطأ في معالجة الآية"
        }
    }
}