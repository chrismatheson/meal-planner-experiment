# Ingredient Line Normalisation

> **Status**: Proposal
> **Date**: 2026-05-10
> **Scope**: Parse freeform ingredient lines into structured components, rewrite them into a consistent canonical format, store locally with opt-in Paprika write-back
> **Depends on**: Recipe Metadata feature (inference engine, write-back plumbing)

## Problem

Paprika stores ingredients as a single freeform `String?` — one ingredient per line, no structure. Lines arrive in wildly inconsistent formats:

```
1 lb spaghetti
1/2 Cup Flour
4 large egg yolks
½ tsp salt
2   tablespoons   olive oil
Freshly ground black pepper
1 (14 oz) can diced tomatoes
Salt and pepper to taste
2-3 cloves garlic, minced
```

This blocks any feature that needs to reason about ingredients programmatically: shopping list aggregation, recipe scaling, smarter effort heuristics, duplicate detection. Today we can only *count* lines (`IngredientCounter`). We can't compare, merge, or transform them.

## Non-Goals

- **Nutritional data** — not in scope for this project
- **Ingredient database / lookup** — we normalise text, we don't map to a food ontology
- **Modifying the meaning** — if we can't parse a line confidently, we leave it untouched
- **Scaling or unit conversion** — future feature that *uses* the structured data; not part of this spec

## Solution

A three-stage pipeline, all pure functions:

```
Raw line  →  [Parse]  →  IngredientLine?  →  [Normalise]  →  String  →  [Reassemble]  →  Updated recipe text
```

### Stage 1: Parse — `IngredientLineParser`

Takes a single ingredient line string. Returns a structured `IngredientLine` or `nil` (unparseable).

```swift
struct IngredientLine: Equatable {
    let quantity: IngredientQuantity? // .single(1.5), .range(2, 3), nil for "Salt to taste"
    let unit: IngredientUnit?         // .cup, .tbsp, .lb, nil
    let name: String                  // "flour", "olive oil", "garlic"
    let prep: String?                 // "minced", "grated", "diced"
    let original: String              // the raw input line, preserved
    let confidence: ParseConfidence
}

enum IngredientQuantity: Equatable {
    case single(Double)               // 1.5
    case range(Double, Double)        // 2-3 → .range(2, 3)

    var displayString: String {
        switch self {
        case .single(let v): return v.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(v))" : "\(v)"
        case .range(let lo, let hi): return "\(lo.clean)-\(hi.clean)"
        }
    }
}

enum ParseConfidence {
    case full        // quantity + unit + name all parsed
    case partial     // some components parsed (e.g. name only, or quantity + name but no unit)
    case unparseable // nothing useful extracted — leave alone
}
```

#### Quantity parsing

| Input | Parsed | Notes |
|-------|--------|-------|
| `1` | `.single(1)` | Integer |
| `1.5` | `.single(1.5)` | Decimal |
| `1/2` | `.single(0.5)` | Fraction |
| `1 1/2` | `.single(1.5)` | Mixed number |
| `½` | `.single(0.5)` | Unicode vulgar fraction (½ ⅓ ¼ ⅔ ¾ ⅛) |
| `2-3` | `.range(2, 3)` | Range preserved as-is |
| (none) | nil | "Salt to taste" |

#### Unit recognition

Canonical set — all aliases map to one canonical short form:

| Canonical | Aliases | Apple Measurement |
|-----------|---------|-------------------|
| `lb` | `lb`, `lbs`, `pound`, `pounds` | `UnitMass.pounds` |
| `oz` | `oz`, `ounce`, `ounces` | `UnitMass.ounces` |
| `g` | `g`, `gram`, `grams` | `UnitMass.grams` |
| `kg` | `kg`, `kilogram`, `kilograms` | `UnitMass.kilograms` |
| `cup` | `cup`, `cups`, `c` | `UnitVolume.cups` |
| `tbsp` | `tbsp`, `tablespoon`, `tablespoons`, `tbs`, `T` | `UnitVolume.tablespoons` |
| `tsp` | `tsp`, `teaspoon`, `teaspoons`, `t` | `UnitVolume.teaspoons` |
| `fl oz` | `fl oz`, `fluid ounce`, `fluid ounces` | `UnitVolume.fluidOunces` |
| `ml` | `ml`, `mL`, `milliliter`, `milliliters` | `UnitVolume.milliliters` |
| `L` | `L`, `l`, `liter`, `liters`, `litre`, `litres` | `UnitVolume.liters` |
| `pint` | `pint`, `pints`, `pt` | `UnitVolume.pints` |
| `quart` | `quart`, `quarts`, `qt` | `UnitVolume.quarts` |
| `gallon` | `gallon`, `gallons`, `gal` | `UnitVolume.gallons` |

**Non-standard "kitchen" units** — recognised but no Apple Measurement mapping:

| Canonical | Aliases |
|-----------|---------|
| `pinch` | `pinch`, `pinches` |
| `dash` | `dash`, `dashes` |
| `clove` | `clove`, `cloves` |
| `head` | `head`, `heads` |
| `bunch` | `bunch`, `bunches` |
| `can` | `can`, `cans` |
| `slice` | `slice`, `slices` |
| `piece` | `piece`, `pieces`, `pc`, `pcs` |
| `sprig` | `sprig`, `sprigs` |
| `stalk` | `stalk`, `stalks` |
| `stick` | `stick`, `sticks` |

**Countable items** (no unit word): `4 eggs`, `2 onions` → quantity=4, unit=nil, name="eggs"

#### Prep/modifier extraction

Text after a comma at the end of the ingredient name is treated as prep notes:

| Input | Name | Prep |
|-------|------|------|
| `1 cup Pecorino Romano, grated` | `Pecorino Romano` | `grated` |
| `2 cloves garlic, minced` | `garlic` | `minced` |
| `1 onion, finely diced` | `onion` | `finely diced` |
| `1 lb spaghetti` | `spaghetti` | nil |

#### Parenthetical & duplicate unit stripping

When a line contains a parenthetical unit conversion — e.g. `1 lb (450g) chicken` or `1 (14 oz) can diced tomatoes` — the parser strips the parenthetical and keeps a single measurement. Preference order:

1. **Outer quantity + standard measurable unit** wins (if it maps to an Apple `Dimension`)
2. If the outer unit is a kitchen unit (`can`, `piece`) and the parenthetical is measurable (`oz`, `g`), **promote the parenthetical** to become the primary quantity/unit
3. If neither maps to a standard unit, keep the outer and drop the parenthetical

| Input | Output | Rule |
|-------|--------|------|
| `1 lb (450g) chicken` | `1 lb chicken` | outer is measurable, drop parens |
| `450g (1 lb) chicken` | `450 g chicken` | outer is measurable, drop parens |
| `1 (14 oz) can diced tomatoes` | `14 oz diced tomatoes` | promote measurable parens over `can` |
| `2 (6-inch) tortillas` | `2 tortillas` | non-unit parens, just strip |

This is lossy — we're choosing one representation. But the goal is a single parseable quantity+unit per line that downstream features can work with.

#### Size modifiers

Size words (`large`, `small`, `medium`) between quantity and name are kept as part of the ingredient name. They modify the ingredient, not the measurement.

| Input | Quantity | Unit | Name |
|-------|----------|------|------|
| `4 large egg yolks` | `.single(4)` | nil | `large egg yolks` |
| `1 small onion, diced` | `.single(1)` | nil | `small onion` |

#### Lines left untouched

These patterns get `confidence: .unparseable` and pass through unchanged:

- Section headers: `--- For the sauce ---`, `**Dressing:**`
- Freeform notes: `Salt and pepper to taste`, `Freshly ground black pepper`
- Empty / whitespace-only lines

### Stage 2: Normalise — `IngredientNormaliser`

Takes an `IngredientLine` and emits a canonical string. Rules:

1. **Quantity**: decimal form, trailing `.0` stripped (`1` not `1.0`, but `1.5` stays). Ranges preserved as `lo-hi`.
2. **Unit**: lowercase canonical form from the table above. `T` → `tbsp`, `t` → `tsp`.
3. **Name**: original casing preserved (proper nouns matter: `Pecorino Romano`)
4. **Prep**: appended after comma
5. **Whitespace**: single space between components, trimmed
6. **Parentheticals**: stripped; duplicate unit conversions collapsed to one unit (see Stage 1)

| Input | Output | Changed? |
|-------|--------|----------|
| `1/2 Cup Flour` | `0.5 cup Flour` | ✅ |
| `½ tsp salt` | `0.5 tsp salt` | ✅ |
| `2   tablespoons   olive oil` | `2 tbsp olive oil` | ✅ |
| `1 lb spaghetti` | `1 lb spaghetti` | ❌ already clean |
| `1 cup Pecorino Romano, grated` | `1 cup Pecorino Romano, grated` | ❌ already clean |
| `Freshly ground black pepper` | `Freshly ground black pepper` | ❌ unparseable, untouched |
| `2-3 cloves garlic, minced` | `2-3 cloves garlic, minced` | ❌ range preserved |
| `1 lb (450g) chicken` | `1 lb chicken` | ✅ parens stripped |
| `1 (14 oz) can diced tomatoes` | `14 oz diced tomatoes` | ✅ measurable unit promoted |
| `2 T olive oil` | `2 tbsp olive oil` | ✅ T → tbsp |

**Key principle: if a line is already in canonical form, `normalise(parse(line))` returns the original string unchanged.** This is idempotent — running normalisation twice produces the same result.

### Stage 3: Reassemble — `IngredientTextNormaliser`

Takes the full `ingredients` string, splits on newlines, runs parse+normalise on each line, joins back. Preserves blank lines (section separators).

