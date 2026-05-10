# Ingredient Normalisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Parse freeform Paprika ingredient lines into structured components, normalise them into a consistent canonical format, write back locally (and optionally to Paprika).

**Architecture:** Three pure-function stages (parse → normalise → reassemble) with no SwiftData dependency in the core logic. Integration layer hooks into existing `MetadataInferenceEngine` lifecycle.

**Tech Stack:** Swift, XCTest, structured concurrency

**Spec:** `Docs/superpowers/specs/2026-05-10-ingredient-normalisation-design.md`

**Test target name:** `MealPlannerTests`
**Module import:** `@testable import paprikaplanner`
**Test command:** `xcodebuild test -scheme PaprikaPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MealPlannerTests/<TestClass> 2>&1 | tail -30`

---

### Task 1: QuantityParser — parse quantity tokens from ingredient lines

**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/QuantityParser.swift`
- Create: `MealPlannerTests/QuantityParserTests.swift`

- [ ] **Step 1: Write failing tests for QuantityParser**

Create `MealPlannerTests/QuantityParserTests.swift`:

```swift
import XCTest
@testable import paprikaplanner

final class QuantityParserTests: XCTestCase {
    // MARK: - Single values
    func test_integer() { XCTAssertEqual(QuantityParser.parse("1"), .single(1)) }
    func test_decimal() { XCTAssertEqual(QuantityParser.parse("1.5"), .single(1.5)) }
    func test_fraction() { XCTAssertEqual(QuantityParser.parse("1/2"), .single(0.5)) }
    func test_fraction_third() { XCTAssertEqual(QuantityParser.parse("1/3"), .single(1.0/3.0)) }
    func test_mixedNumber() { XCTAssertEqual(QuantityParser.parse("1 1/2"), .single(1.5)) }
    func test_mixedNumber_noSpace() { XCTAssertEqual(QuantityParser.parse("1½"), .single(1.5)) }

    // MARK: - Unicode fractions
    func test_unicodeHalf() { XCTAssertEqual(QuantityParser.parse("½"), .single(0.5)) }
    func test_unicodeThird() { XCTAssertEqual(QuantityParser.parse("⅓"), .single(1.0/3.0)) }
    func test_unicodeQuarter() { XCTAssertEqual(QuantityParser.parse("¼"), .single(0.25)) }
    func test_unicodeTwoThirds() { XCTAssertEqual(QuantityParser.parse("⅔"), .single(2.0/3.0)) }
    func test_unicodeThreeQuarters() { XCTAssertEqual(QuantityParser.parse("¾"), .single(0.75)) }
    func test_unicodeEighth() { XCTAssertEqual(QuantityParser.parse("⅛"), .single(0.125)) }

    // MARK: - Ranges
    func test_range() { XCTAssertEqual(QuantityParser.parse("2-3"), .range(2, 3)) }
    func test_rangeWithSpaces() { XCTAssertEqual(QuantityParser.parse("2 - 3"), .range(2, 3)) }
    func test_rangeEnDash() { XCTAssertEqual(QuantityParser.parse("2–3"), .range(2, 3)) }

    // MARK: - Nil / invalid
    func test_nil() { XCTAssertNil(QuantityParser.parse(nil)) }
    func test_empty() { XCTAssertNil(QuantityParser.parse("")) }
    func test_word() { XCTAssertNil(QuantityParser.parse("some")) }
    func test_toTaste() { XCTAssertNil(QuantityParser.parse("to taste")) }
}
```

- [ ] **Step 2: Run tests — expect compile error** (`Cannot find 'QuantityParser' in scope`)

- [ ] **Step 3: Implement QuantityParser and IngredientQuantity**

Create `MealPlanner/Infrastructure/Metadata/QuantityParser.swift`:

```swift
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
        // Mixed number: "1 1/2" — caller should split before calling parseSingleValue
        // But handle "1 1/2" as a whole string:
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
```

- [ ] **Step 4: Run tests — all pass**
- [ ] **Step 5: Commit**

---

### Task 2: UnitResolver — map unit aliases to canonical forms

**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/UnitResolver.swift`
- Create: `MealPlannerTests/UnitResolverTests.swift`

- [ ] **Step 1: Write failing tests for UnitResolver**

Create `MealPlannerTests/UnitResolverTests.swift`:

