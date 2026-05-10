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
