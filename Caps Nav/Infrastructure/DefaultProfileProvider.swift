import Foundation

struct DefaultProfileProvider {
    let bundle: Bundle

    func loadDefaultProfileData() throws -> Data {
        if let bundledURL = bundle.url(forResource: "default-profile", withExtension: "json"),
           let bundledData = try? Data(contentsOf: bundledURL) {
            return bundledData
        }

        return try JSONEncoder.capsNav().encode(Profile.default)
    }
}