```swift
import XCTest
@testable import paprikaplanner

final class UnitResolverTests: XCTestCase {
    // MARK: - Standard units (Apple Measurement mappable)
    func test_lb() { XCTAssertEqual(UnitResolver.resolve("lb")?.canonical, "lb") }
    func test_lbs() { XCTAssertEqual(UnitResolver.resolve("lbs")?.canonical, "lb") }
    func test_pound() { XCTAssertEqual(UnitResolver.resolve("pound")?.canonical, "lb") }
    func test_pounds() { XCTAssertEqual(UnitResolver.resolve("pounds")?.canonical, "lb") }
    func test_oz() { XCTAssertEqual(UnitResolver.resolve("oz")?.canonical, "oz") }
    func test_ounce() { XCTAssertEqual(UnitResolver.resolve("ounce")?.canonical, "oz") }
    func test_gram() { XCTAssertEqual(UnitResolver.resolve("gram")?.canonical, "g") }
    func test_grams() { XCTAssertEqual(UnitResolver.resolve("grams")?.canonical, "g") }
    func test_cup() { XCTAssertEqual(UnitResolver.resolve("cup")?.canonical, "cup") }
    func test_cups() { XCTAssertEqual(UnitResolver.resolve("cups")?.canonical, "cup") }
    func test_tablespoon() { XCTAssertEqual(UnitResolver.resolve("tablespoon")?.canonical, "tbsp") }
    func test_tbs() { XCTAssertEqual(UnitResolver.resolve("tbs")?.canonical, "tbsp") }
    func test_teaspoon() { XCTAssertEqual(UnitResolver.resolve("teaspoon")?.canonical, "tsp") }

    // MARK: - Case-sensitive T/t
    func test_T_tablespoon() { XCTAssertEqual(UnitResolver.resolve("T")?.canonical, "tbsp") }
    func test_t_teaspoon() { XCTAssertEqual(UnitResolver.resolve("t")?.canonical, "tsp") }

    // MARK: - Kitchen units
    func test_clove() { XCTAssertEqual(UnitResolver.resolve("clove")?.canonical, "clove") }
    func test_cloves() { XCTAssertEqual(UnitResolver.resolve("cloves")?.canonical, "clove") }
    func test_can() { XCTAssertEqual(UnitResolver.resolve("can")?.canonical, "can") }
    func test_cans() { XCTAssertEqual(UnitResolver.resolve("cans")?.canonical, "can") }
    func test_pinch() { XCTAssertEqual(UnitResolver.resolve("pinch")?.canonical, "pinch") }
    func test_slice() { XCTAssertEqual(UnitResolver.resolve("slice")?.canonical, "slice") }

    // MARK: - Case insensitive (except T/t)
    func test_caseInsensitive_CUP() { XCTAssertEqual(UnitResolver.resolve("CUP")?.canonical, "cup") }
    func test_caseInsensitive_Tablespoon() { XCTAssertEqual(UnitResolver.resolve("Tablespoon")?.canonical, "tbsp") }

    // MARK: - Measurable flag
    func test_lb_isMeasurable() { XCTAssertTrue(UnitResolver.resolve("lb")!.isMeasurable) }
    func test_cup_isMeasurable() { XCTAssertTrue(UnitResolver.resolve("cup")!.isMeasurable) }
    func test_clove_isNotMeasurable() { XCTAssertFalse(UnitResolver.resolve("clove")!.isMeasurable) }
    func test_can_isNotMeasurable() { XCTAssertFalse(UnitResolver.resolve("can")!.isMeasurable) }

    // MARK: - Unknown
    func test_unknown() { XCTAssertNil(UnitResolver.resolve("eggs")) }
    func test_unknown_large() { XCTAssertNil(UnitResolver.resolve("large")) }
}
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Implement UnitResolver**

Create `MealPlanner/Infrastructure/Metadata/UnitResolver.swift`:

```swift
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
```

- [ ] **Step 4: Run tests — all pass**
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/UnitResolver.swift MealPlannerTests/UnitResolverTests.swift
git commit -m "feat: UnitResolver — map unit aliases to canonical forms"
```

---

### Task 3: IngredientLineParser — parse a single ingredient line into structured components

