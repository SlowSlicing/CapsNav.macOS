import XCTest
@testable import Caps_Nav

final class AppVersionTests: XCTestCase {
    func testSemanticVersionComparisonUsesNumericSegments() throws {
        let older = try XCTUnwrap(AppVersion("0.0.9"))
        let newer = try XCTUnwrap(AppVersion("0.0.10"))
        let major = try XCTUnwrap(AppVersion("1.0.0"))

        XCTAssertLessThan(older, newer)
        XCTAssertLessThan(newer, major)
    }

    func testRejectsInvalidVersionFormat() {
        XCTAssertNil(AppVersion("1.0"))
        XCTAssertNil(AppVersion("1.0.0.1"))
        XCTAssertNil(AppVersion("v1.0.0"))
        XCTAssertNil(AppVersion("1.a.0"))
    }
}
