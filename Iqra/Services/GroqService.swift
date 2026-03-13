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
        
        // Build language instruction dynamically
        let language_instruction: String
        switch language.lowercased() {
        case "arabic":
            language_instruction = "أجب باللغة العربية فقط. كل الشروحات بالعربية فقط."
        case "turkish":
            language_instruction = "Cevap dilini Türkçe yapın. Tüm açıklamalar Türkçe olsun."
        case "english":
            language_instruction = "Answer in English only. All explanations in English."
        case "french":
            language_instruction = "Répondez en français uniquement. Toutes les explications en français."
        case "german":
            language_instruction = "Antworten Sie nur auf Deutsch. Alle Erklärungen auf Deutsch."
        case "urdu":
            language_instruction = "اردو میں جواب دیں۔ تمام وضاحتیں اردو میں ہوں۔"
        case "chinese":
            language_instruction = "请只用简体中文回答。所有解释都必须是简体中文。"
        case "korean":
            language_instruction = "한국어로만 답변하세요. 모든 설명은 한국어여야 합니다."
        case "japanese":
            language_instruction = "日本語だけで答えてください。すべての説明は日本語である必要があります。"
        case "malay":
            language_instruction = "Jawab hanya dalam bahasa Melayu. Semua penjelasan harus dalam bahasa Melayu."
        case "indonesian":
            language_instruction = "Jawab hanya dalam bahasa Indonesia. Semua penjelasan harus dalam bahasa Indonesia."
        case "thai":
            language_instruction = "ตอบเฉพาะภาษาไทยเท่านั้น คำอธิบายทั้งหมดต้องเป็นภาษาไทย"
        case "vietnamese":
            language_instruction = "Chỉ trả lời bằng tiếng Việt. Tất cả các giải thích phải bằng tiếng Việt."
        case "portuguese":
            language_instruction = "Responda apenas em português. Todas as explicações devem ser em português."
        case "spanish":
            language_instruction = "Responda solo en español. Todas las explicaciones deben ser en español."
        case "russian":
            language_instruction = "Ответьте только на русском языке. Все объяснения должны быть на русском языке."
        case "hindi":
            language_instruction = "केवल हिंदी में उत्तर दें। सभी व्याख्याएं हिंदी में होनी चाहिए।"
        case "bengali":
            language_instruction = "শুধুমাত্র বাংলায় উত্তর দিন। সমস্ত ব্যাখ্যা বাংলায় হওয়া উচিত।"
        case "swahili":
            language_instruction = "Jibu kwa Kiswahili tu. Maelezo yote lazima yawe kwa Kiswahili."
        case "hebrew":
            language_instruction = "ענה רק בעברית. כל ההסברים חייבים להיות בעברית."
        case "persian":
            language_instruction = "فقط به فارسی پاسخ دهید. تمام توضیحات باید به فارسی باشند."
        default:
            language_instruction = "أجب باللغة العربية فقط. كل الشروحات بالعربية فقط."
        }
        
        // Prompt the LLM to recognize the verse even with imperfect STT
        let identifyPrompt = """
        أنت معلم قرآني بسيط وواضح. المصلي يقف أمام الله يقرأ القرآن.
        
        الكلمات المسموعة من ميكروفون المصلي (قد لا تكون دقيقة 100%):
        "\(recognizedText)"
        
        \(language_instruction)
        
        المطلوب:
        1. خمّن أي آية من القرآن الكريم بدقة (حتى لو STT غير دقيق)
        2. أعطِ اسم السورة ورقم الآية الصحيحة فقط
        3. شرح مباشر وسهل جداً (جملة واحدة فقط، 10 كلمات أقل) - اشرح ماذا تقول الآية بطريقة بسيطة جداً يفهمها أي شخص
        4. اسم السورة والآية التالية
        
        ركّز على:
        ✅ معنى الآية بكلمات بسيطة جداً (بدون كلمات صعبة)
        ✅ مباشر وواضح جداً
        ✅ يوضح اللي تقول الآية مباشرة بدون تفاسير طويلة
        
        لا تفعل:
        ❌ لا تضيف تعليقات إضافية
        ❌ لا تقول "أنا أعتقد" أو "قد يكون"
        ❌ لا تقول كلمات صعبة مثل "المقام" أو "التجلي"
        ❌ لا تشرح السياق الأكاديمي
        
        أجب بصيغة هذه (بالضبط، بدون إضافات):
        السورة: [فقط اسم السورة]
        الآية: [فقط الرقم]
        الشرح: [شرح بسيط جداً يوضح ماذا تقول الآية]
        التالية: [اسم السورة رقم]
        """
        
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "user",
                    "content": identifyPrompt
                ]
            ],
            "max_tokens": 100,  // Reduced from 150 to force conciseness
            "temperature": 0.3  // More conservative (was 0.4) for consistent format
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
                print("🧠 LLM Result: \(response)")
                
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
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("السورة:") {
                let value = trimmed.replacingOccurrences(of: "السورة:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // Take only the first word/number (ignore extra text)
                surahName = value.split(separator: " ").first.map(String.init) ?? value
            } else if trimmed.hasPrefix("الآية:") {
                let value = trimmed.replacingOccurrences(of: "الآية:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // Take only the first number (ignore extra text)
                ayahNumber = value.split(separator: " ").first.map(String.init) ?? value
            } else if trimmed.hasPrefix("الشرح:") {
                let value = trimmed.replacingOccurrences(of: "الشرح:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // Take everything up to certain delimiters (ignore garbage)
                explanation = value.split(separator: "،").first.map(String.init) ?? value
                explanation = explanation.split(separator: "،").first.map(String.init) ?? explanation
            } else if trimmed.hasPrefix("التالية:") {
                let value = trimmed.replacingOccurrences(of: "التالية:", with: "")
                    .trimmingCharacters(in: .whitespaces)
                // Take everything up to certain delimiters
                nextVerse = value.split(separator: "،").first.map(String.init) ?? value
            }
        }
        
        // Validate that we got meaningful results
        if surahName.isEmpty || ayahNumber.isEmpty {
            print("⚠️  Invalid parse result - surahName: '\(surahName)', ayahNumber: '\(ayahNumber)'")
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