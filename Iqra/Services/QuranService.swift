import Foundation

final class QuranService {
    static let shared = QuranService()
    
    private var verseCache: [String: Ayah] = [:]  // Cache API responses
    private var surahInfo: [Int: String] = [:]    // Surah number → name mapping
    
    // Quick lookup: first 2-3 words of each verse for fast matching
    private let quickIndex: [(keywords: String, surah: Int, ayah: Int)] = [
        // Surah 1 - Al-Fatihah
        ("الحمد لله رب", 1, 1),
        ("الرحمن الرحيم", 1, 2),
        ("مالك يوم الدين", 1, 3),
        ("إياك نعبد وإياك", 1, 4),
        ("اهدنا الصراط", 1, 5),
        ("صراط الذين أنعمت", 1, 6),
        ("غير المغضوب", 1, 7),
        
        // Surah 2 - Al-Baqarah (sample)
        ("الم ذلك الكتاب", 2, 1),
        ("ذلك الكتاب لا ريب", 2, 2),
        ("الذين يؤمنون بالغيب", 2, 3),
        
        // Surah 36 - Ya-Sin
        ("يس والقرآن الحكيم", 36, 1),
        
        // Surah 55 - Ar-Rahman
        ("الرحمن علم القرآن", 55, 1),
        
        // Surah 67 - Al-Mulk
        ("تبارك الذي بيده", 67, 1),
        
        // Surah 68 - Al-Qalam
        ("ن والقلم وما", 68, 1),
        ("والقلم وما يسطرون", 68, 1),
        
        // Surah 96 - Al-Alaq
        ("اقرأ باسم ربك", 96, 1),
        
        // Surah 97 - Al-Qadr
        ("إنا أنزلناه في", 97, 1),
        
        // Surah 103 - Al-Asr
        ("والعصر إن الإنسان", 103, 1),
        
        // Surah 112 - Al-Ikhlas
        ("قل هو الله", 112, 1),
        ("الله الصمد", 112, 2),
        ("لم يلد ولم", 112, 3),
        ("ولم يكن له", 112, 4),
        
        // Surah 113 - Al-Falaq
        ("قل أعوذ برب", 113, 1),
        
        // Surah 114 - An-Nas
        ("قل أعوذ برب الناس", 114, 1),
        
        // Surah 4 - An-Nisa
        ("يا أيها الناس", 4, 1),
        
        // Surah 109 - Al-Kafirun
        ("قل يا أيها الكافرون", 109, 1),
        ("قل يا أيها", 109, 1),
    ]
    
    private init() {
        // Preload surah names
        Task {
            await loadSurahNames()
        }
    }
    
