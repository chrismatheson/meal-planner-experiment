import Foundation

enum IngredientNormaliser {
    /// Normalise a single ingredient line. Unparseable lines return unchanged.
    static func normalise(_ line: String) -> String {
        guard let parsed = IngredientLineParser.parse(line) else { return line }
        guard parsed.confidence != .unparseable else { return parsed.original }

        var parts: [String] = []

        // Quantity
        if let q = parsed.quantity {
            parts.append(q.displayString)
        }

        // Unit (canonical form)
        if let u = parsed.unit {
            parts.append(u.canonical)
        }

        // Name (original casing preserved)
        parts.append(parsed.name)

        var result = parts.joined(separator: " ")

        // Prep (after comma)
        if let prep = parsed.prep {
            result += ", \(prep)"
        }

        return result
    }
}
