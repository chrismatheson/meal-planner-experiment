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
        XCTAssertEqual(normalise("2-3 cloves garlic, minced"), "2-3 clove garlic, minced")
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
