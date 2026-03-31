import Foundation

struct AppUpdateInfo: Decodable, Equatable {
    let version: String
    let publishedAt: Date
    let minimumSystemVersion: String
    let pageURL: URL
    let downloadURL: URL
    let notesMarkdown: String

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    var minimumSupportedSystemVersion: OperatingSystemVersion? {
        let parts = minimumSystemVersion.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...3).contains(parts.count) else {
            return nil
        }

        guard
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = parts.count == 3 ? Int(parts[2]) : 0
        else {
            return nil
        }

        return OperatingSystemVersion(
            majorVersion: major,
            minorVersion: minor,
            patchVersion: patch
        )
    }
}
