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