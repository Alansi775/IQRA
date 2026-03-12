import Foundation

struct Ayah: Codable, Equatable, Identifiable {
    let id: String  // Unique identifier to help SwiftUI track changes
    let surah: Int
    let ayah: Int
    let arabic: String
    let translation: String
    let surahName: String
    
    // Custom initializer with explicit String conversions
    init(surah: Int, ayah: Int, arabic: String, translation: String, surahName: String) {
        self.id = "\(surah)-\(ayah)"
        self.surah = surah
        self.ayah = ayah
        self.arabic = String(arabic).trimmingCharacters(in: .whitespaces)
        self.translation = String(translation).trimmingCharacters(in: .whitespaces)
        self.surahName = String(surahName).trimmingCharacters(in: .whitespaces)
    }
    
    // Codable conformance with explicit String handling
    enum CodingKeys: String, CodingKey {
        case surah, ayah, arabic, translation, surahName
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        surah = try container.decode(Int.self, forKey: .surah)
        ayah = try container.decode(Int.self, forKey: .ayah)
        
        // Explicitly decode strings and convert them
        let arabicRaw = try container.decode(String.self, forKey: .arabic)
        let translationRaw = try container.decode(String.self, forKey: .translation)
        let surahNameRaw = try container.decode(String.self, forKey: .surahName)
        
        arabic = String(arabicRaw).trimmingCharacters(in: .whitespaces)
        translation = String(translationRaw).trimmingCharacters(in: .whitespaces)
        surahName = String(surahNameRaw).trimmingCharacters(in: .whitespaces)
        
        id = "\(surah)-\(ayah)"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(surah, forKey: .surah)
        try container.encode(ayah, forKey: .ayah)
        try container.encode(String(arabic), forKey: .arabic)
        try container.encode(String(translation), forKey: .translation)
        try container.encode(String(surahName), forKey: .surahName)
    }
    
    // Explicit Equatable conformance
    static func == (lhs: Ayah, rhs: Ayah) -> Bool {
        lhs.id == rhs.id && 
        lhs.surah == rhs.surah && 
        lhs.ayah == rhs.ayah &&
        String(lhs.arabic) == String(rhs.arabic) &&
        String(lhs.translation) == String(rhs.translation) &&
        String(lhs.surahName) == String(rhs.surahName)
    }
}