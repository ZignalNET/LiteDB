import XCTest
@testable import LiteDB

final class LiteDBTests: XCTestCase {
    func testExample() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(LiteDB().text, "Hello, World!")
    }
}