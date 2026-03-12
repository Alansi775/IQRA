import Foundation

enum Config {
    static var groqAPIKey: String {
        loadAPIKey()
    }
    
    private static func loadAPIKey() -> String {
        // First try: Environment variable (from Xcode scheme)
        if let key = ProcessInfo.processInfo.environment["GROQ_API_KEY"], !key.isEmpty {
            print("✅ Loaded from environment")
            return key
        }
        
        // Second try: Read from .env file in Bundle
        if let envPath = Bundle.main.path(forResource: ".env", ofType: ""),
           let envContent = try? String(contentsOfFile: envPath, encoding: .utf8) {
            let lines = envContent.split(separator: "\n", omittingEmptySubsequences: true)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.starts(with: "GROQ_API_KEY=") {
                    let key = String(trimmed.dropFirst("GROQ_API_KEY=".count)).trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty {
                        print("✅ Loaded from .env file")
                        return key
                    }
                }
            }
        }
        
        print("❌ WARNING: No API key found!")
        return ""
    }
}