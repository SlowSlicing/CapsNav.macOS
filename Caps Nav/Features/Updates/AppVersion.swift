import Foundation

struct AppVersion: Comparable, Equatable, Hashable {
    let major: Int
    let minor: Int
    let patch: Int

    init?(_ rawValue: String) {
        let parts = rawValue.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            return nil
        }

        guard
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2])
        else {
            return nil
        }

        self.major = major
        self.minor = minor
        self.patch = patch
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }

        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }

        return lhs.patch < rhs.patch
    }
}