    /// Search for verse using multiple strategies
    func searchVerse(text: String) async throws -> Ayah? {
        var cleaned = String(text)  // Ensure String type
        
        // Remove control characters
        let controlChars = [
            "\u{200F}", "\u{200E}", "\u{202A}", "\u{202B}", "\u{202C}", "\u{061C}",
            "\u{200D}", "\u{200B}", "\u{200C}", "\u{FEFF}",
        ]
        
        for char in controlChars {
            cleaned = cleaned.replacingOccurrences(of: char, with: "")
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        
        print("📍 Cleaned text: '\(cleaned)'")
        guard !cleaned.isEmpty else { return nil }
        
        // Strategy 1: Try quick keyword lookup first (fast!)
        if let ayah = try await findVerseByQuickLookup(text: cleaned) {
            return ayah
        }
        
        // Strategy 2: Smart search (slower but comprehensive)
        if let ayah = try await findVerseBySmartMatch(text: cleaned) {
            return ayah
        }
        
        print("❌ No match found")
        return nil
    }
    
    /// Quick lookup using pre-indexed common verses - returns RIGHTMOST match (latest verse being recited)
    private func findVerseByQuickLookup(text: String) async throws -> Ayah? {
        let searchNorm = normalize(String(text))  // Ensure String type
        
        var bestMatch: (surah: Int, ayah: Int)? = nil
        var bestPosition: Int = -1
        
        // Find ALL matches and track their positions
        for entry in quickIndex {
            let keyNorm = normalize(String(entry.keywords))
            
            // Simple substring matching - check if any keyword matches
            if searchNorm.contains(keyNorm) {
                // Find position where this keyword appears
                if let range = searchNorm.range(of: keyNorm) {
                    let position = searchNorm.distance(from: searchNorm.startIndex, to: range.lowerBound)
                    
                    // Keep the RIGHTMOST match (highest position = latest in text)
                    if position > bestPosition {
                        bestPosition = position
                        bestMatch = (entry.surah, entry.ayah)
                    }
                }
            }
        }
        
        if let match = bestMatch {
            print("⚡ Quick lookup hit: Surah \(match.surah):Ayah \(match.ayah)")
            return try await fetchAyahFromAPI(surah: match.surah, ayah: match.ayah)
        }
        
        return nil
    }
    
    /// Smart matching strategy: Search through Quran verses intelligently
    private func findVerseBySmartMatch(text: String) async throws -> Ayah? {
        let searchNorm = normalize(String(text))
        
        // Simple check: need at least 2 words worth of text
        let wordCount = searchNorm.split(separator: " ").count
        guard wordCount >= 2 else {
            print("⚠️  Text too short (< 2 words)")
            return nil
        }
        
        print("🔍 Smart searching for: \(searchNorm)")
        
        do {
            // Progressive search strategy:
            // Phase 1: Search common surahs (36, 55, 67-114)
            if let result = try await searchSurahRange(surahStart: 36, surahEnd: 114, ayahStart: 1, ayahEnd: 5, searchText: searchNorm) {
                return result
            }
            
            print("⏳ Expanding search to all surahs...")
            
            // Phase 2: Search all remaining surahs
            if let result = try await searchSurahRange(surahStart: 1, surahEnd: 35, ayahStart: 1, ayahEnd: 5, searchText: searchNorm) {
                return result
            }
        } catch {
            print("⚠️  Search error: \(error)")
        }
        
        return nil
    }
    
    /// Search specific range of surahs with extreme type safety
    private func searchSurahRange(
        surahStart: Int,
        surahEnd: Int,
        ayahStart: Int,
        ayahEnd: Int,
        searchText: String
    ) async throws -> Ayah? {
        guard surahStart <= surahEnd else { return nil }
        guard !searchText.isEmpty else { return nil }
        
        let searchNorm = normalize(String(searchText))
        let textArray = searchNorm.split(separator: " ")
        
        // Build explicit String array
        var textWords: [String] = []
        for segment in textArray {
            let word = String(segment)
            if !word.isEmpty {
                textWords.append(word)
            }
        }
        
        guard textWords.count >= 2 else { 
            return nil
        }
        
        print("  🔎 Searching surahs \(surahStart)-\(surahEnd), ayahs \(ayahStart)-\(ayahEnd)")
        let searchStart = Date()
        
        for surah in surahStart...surahEnd {
            // Timeout check
            if Date().timeIntervalSince(searchStart) > 5.0 {
                print("  ⏱️  Timeout")
                return nil
            }
            
            for ayah in ayahStart...ayahEnd {
                do {
                    guard let verse = try await fetchAyahFromAPI(surah: surah, ayah: ayah) else {
                        continue
                    }
                    
                    let verseNorm = normalize(String(verse.arabic))
                    
                    // Count matches explicitly
                    var matchCount: Int = 0
                    for searchWord in textWords {
                        let word: String = searchWord
                        if verseNorm.contains(word) {
                            matchCount += 1
                        }
                    }
                    
                    // Safe threshold check
                    let threshold: Int = Int(Double(textWords.count) * 0.5)
                    if matchCount >= threshold {
                        print("  ✅ Match: \(surah):\(ayah)")
                        return verse
                    }
                } catch {
                    continue
                }
            }
        }
        
        return nil
    }
    
    /// Fetch verse from API using surah:ayah reference
    private func fetchAyahFromAPI(surah: Int, ayah: Int) async throws -> Ayah? {
        let cacheKey = "\(surah):\(ayah)"
        
        // Check cache first
        if let cached = verseCache[cacheKey] {
            return cached
        }
        
        let urlString = "https://api.alquran.cloud/v1/ayah/\(surah):\(ayah)/ar"
        guard let url = URL(string: urlString) else { return nil }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 3
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
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
                
                if let response = try? JSONDecoder().decode(AyahResponse.self, from: data),
                   let ayahData = response.data {
                    
                    // Explicitly convert all JSON strings to Swift String type
                    let arabicText = String(ayahData.text)
                    let surahNumber = Int(ayahData.surah.number)
                    let ayahNumber = Int(ayahData.numberInSurah)
                    let sName = String(ayahData.surah.name)
                    
                    let ayah = Ayah(
                        surah: surahNumber,
                        ayah: ayahNumber,
                        arabic: arabicText,
                        translation: "",
                        surahName: sName
                    )
                    
                    // Cache it for future use
                    verseCache[cacheKey] = ayah
                    return ayah
                }
            }
        } catch {
            print("  ⚠️  API timeout for \(surah):\(ayah)")
        }
        
