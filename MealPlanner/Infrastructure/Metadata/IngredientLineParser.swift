import Foundation

struct IngredientLine: Equatable {
    let quantity: IngredientQuantity?
    let unit: ResolvedUnit?
    let name: String
    let prep: String?
    let original: String
    let confidence: ParseConfidence
}

enum ParseConfidence: Equatable {
    case full, partial, unparseable
}

enum IngredientLineParser {
    /// Parse a freeform ingredient string into structured components.
    static func parse(_ input: String?) -> IngredientLine? {
        guard let raw = input?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return nil }

        // 1. Detect section headers
        if raw.hasPrefix("---") || raw.hasPrefix("**") || raw.hasPrefix("##") {
            return IngredientLine(quantity: nil, unit: nil, name: raw, prep: nil,
                                  original: raw, confidence: .unparseable)
        }

        // 2. Strip parentheticals, preserving inner content for promotion
        var innerQuantity: IngredientQuantity?
        var innerUnit: ResolvedUnit?
        var stripped = raw
        if let parenRange = findParenthetical(in: raw) {
            let inner = String(raw[parenRange]).dropFirst().dropLast()
                .trimmingCharacters(in: .whitespaces)
            // Try to parse inner as quantity + unit
            let innerTokens = inner.split(separator: " ").map(String.init)
            if let iq = QuantityParser.parse(innerTokens.first) {
                innerQuantity = iq
                if innerTokens.count > 1, let iu = UnitResolver.resolve(innerTokens[1]) {
                    innerUnit = iu
                } else if innerTokens.count == 1 {
                    // Try parsing the whole thing as a unit+quantity combo like "450g"
                    let numStr = inner.filter { $0.isNumber || $0 == "." }
                    let unitStr = inner.filter { !$0.isNumber && $0 != "." }
                    if let q = QuantityParser.parse(numStr), let u = UnitResolver.resolve(unitStr.trimmingCharacters(in: .whitespaces)) {
                        innerQuantity = q
                        innerUnit = u
                    }
                }
            } else {
                // Try "450g" format (no space)
                let numStr = inner.filter { $0.isNumber || $0 == "." }
                let unitStr = inner.filter { !$0.isNumber && $0 != "." }
                if !numStr.isEmpty, !unitStr.isEmpty,
                   let q = QuantityParser.parse(numStr),
                   let u = UnitResolver.resolve(unitStr.trimmingCharacters(in: .whitespaces)) {
                    innerQuantity = q
                    innerUnit = u
                }
            }
            // Remove parenthetical from the string
            stripped = raw[raw.startIndex..<parenRange.lowerBound].appending(
                raw[parenRange.upperBound...]
            ).trimmingCharacters(in: .whitespaces)
            // Collapse double spaces
            while stripped.contains("  ") {
                stripped = stripped.replacingOccurrences(of: "  ", with: " ")
            }
        }

        // 3. Tokenise
        let tokens = stripped.split(separator: " ").map(String.init)
        guard !tokens.isEmpty else {
            return IngredientLine(quantity: nil, unit: nil, name: raw, prep: nil,
                                  original: raw, confidence: .unparseable)
        }

        var idx = 0

        // 4. Parse quantity
        var quantity: IngredientQuantity?

        // Try mixed number: "1 1/2" (two tokens)
        if tokens.count >= 2 {
            let combined = tokens[0] + " " + tokens[1]
            if let q = QuantityParser.parse(combined), case .single = q {
                // Verify it's actually a mixed number (first is int, second is fraction)
                if Double(tokens[0]) != nil && tokens[1].contains("/") {
                    quantity = q
                    idx = 2
                }
            }
        }

        // Try single token quantity (including ranges like "2-3")
        if quantity == nil, let q = QuantityParser.parse(tokens[0]) {
            quantity = q
            idx = 1
        }

        guard quantity != nil else {
            // No quantity found — unparseable
            return IngredientLine(quantity: nil, unit: nil, name: raw, prep: nil,
                                  original: raw, confidence: .unparseable)
        }

        // 5. Parse unit
        var unit: ResolvedUnit?
        let remaining = Array(tokens[idx...])

        // Check 2-word unit first ("fl oz")
        if remaining.count >= 2 {
            let twoWord = remaining[0] + " " + remaining[1]
            if let u = UnitResolver.resolve(twoWord) {
                unit = u
                idx += 2
            }
        }

        // Single-word unit
        if unit == nil, !remaining.isEmpty, let u = UnitResolver.resolve(remaining[0]) {
            unit = u
            idx += 1
        }

        // 6. Apply parenthetical promotion
        // If outer unit is kitchen (!isMeasurable) and inner is measurable → swap
        if let outerUnit = unit, !outerUnit.isMeasurable,
           let iu = innerUnit, iu.isMeasurable, let iq = innerQuantity {
            quantity = iq
            unit = iu
            // Skip the kitchen unit word in the remaining name
            idx += 0 // already consumed
            // The kitchen unit word (e.g. "can") is at current idx position
            // We need to skip it from the name
            if idx < tokens.count, UnitResolver.resolve(tokens[idx]) != nil {
                // This shouldn't happen since we already consumed it
            }
        } else if unit == nil, let iu = innerUnit, iu.isMeasurable, let iq = innerQuantity {
            // No outer unit found, but inner has measurable unit — promote
            quantity = iq
            unit = iu
        }

        // If outer unit is measurable and inner is also measurable, just strip inner (keep outer)
        // This is already handled by removing the parenthetical from the string

        // 7. Build name from remaining tokens
        let nameTokens = Array(tokens[idx...])
        var nameAndPrep = nameTokens.joined(separator: " ")

        // Strip any leftover kitchen unit word after promotion
        // e.g. "1 (14 oz) can diced tomatoes" → after promotion qty=14, unit=oz, remaining="can diced tomatoes"
        // We need to remove "can" from the name
        if let iu = innerUnit, iu.isMeasurable, !nameTokens.isEmpty {
            if let firstWordUnit = UnitResolver.resolve(nameTokens[0]), !firstWordUnit.isMeasurable {
                // Drop the kitchen unit word
                nameAndPrep = nameTokens.dropFirst().joined(separator: " ")
            }
        }

        // 8. Extract prep (split on last comma)
        var name: String
        var prep: String?
        if let lastComma = nameAndPrep.lastIndex(of: ",") {
            name = String(nameAndPrep[nameAndPrep.startIndex..<lastComma])
                .trimmingCharacters(in: .whitespaces)
            prep = String(nameAndPrep[nameAndPrep.index(after: lastComma)...])
                .trimmingCharacters(in: .whitespaces)
            if prep?.isEmpty == true { prep = nil }
        } else {
            name = nameAndPrep
        }

        guard !name.isEmpty else {
            return IngredientLine(quantity: quantity, unit: unit, name: raw, prep: nil,
                                  original: raw, confidence: .unparseable)
        }

        // 9. Confidence
        let confidence: ParseConfidence
        if unit != nil {
            confidence = .full
        } else {
            confidence = .partial
        }

        return IngredientLine(quantity: quantity, unit: unit, name: name, prep: prep,
                              original: raw, confidence: confidence)
    }

    // MARK: - Helpers

    /// Find the first parenthetical expression in a string
    private static func findParenthetical(in s: String) -> Range<String.Index>? {
        guard let open = s.firstIndex(of: "("),
              let close = s[s.index(after: open)...].firstIndex(of: ")") else {
            return nil
        }
        return open..<s.index(after: close)
    }
}