**Deps:** Task 1, Task 2
**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/IngredientLineParser.swift`
- Create: `MealPlannerTests/IngredientLineParserTests.swift`

- [ ] **Step 1: Write failing tests**

Create `MealPlannerTests/IngredientLineParserTests.swift`:

```swift
import XCTest
@testable import paprikaplanner

final class IngredientLineParserTests: XCTestCase {
    // MARK: - Full confidence (quantity + unit + name)
    func test_standard() {
        let r = IngredientLineParser.parse("1 cup flour")!
        XCTAssertEqual(r.quantity, .single(1))
        XCTAssertEqual(r.unit?.canonical, "cup")
        XCTAssertEqual(r.name, "flour")
        XCTAssertNil(r.prep)
        XCTAssertEqual(r.confidence, .full)
    }
    func test_fractionalQuantity() {
        let r = IngredientLineParser.parse("1/2 lb spaghetti")!
        XCTAssertEqual(r.quantity, .single(0.5))
        XCTAssertEqual(r.unit?.canonical, "lb")
        XCTAssertEqual(r.name, "spaghetti")
    }
    func test_unicodeFraction() {
        let r = IngredientLineParser.parse("½ tsp salt")!
        XCTAssertEqual(r.quantity, .single(0.5))
        XCTAssertEqual(r.unit?.canonical, "tsp")
        XCTAssertEqual(r.name, "salt")
    }
    func test_withPrep() {
        let r = IngredientLineParser.parse("2 cloves garlic, minced")!
        XCTAssertEqual(r.quantity, .single(2))
        XCTAssertEqual(r.unit?.canonical, "clove")
        XCTAssertEqual(r.name, "garlic")
        XCTAssertEqual(r.prep, "minced")
    }
    func test_range() {
        let r = IngredientLineParser.parse("2-3 cloves garlic")!
        XCTAssertEqual(r.quantity, .range(2, 3))
        XCTAssertEqual(r.unit?.canonical, "clove")
        XCTAssertEqual(r.name, "garlic")
    }
    func test_T_tablespoon() {
        let r = IngredientLineParser.parse("2 T olive oil")!
        XCTAssertEqual(r.unit?.canonical, "tbsp")
    }
    func test_excessWhitespace() {
        let r = IngredientLineParser.parse("2   tablespoons   olive oil")!
        XCTAssertEqual(r.quantity, .single(2))
        XCTAssertEqual(r.unit?.canonical, "tbsp")
        XCTAssertEqual(r.name, "olive oil")
    }
    func test_multiWordUnit() {
        let r = IngredientLineParser.parse("2 fl oz vanilla extract")!
        XCTAssertEqual(r.unit?.canonical, "fl oz")
        XCTAssertEqual(r.name, "vanilla extract")
    }

    // MARK: - Parenthetical stripping
    func test_parenthetical_outerMeasurable() {
        let r = IngredientLineParser.parse("1 lb (450g) chicken")!
        XCTAssertEqual(r.quantity, .single(1))
        XCTAssertEqual(r.unit?.canonical, "lb")
        XCTAssertEqual(r.name, "chicken")
    }
    func test_parenthetical_promoteMeasurable() {
        let r = IngredientLineParser.parse("1 (14 oz) can diced tomatoes")!
        XCTAssertEqual(r.quantity, .single(14))
        XCTAssertEqual(r.unit?.canonical, "oz")
        XCTAssertEqual(r.name, "diced tomatoes")
    }
    func test_parenthetical_nonUnit() {
        let r = IngredientLineParser.parse("2 (6-inch) tortillas")!
        XCTAssertEqual(r.quantity, .single(2))
        XCTAssertNil(r.unit)
        XCTAssertEqual(r.name, "tortillas")
    }

    // MARK: - Partial confidence (quantity + name, no unit)
    func test_countable() {
        let r = IngredientLineParser.parse("4 eggs")!
        XCTAssertEqual(r.quantity, .single(4))
        XCTAssertNil(r.unit)
        XCTAssertEqual(r.name, "eggs")
        XCTAssertEqual(r.confidence, .partial)
    }
    func test_sizeModifier() {
        let r = IngredientLineParser.parse("4 large egg yolks")!
        XCTAssertEqual(r.quantity, .single(4))
        XCTAssertNil(r.unit)
        XCTAssertEqual(r.name, "large egg yolks")
    }

