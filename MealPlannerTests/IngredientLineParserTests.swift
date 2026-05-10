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
