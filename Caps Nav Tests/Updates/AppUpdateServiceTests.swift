import XCTest
@testable import Caps_Nav

final class AppUpdateServiceTests: XCTestCase {
    override func tearDown() {
        super.tearDown()
        MockUpdateURLProtocol.responseProvider = nil
    }

    func testReturnsUpdateWhenRemoteVersionIsGreater() async {
        MockUpdateURLProtocol.responseProvider = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com/updates/latest.json")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!

            let payload = """
            {
              "version": "0.0.2",
              "publishedAt": "2026-03-31T20:00:00Z",
              "minimumSystemVersion": "13.0",
              "pageURL": "https://example.com/release",
              "downloadURL": "https://example.com/app.dmg",
              "notesMarkdown": "## 更新内容\\n\\n- 新增：测试"
            }
            """.data(using: .utf8)!

            return (response, payload)
        }

        let service = AppUpdateService(
            feedURL: URL(string: "https://example.com/updates/latest.json")!,
            urlSession: makeMockSession()
        )

        let result = await service.fetchLatestUpdate(currentVersion: AppVersion("0.0.1"))

        guard case let .updateAvailable(info) = result else {
            return XCTFail("期望返回 updateAvailable，实际为 \(result)")
        }

        XCTAssertEqual(info.version, "0.0.2")
    }

    func testTreatsNonSuccessStatusCodeAsFailure() async {
        MockUpdateURLProtocol.responseProvider = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com/updates/latest.json")!,
                statusCode: 404,
                httpVersion: nil,
                headerFields: nil
            )!

            let payload = Data("not found".utf8)
            return (response, payload)
        }

        let service = AppUpdateService(
            feedURL: URL(string: "https://example.com/updates/latest.json")!,
            urlSession: makeMockSession()
        )

        let result = await service.fetchLatestUpdate(currentVersion: AppVersion("0.0.1"))

        guard case let .failed(message) = result else {
            return XCTFail("期望返回 failed，实际为 \(result)")
        }

        XCTAssertTrue(message.contains("404"))
    }

    private func makeMockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockUpdateURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockUpdateURLProtocol: URLProtocol {
    static var responseProvider: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let responseProvider = Self.responseProvider else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try responseProvider(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