    // MARK: - Unparseable
    func test_unparseable_freeform() {
        let r = IngredientLineParser.parse("Salt and pepper to taste")!
        XCTAssertEqual(r.confidence, .unparseable)
    }
    func test_unparseable_sectionHeader() {
        let r = IngredientLineParser.parse("--- For the sauce ---")!
        XCTAssertEqual(r.confidence, .unparseable)
    }
    func test_nil() { XCTAssertNil(IngredientLineParser.parse(nil)) }
    func test_empty() { XCTAssertNil(IngredientLineParser.parse("")) }
    func test_whitespaceOnly() { XCTAssertNil(IngredientLineParser.parse("   ")) }
}
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Implement IngredientLineParser**

Create `MealPlanner/Infrastructure/Metadata/IngredientLineParser.swift`:

The parser logic (in pseudocode for the implementer):

```swift
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
    static func parse(_ input: String?) -> IngredientLine? {
        guard let raw = input?.trimmingCharacters(in: .whitespaces),
              !raw.isEmpty else { return nil }

        // 1. Detect section headers (lines starting with ---, **, etc.)
        //    → return IngredientLine(confidence: .unparseable, original: raw)

        // 2. Strip parentheticals: find "(stuff)" patterns
        //    Parse inner content for quantity+unit
        //    Store outer and inner resolved units for promotion logic later

        // 3. Split remaining into tokens
        //    Consume leading tokens as quantity (QuantityParser)
        //    Next token(s) as unit (UnitResolver — check 2-word "fl oz" first)

        // 4. Apply parenthetical promotion:
        //    If outer unit is kitchen (!isMeasurable) and inner is measurable
        //    → swap: use inner quantity+unit, drop outer unit word from name

        // 5. Extract prep: split name on last comma
        //    "garlic, minced" → name: "garlic", prep: "minced"

        // 6. Determine confidence:
        //    quantity + unit + name → .full
        //    quantity + name (no unit) → .partial
        //    no quantity → .unparseable

        // 7. Return IngredientLine
    }
}
```

Implementation notes:
- Tokenise on whitespace after stripping parentheticals
- Try consuming first token as quantity via `QuantityParser.parse()`
- If quantity found, try next token(s) as unit via `UnitResolver.resolve()`
- Check 2-word units first (`fl oz` = tokens[1] + " " + tokens[2])
- Everything remaining after quantity+unit is the ingredient name
- Split name on last comma for prep extraction
- If no quantity is found at all, mark as `.unparseable`

- [ ] **Step 4: Run tests — all pass**
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/IngredientLineParser.swift MealPlannerTests/IngredientLineParserTests.swift
git commit -m "feat: IngredientLineParser — parse ingredient lines into structured components"
```

---

### Task 4: IngredientNormaliser — emit canonical string from parsed line

**Deps:** Task 3
**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/IngredientNormaliser.swift`
- Create: `MealPlannerTests/IngredientNormaliserTests.swift`

- [ ] **Step 1: Write failing tests**

Create `MealPlannerTests/IngredientNormaliserTests.swift`:

