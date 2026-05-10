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
