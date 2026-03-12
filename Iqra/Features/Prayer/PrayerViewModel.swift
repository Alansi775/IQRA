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
    
    // Buffer system: collect text for 1-2 seconds before sending to LLM
    private var textBuffer: String = ""
    private var bufferTimer: Timer?
    private let BUFFER_TIMEOUT: TimeInterval = 1.5  // استجمع لمدة 1.5 ثانية
    private let MIN_BUFFER_WORDS = 2  // الحد الأدنى من الكلمات قبل المعالجة
    
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
        bufferTimer?.invalidate()  // Cancel any pending buffer processing
        bufferTimer = nil
    }
    
    private func processRecognizedText(_ text: String) async {
        // Update UI with live text
        recognizedText = text
        print("📝 Processing text: \(text)")
        
        // Add text to buffer instead of processing immediately
        textBuffer = text
        
        // Reset and restart buffer timer
        bufferTimer?.invalidate()
        
        // Wait for more words to arrive (give STT time to complete the verse)
        bufferTimer = Timer.scheduledTimer(withTimeInterval: BUFFER_TIMEOUT, repeats: false) { [weak self] _ in
            Task { await self?.processBuffer() }
        }
    }
    
    /// Process the accumulated buffer when timer expires
    private func processBuffer() async {
        guard !textBuffer.isEmpty else {
            print("⚠️  Buffer is empty after timeout")
            return
        }
        
        print("✅ Buffer ready after \(BUFFER_TIMEOUT)s with text: \(textBuffer)")
        
        do {
            // Calculate word count for threshold check
            let wordCount = textBuffer.split(separator: " ").count
            print("📊 Final word count: \(wordCount)")
            
            // Skip processing if text is too short
            guard wordCount >= MIN_BUFFER_WORDS else {
                print("⏳ Still too few words (\(wordCount) < \(MIN_BUFFER_WORDS))")
                return
            }
            
            // AI-powered verse identification
            // Let LLM guess which verse, get explanation, and prepare for next verse
            print("🧠 Using AI to identify verse from buffered text...")
            
            let identification = try await groqService.identifyVerseAndExplain(recognizedText: textBuffer)
            
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
            print("💭 Explanation: \(displayExplanation)")
            
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
            textBuffer = ""  // Clear buffer
            
            // Update explanation if we haven't processed this ayah yet
            if ayahId != lastProcessedAyahId && !displayExplanation.isEmpty {
                lastProcessedAyahId = ayahId
                explanation = displayExplanation
            }
            
        } catch {
            print("❌ Error processing buffer: \(error)")
        }
    }
}