```swift
import XCTest
@testable import paprikaplanner

final class IngredientNormaliserTests: XCTestCase {
    // MARK: - Normalisation
    func test_fractionToDecimal() {
        XCTAssertEqual(normalise("1/2 Cup Flour"), "0.5 cup Flour")
    }
    func test_unicodeFraction() {
        XCTAssertEqual(normalise("½ tsp salt"), "0.5 tsp salt")
    }
    func test_unitAlias() {
        XCTAssertEqual(normalise("2 tablespoons olive oil"), "2 tbsp olive oil")
    }
    func test_whitespaceCollapse() {
        XCTAssertEqual(normalise("2   tablespoons   olive oil"), "2 tbsp olive oil")
    }
    func test_T_to_tbsp() {
        XCTAssertEqual(normalise("2 T olive oil"), "2 tbsp olive oil")
    }
    func test_rangePreserved() {
        XCTAssertEqual(normalise("2-3 cloves garlic, minced"), "2-3 cloves garlic, minced")
    }
    func test_parenthetical_stripped() {
        XCTAssertEqual(normalise("1 lb (450g) chicken"), "1 lb chicken")
    }
    func test_parenthetical_promoted() {
        XCTAssertEqual(normalise("1 (14 oz) can diced tomatoes"), "14 oz diced tomatoes")
    }
    func test_prepPreserved() {
        XCTAssertEqual(normalise("1 cup Pecorino Romano, grated"), "1 cup Pecorino Romano, grated")
    }
    func test_alreadyClean_unchanged() {
        XCTAssertEqual(normalise("1 lb spaghetti"), "1 lb spaghetti")
    }
    func test_unparseableLine_passthrough() {
        XCTAssertEqual(normalise("Freshly ground black pepper"), "Freshly ground black pepper")
    }

    // MARK: - Idempotency
    func test_idempotent_fraction() {
        let once = normalise("1/2 Cup Flour")
        XCTAssertEqual(normalise(once), once)
    }
    func test_idempotent_parenthetical() {
        let once = normalise("1 (14 oz) can diced tomatoes")
        XCTAssertEqual(normalise(once), once)
    }
    func test_idempotent_range() {
        let once = normalise("2-3 cloves garlic, minced")
        XCTAssertEqual(normalise(once), once)
    }

    private func normalise(_ input: String) -> String {
        IngredientNormaliser.normalise(input)
    }
}
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Implement IngredientNormaliser**

Create `MealPlanner/Infrastructure/Metadata/IngredientNormaliser.swift`:

```swift
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

        // Unit (canonical, lowercase)
        if let u = parsed.unit {
            parts.append(u.canonical)
        }

        // Name (original casing)
        parts.append(parsed.name)

        var result = parts.joined(separator: " ")

        // Prep (after comma)
        if let prep = parsed.prep {
            result += ", \(prep)"
        }

        return result
    }
}
```

- [ ] **Step 4: Run tests — all pass**
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/IngredientNormaliser.swift MealPlannerTests/IngredientNormaliserTests.swift
git commit -m "feat: IngredientNormaliser — emit canonical strings from parsed lines"
```

---

### Task 5: IngredientTextNormaliser — full recipe text normalisation with stats

**Deps:** Task 4
**Files:**
- Create: `MealPlanner/Infrastructure/Metadata/IngredientTextNormaliser.swift`
- Add tests to: `MealPlannerTests/IngredientNormaliserTests.swift`

- [ ] **Step 1: Add failing tests to IngredientNormaliserTests**

Append to `MealPlannerTests/IngredientNormaliserTests.swift`:

```swift
// MARK: - IngredientTextNormaliser tests (in same file)

final class IngredientTextNormaliserTests: XCTestCase {
    func test_multiLine_normalisesEachLine() {
        let input = "1/2 Cup Flour\n2 tablespoons olive oil\n1 lb spaghetti"
        let result = IngredientTextNormaliser.normalise(input)
        XCTAssertEqual(result.text, "0.5 cup Flour\n2 tbsp olive oil\n1 lb spaghetti")
        XCTAssertEqual(result.totalLines, 3)
        XCTAssertEqual(result.normalisedLines, 2) // flour + olive oil changed, spaghetti unchanged
        XCTAssertEqual(result.unparseableLines, 0)
    }

    func test_preservesBlankLines() {
        let input = "1 cup flour\n\n2 eggs"
        let result = IngredientTextNormaliser.normalise(input)
        XCTAssertTrue(result.text!.contains("\n\n"))
    }

    func test_unparseableLinesInStats() {
        let input = "1 cup flour\nSalt to taste\nFreshly ground pepper"
        let result = IngredientTextNormaliser.normalise(input)
        XCTAssertEqual(result.unparseableLines, 2)
    }

    func test_nothingChanged_returnsNilText() {
        let input = "1 lb spaghetti\n4 eggs"
        let result = IngredientTextNormaliser.normalise(input)
        XCTAssertNil(result.text, "Already-clean text should return nil")
    }

    func test_nilInput_returnsNilText() {
        let result = IngredientTextNormaliser.normalise(nil)
        XCTAssertNil(result.text)
        XCTAssertEqual(result.totalLines, 0)
    }
}
```

- [ ] **Step 2: Run tests — expect compile error**

- [ ] **Step 3: Implement IngredientTextNormaliser**

Create `MealPlanner/Infrastructure/Metadata/IngredientTextNormaliser.swift`:

