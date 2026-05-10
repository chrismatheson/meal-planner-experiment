import Foundation

enum IngredientQuantity: Equatable {
    case single(Double)
    case range(Double, Double)

    var displayString: String {
        switch self {
        case .single(let v):
            return v.truncatingRemainder(dividingBy: 1) == 0
                ? "\(Int(v))" : String(format: "%g", v)
        case .range(let lo, let hi):
            let loStr = lo.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(lo))" : String(format: "%g", lo)
            let hiStr = hi.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(hi))" : String(format: "%g", hi)
            return "\(loStr)-\(hiStr)"
        }
    }
}

enum QuantityParser {
    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "⅓": 1.0/3.0, "⅔": 2.0/3.0,
        "¼": 0.25, "¾": 0.75, "⅕": 0.2, "⅖": 0.4,
        "⅗": 0.6, "⅘": 0.8, "⅙": 1.0/6.0, "⅚": 5.0/6.0,
        "⅐": 1.0/7.0, "⅛": 0.125, "⅜": 0.375, "⅝": 0.625, "⅞": 0.875,
        "⅑": 1.0/9.0, "⅒": 0.1,
    ]

    static func parse(_ input: String?) -> IngredientQuantity? {
        guard let s = input?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }

        // Try range first (2-3, 2 - 3, 2–3)
        let rangeSeparators = CharacterSet(charactersIn: "-–—")
        let rangeParts = s.components(separatedBy: rangeSeparators)
        if rangeParts.count == 2,
           let lo = parseSingleValue(rangeParts[0].trimmingCharacters(in: .whitespaces)),
           let hi = parseSingleValue(rangeParts[1].trimmingCharacters(in: .whitespaces)),
           lo < hi {
            return .range(lo, hi)
        }

        // Try single value
        if let v = parseSingleValue(s) { return .single(v) }
        return nil
    }

    private static func parseSingleValue(_ s: String) -> Double? {
        guard !s.isEmpty else { return nil }
        // Pure unicode fraction: "½"
        if s.count == 1, let v = unicodeFractions[s.first!] { return v }
        // Integer or decimal followed by unicode fraction: "1½"
        if let last = s.last, let frac = unicodeFractions[last],
           let whole = Double(s.dropLast().trimmingCharacters(in: .whitespaces)) {
            return whole + frac
        }
        // Slash fraction: "1/2"
        if s.contains("/") {
            let parts = s.split(separator: "/")
            if parts.count == 2, let n = Double(parts[0].trimmingCharacters(in: .whitespaces)),
               let d = Double(parts[1].trimmingCharacters(in: .whitespaces)), d != 0 {
                return n / d
            }
        }
        // Mixed number: "1 1/2"
        let tokens = s.split(separator: " ")
        if tokens.count == 2, let whole = Double(tokens[0]),
           tokens[1].contains("/") {
            let fracParts = tokens[1].split(separator: "/")
            if fracParts.count == 2, let n = Double(fracParts[0]), let d = Double(fracParts[1]), d != 0 {
                return whole + (n / d)
            }
        }
        // Plain number
        return Double(s)
    }
}