        return nil
    }
    
    /// Load all surah names for reference
    private func loadSurahNames() async {
        // Hardcoded surah names (complete list)
        let surahs: [Int: String] = [
            1: "الفاتحة", 2: "البقرة", 3: "آل عمران", 4: "النساء", 5: "المائدة",
            6: "الأنعام", 7: "الأعراف", 8: "الأنفال", 9: "التوبة", 10: "يونس",
            11: "هود", 12: "يوسف", 13: "الرعد", 14: "إبراهيم", 15: "الحجر",
            16: "النحل", 17: "الإسراء", 18: "الكهف", 19: "مريم", 20: "طه",
            21: "الأنبياء", 22: "الحج", 23: "المؤمنون", 24: "النور", 25: "الفرقان",
            26: "الشعراء", 27: "النمل", 28: "القصص", 29: "العنكبوت", 30: "الروم",
            31: "لقمان", 32: "السجدة", 33: "الأحزاب", 34: "سبأ", 35: "فاطر",
            36: "يس", 37: "الصافات", 38: "ص", 39: "الزمر", 40: "غافر",
            41: "فصلت", 42: "الشورى", 43: "الزخرف", 44: "الدخان", 45: "الجاثية",
            46: "الأحقاف", 47: "محمد", 48: "الفتح", 49: "الحجرات", 50: "ق",
            51: "الذاريات", 52: "الطور", 53: "النجم", 54: "القمر", 55: "الرحمن",
            56: "الواقعة", 57: "الحديد", 58: "المجادلة", 59: "الحشر", 60: "الممتحنة",
            61: "الصف", 62: "الجمعة", 63: "المنافقون", 64: "التغابن", 65: "الطلاق",
            66: "التحريم", 67: "الملك", 68: "القلم", 69: "الحاقة", 70: "المعارج",
            71: "نوح", 72: "الجن", 73: "المزمل", 74: "المدثر", 75: "القيامة",
            76: "الإنسان", 77: "المرسلات", 78: "النبأ", 79: "النازعات", 80: "عبس",
            81: "التكوير", 82: "الانفطار", 83: "المطففين", 84: "الانشقاق", 85: "البروج",
            86: "الطارق", 87: "الأعلى", 88: "الغاشية", 89: "الفجر", 90: "البلد",
            91: "الشمس", 92: "الليل", 93: "الضحى", 94: "الشرح", 95: "التين",
            96: "العلق", 97: "القدر", 98: "البينة", 99: "الزلزلة", 100: "العاديات",
            101: "القارعة", 102: "التكاثر", 103: "العصر", 104: "الهمزة", 105: "الفيل",
            106: "قريش", 107: "الماعون", 108: "الكوثر", 109: "الكافرون", 110: "النصر",
            111: "المسد", 112: "الإخلاص", 113: "الفلق", 114: "الناس"
        ]
        
        surahInfo = surahs
    }
    
    /// Normalize Arabic text for comparison - explicit type handling
    private func normalize(_ text: String) -> String {
        // Ensure we're working with a String, not a SubSequence
        let inputString = String(text)
        
        // Create mutable copy
        var result = inputString
        
        // Remove diacritics
        result = result.folding(options: .diacriticInsensitive, locale: .current)
        
        // Lowercase
        result = result.lowercased()
        
        return result
    }
}