```swift
import Foundation

enum IngredientTextNormaliser {
    struct NormalisationResult {
        let text: String?           // nil if no lines changed
        let totalLines: Int
        let normalisedLines: Int    // lines actually modified
        let unparseableLines: Int   // lines left untouched (no quantity found)
    }

    static func normalise(_ ingredientsText: String?) -> NormalisationResult {
        guard let input = ingredientsText, !input.isEmpty else {
            return NormalisationResult(text: nil, totalLines: 0, normalisedLines: 0, unparseableLines: 0)
        }

        let lines = input.components(separatedBy: "\n")
        var outputLines: [String] = []
        var normalisedCount = 0
        var unparseableCount = 0
        var anyChanged = false

        for line in lines {
            // Preserve blank lines as-is
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else {
                outputLines.append(line)
                continue
            }

            let normalised = IngredientNormaliser.normalise(line)

            // Check if the parsed line was unparseable
            if let parsed = IngredientLineParser.parse(line), parsed.confidence == .unparseable {
                unparseableCount += 1
            }

            if normalised != line {
                anyChanged = true
                normalisedCount += 1
            }
            outputLines.append(normalised)
        }

        let nonBlankLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count

        return NormalisationResult(
            text: anyChanged ? outputLines.joined(separator: "\n") : nil,
            totalLines: nonBlankLines,
            normalisedLines: normalisedCount,
            unparseableLines: unparseableCount
        )
    }
}
```

- [ ] **Step 4: Run tests — all pass**
- [ ] **Step 5: Commit**
```bash
git add MealPlanner/Infrastructure/Metadata/IngredientTextNormaliser.swift MealPlannerTests/IngredientNormaliserTests.swift
git commit -m "feat: IngredientTextNormaliser — full recipe text normalisation with stats"
```

---

### Task 6: Integration — wire normalisation into MetadataInferenceEngine and UI

**Deps:** Task 5
**Files:**
- Modify: `MealPlanner/Infrastructure/Metadata/MetadataInferenceEngine.swift`
- Modify: `MealPlanner/Infrastructure/Metadata/MetadataInferenceState.swift`
- Modify: `MealPlanner/App/RootView.swift` (settings section)
- Modify: `MealPlanner/Infrastructure/Sync/RecipeSyncEngine.swift` (if needed)

- [ ] **Step 1: Add normalisation pass to MetadataInferenceEngine**

In `MetadataInferenceEngine`, after the existing effort/kid-friendly classification:

```swift
// After classification pass, run normalisation on each recipe's ingredients
for recipe in recipes {
    let result = IngredientTextNormaliser.normalise(recipe.ingredients)
    if let normalisedText = result.text {
        recipe.ingredients = normalisedText
        // Mark recipe as needing sync-back if write-back is enabled
    }
}
```

Key decisions:
- Normalisation runs as part of the same inference pass (not a separate button)
- Only writes to local SwiftData model; Paprika write-back uses existing `CategoryWriteBackEngine` pattern
- Stats (normalisedLines, unparseableLines) logged but not persisted per-recipe

- [ ] **Step 2: Add a toggle in Settings for ingredient normalisation**

In `RootView.swift` settings section, add a toggle:
```swift
Toggle(isOn: $ingredientNormalisationEnabled) {
    Label("Normalise ingredients", systemImage: "text.alignleft")
}
```

Use `@AppStorage("ingredientNormalisationEnabled") private var ingredientNormalisationEnabled = true`

- [ ] **Step 3: Add normalisation stats to MetadataInferenceState**

Add properties to track normalisation results:
```swift
@Published var lastNormalisationStats: (total: Int, normalised: Int, unparseable: Int)?
```

- [ ] **Step 4: Build and verify no compiler errors**
- [ ] **Step 5: Commit**
```bash
git add -A
git commit -m "feat: wire ingredient normalisation into inference engine and settings"
```

---

### Task 7: Verification — end-to-end testing and version bump

**Deps:** Task 6

- [ ] **Step 1: Run full test suite**
```bash
xcodebuild test -scheme PaprikaPlanner -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -50
```
All tests must pass (existing + new).

- [ ] **Step 2: Build in Xcode — verify clean build**

- [ ] **Step 3: Version bump**
```bash
./scripts/bump-version.sh
```

- [ ] **Step 4: Commit and push**
```bash
git add -A
git commit -m "chore: version bump after ingredient normalisation"
git push
```