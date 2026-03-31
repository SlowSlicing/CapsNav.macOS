import XCTest
@testable import Caps_Nav

final class AppUpdateDecodingTests: XCTestCase {
    func testDecodeLatestUpdateJSON() throws {
        let json = """
        {
          "version": "0.0.2",
          "publishedAt": "2026-03-31T20:00:00Z",
          "minimumSystemVersion": "13.0",
          "pageURL": "https://example.com/release",
          "downloadURL": "https://example.com/app.dmg",
          "notesMarkdown": "## 更新内容\\n\\n- 新增：测试"
        }
        """.data(using: .utf8)!

        let decoder = AppUpdateInfo.decoder
        let info = try decoder.decode(AppUpdateInfo.self, from: json)

        XCTAssertEqual(info.version, "0.0.2")
        XCTAssertEqual(info.minimumSystemVersion, "13.0")
        XCTAssertEqual(info.pageURL.absoluteString, "https://example.com/release")
        XCTAssertEqual(info.downloadURL.absoluteString, "https://example.com/app.dmg")
        XCTAssertEqual(info.notesMarkdown, "## 更新内容\n\n- 新增：测试")
    }

    func testFailsWhenRequiredFieldsMissing() {
        let json = """
        {
          "version": "0.0.2",
          "notesMarkdown": "## 更新内容"
        }
        """.data(using: .utf8)!

        XCTAssertThrowsError(
            try AppUpdateInfo.decoder.decode(AppUpdateInfo.self, from: json)
        )
    }
}
