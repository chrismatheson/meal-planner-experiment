import Foundation

struct ResolvedUnit: Equatable {
    let canonical: String    // "lb", "cup", "tbsp", "clove", etc.
    let isMeasurable: Bool   // true if maps to Apple Dimension (UnitMass/UnitVolume)
}

enum UnitResolver {
    // Case-sensitive single-char units
    private static let caseSensitiveUnits: [String: ResolvedUnit] = [
        "T": ResolvedUnit(canonical: "tbsp", isMeasurable: true),
        "t": ResolvedUnit(canonical: "tsp", isMeasurable: true),
    ]

    // All other aliases (matched case-insensitively)
    private static let aliases: [String: ResolvedUnit] = {
        var map = [String: ResolvedUnit]()
        let measurable: [(String, [String])] = [
            ("lb", ["lb", "lbs", "pound", "pounds"]),
            ("oz", ["oz", "ounce", "ounces"]),
            ("g", ["g", "gram", "grams"]),
            ("kg", ["kg", "kilogram", "kilograms"]),
            ("cup", ["cup", "cups", "c"]),
            ("tbsp", ["tbsp", "tablespoon", "tablespoons", "tbs"]),
            ("tsp", ["tsp", "teaspoon", "teaspoons"]),
            ("fl oz", ["fl oz", "fluid ounce", "fluid ounces"]),
            ("ml", ["ml", "milliliter", "milliliters"]),
            ("L", ["l", "liter", "liters", "litre", "litres"]),
            ("pint", ["pint", "pints", "pt"]),
            ("quart", ["quart", "quarts", "qt"]),
            ("gallon", ["gallon", "gallons", "gal"]),
        ]
        for (canonical, names) in measurable {
            let unit = ResolvedUnit(canonical: canonical, isMeasurable: true)
            for name in names { map[name] = unit }
        }
        let kitchen: [(String, [String])] = [
            ("pinch", ["pinch", "pinches"]),
            ("dash", ["dash", "dashes"]),
            ("clove", ["clove", "cloves"]),
            ("head", ["head", "heads"]),
            ("bunch", ["bunch", "bunches"]),
            ("can", ["can", "cans"]),
            ("slice", ["slice", "slices"]),
            ("piece", ["piece", "pieces", "pc", "pcs"]),
            ("sprig", ["sprig", "sprigs"]),
            ("stalk", ["stalk", "stalks"]),
            ("stick", ["stick", "sticks"]),
        ]
        for (canonical, names) in kitchen {
            let unit = ResolvedUnit(canonical: canonical, isMeasurable: false)
            for name in names { map[name] = unit }
        }
        return map
    }()

    static func resolve(_ input: String) -> ResolvedUnit? {
        // Check case-sensitive single-char first
        if input.count == 1, let unit = caseSensitiveUnits[input] { return unit }
        // Then case-insensitive lookup
        return aliases[input.lowercased()]
    }
}