```swift
enum IngredientTextNormaliser {
    /// Returns (normalisedText, stats) — nil text if nothing changed
    static func normalise(_ ingredientsText: String) -> NormalisationResult

    struct NormalisationResult {
        let text: String?           // nil if no lines changed (skip write-back)
        let totalLines: Int
        let normalisedLines: Int    // lines that were actually modified
        let unparseableLines: Int   // lines left untouched
    }
}
```

## Data Flow

### Storage

Normalised text is written to `RecipeModel.ingredients` in the local SwiftData cache. No new model needed — we're fixing up the existing field.

A new field tracks whether normalisation has been applied:

```swift
// Added to RecipeModel
var ingredientsNormalised: Bool  // default false, set true after normalisation pass
```

This prevents re-processing on every sync. Reset to `false` when a recipe's `apiHash` changes (meaning the source data changed in Paprika).

### Paprika write-back

Opt-in toggle in Settings (separate from the category write-back toggle):

```swift
@AppStorage("paprikaIngredientWriteBack") private var ingredientWriteBackEnabled = false
```

When enabled, after local normalisation, the normalised `ingredients` text is written back to Paprika via the existing `PaprikaClient.saveRecipe()` path. Only recipes where normalisation actually changed something are synced.

### Trigger

Runs as part of the intelligence engine pass:
1. **Post-sync**: after recipe sync, normalise any recipes where `ingredientsNormalised == false`
2. **Manual**: "Run Intelligence Now" button also triggers normalisation
3. **Idempotent**: running on an already-normalised recipe is a no-op (stats show 0 changed)

## Testing Strategy

### Unit tests (TDD, high priority)

**QuantityParser** (pure function):
- Integer, decimal, fraction, mixed number, unicode fraction, range → midpoint
- Edge cases: nil, empty, `"to taste"`, `"some"`

**UnitResolver** (pure function):
- All aliases resolve to canonical form
- Case-insensitive matching
- Unknown unit returns nil

**IngredientLineParser** (pure function):
- Standard lines: `"1 cup flour"` → quantity=1, unit=cup, name=flour
- With prep: `"2 cloves garlic, minced"` → prep=minced
- Countable: `"4 eggs"` → quantity=4, unit=nil, name=eggs
- Parenthetical: `"1 (14 oz) can diced tomatoes"`
- Unparseable: `"Salt to taste"`, `"Freshly ground black pepper"`
- Section headers: `"--- For the sauce ---"`

**IngredientNormaliser** (pure function):
- Fraction → decimal, unit alias → canonical, whitespace collapse
- Idempotency: `normalise(normalise(x)) == normalise(x)`
- Unparseable lines pass through unchanged

**IngredientTextNormaliser** (pure function):
- Multi-line normalisation with stats
- Blank line preservation
- Returns nil text when nothing changed

### Integration tests
- Normalisation runs after sync, sets `ingredientsNormalised = true`
- Re-sync with changed hash resets flag and re-normalises
- Write-back toggle controls Paprika sync

## Files to create

| File | Purpose |
|------|---------|
| `Infrastructure/Metadata/IngredientLineParser.swift` | Parse single line → `IngredientLine` |
| `Infrastructure/Metadata/IngredientNormaliser.swift` | `IngredientLine` → canonical string |
| `Infrastructure/Metadata/IngredientTextNormaliser.swift` | Full-text normalise + stats |
| `MealPlannerTests/IngredientLineParserTests.swift` | Parser tests |
| `MealPlannerTests/IngredientNormaliserTests.swift` | Normaliser + idempotency tests |

## Files to modify

| File | Change |
|------|--------|
| `SwiftDataModels.swift` | Add `ingredientsNormalised: Bool` to `RecipeModel` |
| `MetadataInferenceEngine.swift` | Call normalisation after effort inference |
| `RecipeSyncEngine.swift` | Reset `ingredientsNormalised` when hash changes |
| `RootView.swift` | Add ingredient write-back toggle in Settings |
| `RecipeDetailView.swift` | Display normalised ingredients (already does — just `Text(ingredients)`) |

## Design Decisions (Resolved)

1. **`T` vs `t`** — ✅ **Recognised.** `T` → `tbsp`, `t` → `tsp`. Case-sensitive single-character match only.

2. **Parenthetical quantities** — ✅ **Strip parentheticals.** Collapse duplicate unit conversions (e.g. `1 lb (450g)`) to a single unit. Prefer the measurable outer unit; promote a measurable parenthetical over a kitchen unit (`can`, `piece`). This is intentionally lossy — one parseable quantity+unit per line.

3. **Name casing** — ✅ **Preserve original.** Only lowercase the unit. Proper nouns (`Pecorino Romano`, `Worcestershire`) must survive.

4. **Range handling** — ✅ **Preserve ranges.** `2-3` stays as `.range(2, 3)` and renders as `2-3` in the normalised output. No midpoint conversion.

5. **Size modifiers** — ✅ **Keep in name.** `4 large eggs` normalises to `4 large eggs`. Stripping would lose meaning.
