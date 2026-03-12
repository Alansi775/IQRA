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
    func identifyVerseAndExplain(recognizedText: String) async throws -> VerseIdentification {
        guard !apiKey.isEmpty else {
            throw NSError(domain: "GroqService", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key is empty"])
        }
        
        // Prompt the LLM to recognize the verse even with imperfect STT
        let identifyPrompt = """
        أنت معلم قرآني روحي صوفي. المصلي يقف أمام الله يستمع للقرآن.
        
        الكلمات المسموعة من ميكروفون المصلي (قد لا تكون دقيقة 100%):
        "\(recognizedText)"
        
        المطلوب:
        1. خمّن أي آية من القرآن الكريم بدقة (حتى لو STT غير دقيق)
        2. أعطِ اسم السورة ورقم الآية الصحيحة فقط
        3. شرح روحي قصير جداً (جملة واحدة أقل من 10 كلمات فقط) - الشعور الروحي فقط
        4. اسم السورة والآية التالية للاستعداد النفسي
        
        تحذير - لا تفعل:
        ❌ لا تضيف تعليقات إضافية
        ❌ لا تقول "أنا أعتقد" أو "قد يكون"
        ❌ لا تشرح السياق الأكاديمي
        ✅ فقط: السورة + الآية + الشعور الروحي + التالية
        
        أجب بصيغة هذه (بالضبط، بدون إضافات):
        السورة: [فقط اسم السورة]
        الآية: [فقط الرقم]
        الشرح: [جملة روحية قصيرة جداً]
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