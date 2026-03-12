import Foundation

final class QuranService {
    static let shared = QuranService()
    
    private init() {}
    
    /// Search for Quranic verse by text
    /// Strategy: Use local index to match text → fetch full verse from API
    func searchVerse(text: String) async throws -> Ayah? {
        var cleaned = text
        
        // Remove control characters
        let controlChars = [
            "\u{200F}", "\u{200E}", "\u{202A}", "\u{202B}", "\u{202C}", "\u{061C}",
            "\u{200D}", "\u{200B}", "\u{200C}", "\u{FEFF}",
        ]
        
        for char in controlChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: "")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
                         .replacingOccurrences(of: "  ", with: " ")
        
        print("📍 Cleaned text: '\(cleaned)'")
        guard !cleaned.isEmpty else { return nil }
        
        // Step 1: Use local index to find verse reference (surah:ayah)
        if let ref = findVerseReference(text: cleaned) {
            print("🔍 Found reference in index: Surah \(ref.surah), Ayah \(ref.ayah)")
            
            // Step 2: Fetch full verse from API
            return try await fetchAyahFromAPI(surah: ref.surah, ayah: ref.ayah)
        }
        
        return nil
    }
    
    /// Fetch verse from API using surah:ayah reference (THIS ENDPOINT WORKS!)
    private func fetchAyahFromAPI(surah: Int, ayah: Int) async throws -> Ayah? {
        let urlString = "https://api.alquran.cloud/v1/ayah/\(surah):\(ayah)/ar"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔗 API Fetch: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    struct AyahResponse: Codable {
                        struct AyahData: Codable {
                            let text: String
                            let numberInSurah: Int
                            let surah: SurahInfo
                        }
                        struct SurahInfo: Codable {
                            let number: Int
                            let name: String
                        }
                        let data: AyahData?
                    }
                    
                    let decoder = JSONDecoder()
                    if let response = try? decoder.decode(AyahResponse.self, from: data),
                       let ayahData = response.data {
                        
                        print("✅ API Returned: Surah \(ayahData.surah.number):Ayah \(ayahData.numberInSurah)")
                        
                        return Ayah(
                            surah: ayahData.surah.number,
                            ayah: ayahData.numberInSurah,
                            arabic: ayahData.text,
                            translation: "",
                            surahName: ayahData.surah.name
                        )
                    }
                }
            }
        } catch {
            print("⚠️  API Error: \(error.localizedDescription)")
        }
        
        return nil
    }
    
    /// Find verse reference (surah:ayah) from recognized text using minimal local index
    /// Strategy: Find LONGEST MATCH FIRST to handle mid-verse starting points
    private func findVerseReference(text: String) -> (surah: Int, ayah: Int)? {
        // Minimal keyword index - JUST 2-3 words that uniquely identify each verse
        let verseIndex: [(keywords: String, surah: Int, ayah: Int)] = [
            // Surah 1 - Al-Fatihah
            ("الحمد لله رب", 1, 1),
            ("الرحمن الرحيم", 1, 2),
            ("مالك يوم الدين", 1, 3),
            ("إياك نعبد", 1, 4),
            ("اهدنا الصراط", 1, 5),
            ("صراط الذين أنعمت", 1, 6),
            ("غير المغضوب", 1, 7),
            
            // Surah 2 - Al-Baqarah (sample verses)
            ("الم ذلك الكتاب", 2, 1),
            ("ذلك الكتاب لا ريب", 2, 2),
            ("الذين يؤمنون بالغيب", 2, 3),
            ("إلهكم إله واحد", 2, 163),
            
            // Surah 3 - Al-Imran
            ("الم الله لا إله", 3, 1),
            
            // Surah 4 - An-Nisa (where user's verse is!)
            ("يا أيها الناس اتقوا ربكم", 4, 1),
            ("وليخش الذين لو تركوا", 4, 9),
            ("وليست التوبة للذين يعملون السيئات", 4, 17),
            
            // Surah 5 - Al-Ma'idah
            ("يا أيها الذين آمنوا أوفوا", 5, 1),
            
            // Surah 16 - An-Nahl
            ("أتى أمر الله", 16, 1),
            
            // Surah 20 - Ta-Ha
            ("ما أنزلنا عليك القرآن", 20, 2),
            
            // Surah 36 - Ya-Sin
            ("يس والقرآن الحكيم", 36, 1),
            ("إنما أمره إذا أراد", 36, 82),
            
            // Surah 55 - Ar-Rahman
            ("الرحمن علم القرآن", 55, 1),
            
            // Surah 67 - Al-Mulk
            ("تبارك الذي بيده الملك", 67, 1),
            
            // Surah 68 - Al-Qalam
            ("ن والقلم وما يسطرون", 68, 1),
            ("وإنك لعلى خلق عظيم", 68, 4),
            
            // Surah 75 - Al-Qiyamah
            ("ويل يومئذ للمكذبين", 75, 1),
            
            // Surah 96 - Al-Alaq
            ("اقرأ باسم ربك الذي خلق", 96, 1),
            
            // Surah 97 - Al-Qadr
            ("إنا أنزلناه في ليلة القدر", 97, 1),
            
            // Surah 103 - Al-Asr
            ("والعصر إن الإنسان", 103, 1),
            
            // Surah 109 - Al-Kafirun
            ("قل يا أيها الكافرون", 109, 1),
            
            // Surah 112 - Al-Ikhlas
            ("قل هو الله أحد", 112, 1),
            ("الله الصمد", 112, 2),
            ("لم يلد ولم يولد", 112, 3),
            ("ولم يكن له كفوا", 112, 4),
            
            // Surah 113 - Al-Falaq
            ("قل أعوذ برب الفلق", 113, 1),
            ("من شر ما خلق", 113, 2),
            ("ومن شر غسق", 113, 3),
            ("ومن شر النفاثات", 113, 4),
            ("ومن شر حاسد", 113, 5),
            
            // Surah 114 - An-Nas
            ("قل أعوذ برب الناس", 114, 1),
            ("ملك الناس", 114, 2),
            ("إله الناس", 114, 3),
            ("من شر الوسواس", 114, 4),
        ]
        
        let cleanedText = normalize(text)
        let words = cleanedText.split(separator: " ").map { String($0) }
        
        print("🔍 Searching index for: \(cleanedText)")
        
        // IGNORE single words - too many false matches
        if words.count < 2 {
            print("⚠️  Text too short (< 2 words), skipping index search")
            return nil
        }
        
        // FIND KEYWORDS WITHIN ACCUMULATED TEXT and return RIGHTMOST/LATEST MATCH
        // Since speech recognition adds new words to the end, the LATEST match is the current verse
        // Example: text = "قل هو الله أحد الله الصمد"
        //          matches "قل هو الله أحد" at position 0 (Ayah 1)
        //          AND "الله الصمد" at position 4 (Ayah 2)
        //          should return Ayah 2 because it's rightmost = currently being recited
        var bestMatch: (surah: Int, ayah: Int, position: Int)? = nil
        
        for entry in verseIndex {
            let keyNorm = normalize(entry.keywords)
            let keyWords = keyNorm.split(separator: " ").map { String($0) }
            
            // Search for keyword sequence ANYWHERE in accumulated text
            if keyWords.count >= 2 && words.count >= keyWords.count {
                for i in 0...(words.count - keyWords.count) {
                    let endIdx = i + keyWords.count
                    let subText = Array(words[i..<endIdx])
                    
                    // Found exact keyword match!
                    if subText == keyWords {
                        print("✅ Found keyword sequence '\(keyWords.joined(separator: " "))' at position \(i)")
                        
                        // Keep track of RIGHTMOST match (latest in accumulated text = current verse)
                        if bestMatch == nil || i > bestMatch!.position {
                            bestMatch = (entry.surah, entry.ayah, i)
                            print("   → Updated best match: Surah \(entry.surah):Ayah \(entry.ayah) (position: \(i))")
                        }
                    }
                }
            }
        }
        
        if let match = bestMatch {
            print("🏆 Final best match: Surah \(match.surah):Ayah \(match.ayah) (rightmost at position: \(match.position))")
            return (match.surah, match.ayah)
        }
        
        print("❌ No match found in verse index")
        return nil
    }
    
    /// Normalize Arabic text for comparison
    private func normalize(_ text: String) -> String {
        var normalized = text
        normalized = normalized.folding(options: .diacriticInsensitive, locale: .current)
        return normalized.lowercased()
    }
}

// MARK: - API Response Models
private struct AlquranResponse: Codable {
    struct AyahData: Codable {
        let text: String
        let numberInSurah: Int
        let surah: SurahInfo
    }
    struct SurahInfo: Codable {
        let number: Int
        let name: String
    }
    let data: AyahData?
}
