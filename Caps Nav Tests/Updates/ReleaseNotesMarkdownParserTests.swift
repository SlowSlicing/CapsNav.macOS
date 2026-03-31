import XCTest
@testable import Caps_Nav

final class ReleaseNotesMarkdownParserTests: XCTestCase {
    func testParsesCommonReleaseNotesBlocks() {
        let markdown = """
        # Caps Nav 0.0.2

        ## 亮点更新

        这次版本主要围绕 **在线检查更新** 做了一轮打通。

        - 新增：应用内 `检查更新`
        - 新增：更新弹窗支持块级 Markdown

        1. 优化了更新说明布局
        2. 优化了错误提示

        > 当前版本最低支持 `macOS 13.0+`

        ---

        ```swift
        print("Caps Nav")
        ```
        """

        let blocks = ReleaseNotesMarkdownParser.parse(markdown)

        XCTAssertEqual(blocks.count, 8)
        XCTAssertEqual(blocks[0], .heading(level: 1, text: "Caps Nav 0.0.2"))
        XCTAssertEqual(blocks[1], .heading(level: 2, text: "亮点更新"))
        XCTAssertEqual(blocks[2], .paragraph("这次版本主要围绕 **在线检查更新** 做了一轮打通。"))
        XCTAssertEqual(
            blocks[3],
            .unorderedList([
                "新增：应用内 `检查更新`",
                "新增：更新弹窗支持块级 Markdown",
            ])
        )
        XCTAssertEqual(
            blocks[4],
            .orderedList([
                ReleaseNotesOrderedListItem(marker: "1.", text: "优化了更新说明布局"),
                ReleaseNotesOrderedListItem(marker: "2.", text: "优化了错误提示"),
            ])
        )
        XCTAssertEqual(blocks[5], .blockquote("当前版本最低支持 `macOS 13.0+`"))
        XCTAssertEqual(blocks[6], .divider)
        XCTAssertEqual(
            blocks[7],
            .codeBlock(
                language: "swift",
                code: #"print("Caps Nav")"#
            )
        )
    }

    func testParsesCodeFenceUntilClosingFence() {
        let markdown = """
        ```text
        当前测试版本：0.0.2
        更新源：GitHub Pages
        ```
        """

        let blocks = ReleaseNotesMarkdownParser.parse(markdown)

        XCTAssertEqual(
            blocks,
            [
                .codeBlock(
                    language: "text",
                    code: """
                    当前测试版本：0.0.2
                    更新源：GitHub Pages
                    """
                ),
            ]
        )
    }
}
