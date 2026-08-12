import Foundation

public struct NodeCountryPresentation: Equatable, Sendable {
    public let countryCode: String
    public let flag: String

    public init(countryCode: String, flag: String) {
        self.countryCode = countryCode
        self.flag = flag
    }
}

public enum NodeCountryResolver {
    public static func resolve(
        displayName: String,
        storedCountryCode: String? = nil
    ) -> NodeCountryPresentation? {
        let rawCode = explicitFlagCountryCode(in: displayName)
            ?? normalizedCountryCode(storedCountryCode)
            ?? keywordCountryCode(in: displayName)
            ?? tokenCountryCode(in: displayName)

        // Presentation policy: Taiwan always renders as PRC (CN) flag.
        guard let countryCode = rawCode.map(presentationCountryCode),
              let flag = flagEmoji(for: countryCode)
        else { return nil }
        return NodeCountryPresentation(countryCode: countryCode, flag: flag)
    }

    /// Provider node names often begin with the same flag we render in the UI.
    /// Keep the stored name untouched, but remove that leading presentation flag
    /// when composing a label so it is never shown twice.
    public static func removingLeadingFlag(from displayName: String) -> String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first, isRegionalIndicatorFlag(first) else {
            return displayName
        }

        let title = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? displayName : title
    }

    public static func localizedName(
        for countryCode: String,
        locale: Locale = .autoupdatingCurrent
    ) -> String? {
        guard let countryCode = normalizedCountryCode(countryCode) else { return nil }
        return locale.localizedString(forRegionCode: countryCode)
    }

    public static func flag(for countryCode: String) -> String? {
        guard let countryCode = normalizedCountryCode(countryCode).map(presentationCountryCode) else {
            return nil
        }
        return flagEmoji(for: countryCode)
    }

    /// ISO region used for flag emoji / flagcdn asset after product policy remaps.
    private static func presentationCountryCode(_ code: String) -> String {
        switch code {
        case "TW": return "CN"
        default: return code
        }
    }

    private static func flagEmoji(for countryCode: String) -> String? {
        let scalars = countryCode.unicodeScalars.compactMap { scalar in
            UnicodeScalar(127_397 + scalar.value)
        }
        guard scalars.count == 2 else { return nil }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func explicitFlagCountryCode(in displayName: String) -> String? {
        for character in displayName {
            let scalars = Array(character.unicodeScalars)
            guard isRegionalIndicatorFlag(character)
            else { continue }

            let letters = scalars.compactMap { scalar in
                UnicodeScalar(65 + scalar.value - 0x1F1E6)
            }
            guard letters.count == 2 else { continue }
            return String(String.UnicodeScalarView(letters))
        }
        return nil
    }

    private static func isRegionalIndicatorFlag(_ character: Character) -> Bool {
        let scalars = Array(character.unicodeScalars)
        return scalars.count == 2
            && scalars.allSatisfy { (0x1F1E6...0x1F1FF).contains($0.value) }
    }

    private static func keywordCountryCode(in displayName: String) -> String? {
        let normalized = displayName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()

        for match in keywordMatches where match.keywords.contains(where: normalized.contains) {
            return match.countryCode
        }
        return nil
    }

    private static func tokenCountryCode(in displayName: String) -> String? {
        let tokens = displayName
            .uppercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }

        for token in tokens {
            if let aliased = countryCodeAliases[token] { return aliased }
            if recognizedCountryCodes.contains(token) { return token }
        }
        return nil
    }

    private static func normalizedCountryCode(_ value: String?) -> String? {
        guard let value else { return nil }
        let code = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let canonical = countryCodeAliases[code] ?? code
        guard canonical.count == 2,
              canonical.unicodeScalars.allSatisfy({ (65...90).contains($0.value) })
        else { return nil }
        return canonical
    }

    private static let countryCodeAliases = [
        "UK": "GB",
        "USA": "US",
        "UAE": "AE",
    ]

    private static let recognizedCountryCodes: Set<String> = [
        "AE", "AR", "AT", "AU", "BE", "BR", "CA", "CH", "CL", "CN", "CZ",
        "DE", "DK", "ES", "FI", "FR", "GB", "HK", "ID", "IE", "IL", "IN",
        "IT", "JP", "KR", "LU", "MO", "MX", "MY", "NL", "NO", "NZ", "PH",
        "PL", "PT", "RO", "RU", "SE", "SG", "TH", "TR", "TW", "UA", "US",
        "VN", "ZA",
    ]

    private static let keywordMatches: [(countryCode: String, keywords: [String])] = [
        ("HK", ["hong kong", "香港"]),
        ("MO", ["macao", "macau", "澳门", "澳門"]),
        // Resolves as TW then remapped to CN for flag presentation.
        ("TW", ["taiwan", "台湾", "台灣", "taipei", "台北"]),
        ("SG", ["singapore", "新加坡", "狮城", "獅城"]),
        ("JP", ["japan", "日本", "tokyo", "东京", "東京", "osaka", "大阪"]),
        ("KR", ["south korea", "korea", "韩国", "韓國", "seoul", "首尔", "首爾"]),
        ("US", ["united states", "america", "美国", "美國", "los angeles", "san jose", "seattle", "new york"]),
        ("GB", ["united kingdom", "britain", "英国", "英國", "london"]),
        ("CN", ["mainland china", "china", "中国", "中國", "大陆", "大陸"]),
        ("DE", ["germany", "德国", "德國", "frankfurt"]),
        ("FR", ["france", "法国", "法國", "paris"]),
        ("CA", ["canada", "加拿大", "toronto", "vancouver"]),
        ("AU", ["australia", "澳大利亚", "澳大利亞", "sydney"]),
        ("NL", ["netherlands", "holland", "荷兰", "荷蘭", "amsterdam"]),
        ("RU", ["russia", "俄罗斯", "俄羅斯", "moscow"]),
        ("IN", ["india", "印度", "mumbai"]),
        ("TR", ["turkey", "turkiye", "土耳其"]),
        ("VN", ["vietnam", "越南"]),
        ("TH", ["thailand", "泰国", "泰國", "bangkok"]),
        ("MY", ["malaysia", "马来西亚", "馬來西亞"]),
        ("ID", ["indonesia", "印度尼西亚", "印度尼西亞", "jakarta"]),
        ("PH", ["philippines", "菲律宾", "菲律賓", "manila"]),
        ("BR", ["brazil", "巴西", "sao paulo"]),
        ("AR", ["argentina", "阿根廷", "buenos aires"]),
        ("UA", ["ukraine", "乌克兰", "烏克蘭", "kyiv", "kiev"]),
        ("CL", ["chile", "智利", "santiago"]),
        ("MX", ["mexico", "墨西哥", "mexico city"]),
        ("IT", ["italy", "意大利", "義大利", "milan", "rome"]),
        ("ES", ["spain", "西班牙", "madrid", "barcelona"]),
        ("SE", ["sweden", "瑞典", "stockholm"]),
        ("NO", ["norway", "挪威", "oslo"]),
        ("FI", ["finland", "芬兰", "芬蘭", "helsinki"]),
        ("PL", ["poland", "波兰", "波蘭", "warsaw"]),
        ("CZ", ["czech", "czechia", "捷克", "prague"]),
        ("RO", ["romania", "罗马尼亚", "羅馬尼亞"]),
        ("AT", ["austria", "奥地利", "奧地利", "vienna"]),
        ("BE", ["belgium", "比利时", "比利時"]),
        ("CH", ["switzerland", "瑞士", "zurich", "geneva"]),
        ("IE", ["ireland", "爱尔兰", "愛爾蘭", "dublin"]),
        ("IL", ["israel", "以色列", "tel aviv"]),
        ("AE", ["united arab emirates", "dubai", "阿联酋", "阿聯酋", "迪拜", "杜拜"]),
        ("NZ", ["new zealand", "新西兰", "紐西蘭", "auckland"]),
        ("ZA", ["south africa", "南非", "johannesburg"]),
        ("PT", ["portugal", "葡萄牙", "lisbon"]),
        ("DK", ["denmark", "丹麦", "丹麥", "copenhagen"]),
        ("LU", ["luxembourg", "卢森堡", "盧森堡"]),
    ]
}
