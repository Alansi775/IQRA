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
        أنت معلم قرآني عبقري. المصلي يقرأ من القرآن الكريم.
        
        الكلمات المسموعة من ميكروفون المصلي (قد لا تكون دقيقة 100%):
        "\(recognizedText)"
        
        المطلوب:
        1. خمّن أي آية من القرآن الكريم يقصد المصلي (حتى لو STT غير دقيق تماماً)
        2. أعطِ اسم السورة ورقم الآية الصحيحة
        3. أعطِ شرح روحي قصير جداً (جملة واحدة أقل من 15 كلمة) عن معنى هذه الآية
        4. اذكر الآية التالية التي تأتي مباشرة بعدها
        
        أجب بصيغة مشابهة لهذه (بالضبط):
        السورة: اسم السورة
        الآية: رقم
        الشرح: الشرح
        التالية: اسم السورة الآية رقم
        """
        
        let requestBody: [String: Any] = [
            "model": "llama-3.3-70b-versatile",
            "messages": [
                [
                    "role": "user",
                    "content": identifyPrompt
                ]
            ],
            "max_tokens": 200,
            "temperature": 0.3  // Lower temperature for better consistency
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
                surahName = trimmed.replacingOccurrences(of: "السورة:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("الآية:") {
                ayahNumber = trimmed.replacingOccurrences(of: "الآية:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("الشرح:") {
                explanation = trimmed.replacingOccurrences(of: "الشرح:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("التالية:") {
                nextVerse = trimmed.replacingOccurrences(of: "التالية:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
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