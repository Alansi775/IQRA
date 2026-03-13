import Foundation

final class GroqService {
    private let apiKey: String
    private let endpoint = "https://api.groq.com/openai/v1/chat/completions"
    
    init(apiKey: String) {
        self.apiKey = apiKey
        if apiKey.isEmpty {
            print("⚠️ WARNING: GroqService initialized with empty API key")
        }
    }
    
    /// Explain a Quranic verse using Groq Chat API
    func explainVerse(prompt: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key is empty"])
        }
        
        // Using llama-3.3-70b-versatile - Groq's latest stable model
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 150,
            "temperature": 0.5
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "GroqService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot serialize request"])
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Log response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("🔗 Groq API response: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ Groq API error: \(errorText)")
                    throw NSError(domain: "GroqService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
                }
            }
            
            let decoder = JSONDecoder()
            
            do {
                let decodedResponse = try decoder.decode(GroqChatResponse.self, from: data)
                if let firstChoice = decodedResponse.choices.first,
                   let content = firstChoice.message.content {
                    let explanation = String(content).trimmingCharacters(in: .whitespaces)
                    print("✅ Groq response: \(explanation)")
                    return explanation
                } else {
                    print("⚠️  Groq response has no choices or content")
                    throw NSError(domain: "GroqService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No valid response message"])
                }
            } catch let DecodingError.dataCorrupted(context) {
                print("❌ JSON decode error - dataCorrupted: \(context.debugDescription)")
                throw NSError(domain: "GroqService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Response format error"])
            } catch let DecodingError.keyNotFound(key, context) {
                print("❌ JSON decode error - keyNotFound: \(key), \(context.debugDescription)")
                throw NSError(domain: "GroqService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Missing response field"])
            } catch {
                print("❌ JSON decode error: \(error)")
                throw NSError(domain: "GroqService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"])
            }
        } catch {
            print("❌ Explanation request failed: \(error)")
            throw error
        }
    }
    
    /// AI-powered verse identification and explanation
    /// The LLM guesses which verse the user is reciting and provides explanation + next verse
    func identifyVerseAndExplain(recognizedText: String, language: String = "arabic") async throws -> VerseIdentification {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key is empty"])
        }
        
        print("🌍 LLM Language selected: '\(language)'")  // Debug: Print selected language
        
        // Build language code for system message
        let languageCode = language.lowercased()
        let responseLanguage: String
        
        switch languageCode {
        case "turkish": responseLanguage = "Turkish - Türkçe"
        case "english": responseLanguage = "English"
        case "french": responseLanguage = "French - Français"
        case "german": responseLanguage = "German - Deutsch"
        case "urdu": responseLanguage = "Urdu - اردو"
        case "chinese": responseLanguage = "Chinese - 中文"
        case "korean": responseLanguage = "Korean - 한국어"
        case "japanese": responseLanguage = "Japanese - 日本語"
        case "malay": responseLanguage = "Malay - Melayu"
        case "indonesian": responseLanguage = "Indonesian - Indonesia"
        case "thai": responseLanguage = "Thai - ไทย"
        case "vietnamese": responseLanguage = "Vietnamese - Tiếng Việt"
        case "portuguese": responseLanguage = "Portuguese - Português"
        case "spanish": responseLanguage = "Spanish - Español"
        case "russian": responseLanguage = "Russian - Русский"
        case "hindi": responseLanguage = "Hindi - हिंदी"
        case "bengali": responseLanguage = "Bengali - বাংলা"
        case "swahili": responseLanguage = "Swahili - Kiswahili"
        case "hebrew": responseLanguage = "Hebrew - עברית"
        case "persian": responseLanguage = "Persian - فارسی"
        default: responseLanguage = "Arabic - العربية"
        }
        
        // Build language instruction dynamically
        let language_instruction: String
        switch language.lowercased() {
        case "arabic":
            language_instruction = "أجب باللغة العربية فقط. كل الشروحات بالعربية فقط."
        case "turkish":
            language_instruction = "ÇOOK ÖNEMLİ: Cevap dilini Türkçe yapın. Tüm açıklamalar TÜRKÇE olsun. Asla Arapça yazma."
        case "english":
            language_instruction = "VERY IMPORTANT: Answer ONLY in English. All explanations MUST be in English. Never answer in Arabic."
        case "french":
            language_instruction = "TRÈS IMPORTANT: Répondez UNIQUEMENT en français. Toutes les explications en français. Jamais d'arabe."
        case "german":
            language_instruction = "SEHR WICHTIG: Antworten Sie NUR auf Deutsch. Alle Erklärungen auf Deutsch. Keine Arabisch."
        case "urdu":
            language_instruction = "بہت اہم: اردو میں جواب دیں۔ تمام وضاحتیں اردو میں ہوں۔ کبھی عربی نہ لکھیں۔"
        case "chinese":
            language_instruction = "非常重要：只用简体中文回答。所有解释都必须是简体中文。不要用阿拉伯语。"
        case "korean":
            language_instruction = "매우 중요: 한국어로만 답변하세요. 모든 설명은 한국어여야 합니다. 아랍어 금지."
        case "japanese":
            language_instruction = "非常に重要：日本語だけで答えてください。すべての説明は日本語である必要があります。アラビア語は禁止。"
        case "malay":
            language_instruction = "SANGAT PENTING: Jawab hanya dalam bahasa Melayu. Semua penjelasan harus dalam bahasa Melayu. Jangan gunakan Bahasa Arab."
        case "indonesian":
            language_instruction = "SANGAT PENTING: Jawab hanya dalam bahasa Indonesia. Semua penjelasan harus dalam bahasa Indonesia. Jangan gunakan Bahasa Arab."
        case "thai":
            language_instruction = "สำคัญมาก: ตอบเฉพาะภาษาไทยเท่านั้น คำอธิบายทั้งหมดต้องเป็นภาษาไทย ห้ามใช้ภาษาอาหรับ"
        case "vietnamese":
            language_instruction = "RẤT QUAN TRỌNG: Chỉ trả lời bằng tiếng Việt. Tất cả các giải thích phải bằng tiếng Việt. Không sử dụng Tiếng Ả Rập."
        case "portuguese":
            language_instruction = "MUITO IMPORTANTE: Responda apenas em português. Todas as explicações devem ser em português. Nunca escreva em árabe."
        case "spanish":
            language_instruction = "MUY IMPORTANTE: Responda solo en español. Todas las explicaciones deben ser en español. Nunca en árabe."
        case "russian":
            language_instruction = "ОЧЕНЬ ВАЖНО: Ответьте только на русском языке. Все объяснения должны быть на русском языке. Никогда по-арабски."
        case "hindi":
            language_instruction = "बहुत महत्वपूर्ण: केवल हिंदी में उत्तर दें। सभी व्याख्याएं हिंदी में होनी चाहिए। कभी अरबी नहीं।"
        case "bengali":
            language_instruction = "অত্যন্ত গুরুত্বপূর্ণ: শুধুমাত্র বাংলায় উত্তর দিন। সমস্ত ব্যাখ্যা বাংলায় হওয়া উচিত। কখনও আরবি নয়।"
        case "swahili":
            language_instruction = "MUHIMU SANA: Jibu kwa Kiswahili tu. Maelezo yote lazima yawe kwa Kiswahili. Hakuna Kiarabu."
        case "hebrew":
            language_instruction = "חשוב מאוד: ענה רק בעברית. כל ההסברים חייבים להיות בעברית. אסור ערבית."
        case "persian":
            language_instruction = "بسیار مهم: فقط به فارسی پاسخ دهید. تمام توضیحات باید به فارسی باشند. هرگز عربی نباشد."
        default:
            language_instruction = "أجب باللغة العربية فقط. كل الشروحات بالعربية فقط."
        }
        
        // Prompt the LLM to recognize the verse even with imperfect STT
        let identifyPrompt = """
        الكلمات المسموعة من ميكروفون المصلي (قد تكون فيها أخطاء):
        "\(recognizedText)"
        
        أجب بصيغة هذه (بالضبط - لا تغير):
        السورة: [اسم بالعربية]
        الآية: [رقم]
        الشرح: [شرح بسيط]
        التالية: [اسم بالعربية رقم]
        """
        
        let systemMessage = """
        أنت معلم قرآني دقيق جداً. المطلوب:
        1. تحديد الآية الدقيقة من القرآن (صحح أخطاء STT)
        2. الإجابة بـ4 أسطر فقط: السورة + الآية + الشرح + التالية
        3. اسم السورة والتالية بالعربية دائماً
        4. الشرح فقط بـ\(responseLanguage) - لا تكتب بأي لغة أخرى
        5. شرح قصير جداً (جملة واحدة أقل من 8 كلمات)
        """
        
        print("🌍 Response language: '\(responseLanguage)' (from code: '\(languageCode)')")
        
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "system",
                    "content": systemMessage
                ],
                [
                    "role": "user",
                    "content": identifyPrompt
                ]
            ],
            "max_tokens": 90,
            "temperature": 0.3  // Lower for consistency
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw NSError(domain: "GroqService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Cannot serialize request"])
        }
        
        var request = URLRequest(url: URL(string: endpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🧠 LLM Identification response: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                    print("❌ LLM error: \(errorText)")
                    throw NSError(domain: "GroqService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorText])
                }
            }
            
            let decoder = JSONDecoder()
            let decodedResponse = try decoder.decode(GroqChatResponse.self, from: data)
            
            if let firstChoice = decodedResponse.choices.first,
               let content = firstChoice.message.content {
                let response = String(content).trimmingCharacters(in: .whitespaces)
                print("🧠 LLM Raw Response:")
                print(response)
                print("🧠 ---END RAW RESPONSE---")
                
                // Parse the response
                return parseVerseIdentification(response)
            } else {
                throw NSError(domain: "GroqService", code: -3, userInfo: [NSLocalizedDescriptionKey: "No valid response"])
            }
        } catch {
            print("❌ Verse identification failed: \(error)")
            throw error
        }
    }
    
    /// Parse LLM response to extract verse identification
    private func parseVerseIdentification(_ response: String) -> VerseIdentification {
        var surahName = ""
        var ayahNumber = ""
        var explanation = ""
        var nextVerse = ""
        
        let lines = response.split(separator: "\n").map(String.init)
        
        print("📋 Parsing \(lines.count) lines from LLM response")
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            print("  -> Parsing line: '\(trimmed)'")
            
            if trimmed.hasPrefix("السورة:") {
                let value = trimmed.replacingOccurrences(of: "السورة:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                surahName = value.split(separator: " ").first.map(String.init) ?? value
                print("     ✅ السورة parsed: '\(surahName)'")
            } else if trimmed.hasPrefix("الآية:") {
                let value = trimmed.replacingOccurrences(of: "الآية:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                ayahNumber = value.split(separator: " ").first.map(String.init) ?? value
                print("     ✅ الآية parsed: '\(ayahNumber)'")
            } else if trimmed.hasPrefix("الشرح:") {
                let value = trimmed.replacingOccurrences(of: "الشرح:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                explanation = value
                print("     ✅ الشرح parsed: '\(explanation)'")
            } else if trimmed.hasPrefix("التالية:") {
                let value = trimmed.replacingOccurrences(of: "التالية:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                nextVerse = value
                print("     ✅ التالية parsed: '\(nextVerse)'")
            }
        }
        
        // Validate that we got meaningful results
        if surahName.isEmpty || ayahNumber.isEmpty {
            print("⚠️  Invalid parse - السورة: '\(surahName)', الآية: '\(ayahNumber)'")
        }
        
        return VerseIdentification(
            surahName: surahName,
            ayahNumber: ayahNumber,
            explanation: explanation,
            nextVerse: nextVerse
        )
    }
}

// MARK: - Verse Identification Model
struct VerseIdentification {
    let surahName: String
    let ayahNumber: String
    let explanation: String
    let nextVerse: String
}

// MARK: - Groq Chat API Response Models
private struct GroqChatResponse: Codable {
    let model: String
    let choices: [Choice]
    let id: String?
    let object: String?
    let created: Int?  // Timestamp, not a Date object
    
    struct Choice: Codable {
        let message: Message
        let index: Int?
        let finish_reason: String?
    }
    
    struct Message: Codable {
        let role: String
        let content: String?
    }
}