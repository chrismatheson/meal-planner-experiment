import XCTest
@testable import paprikaplanner

final class TimeParserTests: XCTestCase {
    func test_minutesOnly() {
        XCTAssertEqual(TimeParser.parseToMinutes("30 min"), 30)
        XCTAssertEqual(TimeParser.parseToMinutes("30 minutes"), 30)
        XCTAssertEqual(TimeParser.parseToMinutes("30 mins"), 30)
    }
    func test_hoursOnly() {
        XCTAssertEqual(TimeParser.parseToMinutes("1 hour"), 60)
        XCTAssertEqual(TimeParser.parseToMinutes("1 hr"), 60)
        XCTAssertEqual(TimeParser.parseToMinutes("2 hours"), 120)
    }
    func test_hoursAndMinutes() {
        XCTAssertEqual(TimeParser.parseToMinutes("1 hr 15 min"), 75)
        XCTAssertEqual(TimeParser.parseToMinutes("1 hour 30 minutes"), 90)
    }
    func test_colonFormat() {
        XCTAssertEqual(TimeParser.parseToMinutes("1:30"), 90)
        XCTAssertEqual(TimeParser.parseToMinutes("0:45"), 45)
    }
    func test_bareNumber() { XCTAssertEqual(TimeParser.parseToMinutes("90"), 90) }
    func test_unparseable() {
        XCTAssertNil(TimeParser.parseToMinutes(nil))
        XCTAssertNil(TimeParser.parseToMinutes(""))
        XCTAssertNil(TimeParser.parseToMinutes("quick"))
    }
    func test_whitespace() { XCTAssertEqual(TimeParser.parseToMinutes("  30 min  "), 30) }
}
