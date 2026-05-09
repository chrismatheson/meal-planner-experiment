import Foundation

enum TimeParser {
    static func parseToMinutes(_ timeString: String?) -> Int? {
        guard let raw = timeString?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return nil }
        if let r = parseColonFormat(raw) { return r }
        if let r = parseNaturalLanguage(raw) { return r }
        if let n = Int(raw) { return n }
        return nil
    }

    private static func parseColonFormat(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let m = Int(parts[1].trimmingCharacters(in: .whitespaces))
        else { return nil }
        return h * 60 + m
    }

    private static func parseNaturalLanguage(_ s: String) -> Int? {
        let lower = s.lowercased()
        var total = 0; var found = false
        if let r = lower.range(of: "([0-9]+)\\s*(?:hours?|hrs?)", options: .regularExpression) {
            if let h = Int(lower[r].filter(\.isNumber)) { total += h * 60; found = true }
        }
        if let r = lower.range(of: "([0-9]+)\\s*(?:minutes?|mins?)", options: .regularExpression) {
            if let m = Int(lower[r].filter(\.isNumber)) { total += m; found = true }
        }
        return found ? total : nil
    }
}
