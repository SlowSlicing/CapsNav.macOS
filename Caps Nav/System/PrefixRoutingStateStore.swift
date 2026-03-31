import Foundation
import IOKit.hid

typealias HIDUserKeyMapping = [String: NSNumber]

struct PersistedHIDUserKeyMapping: Codable, Equatable {
    let srcKey: UInt64
    let dstKey: UInt64

    init?(mapping: HIDUserKeyMapping) {
        guard let srcKey = mapping[kIOHIDKeyboardModifierMappingSrcKey]?.uint64Value,
              let dstKey = mapping[kIOHIDKeyboardModifierMappingDstKey]?.uint64Value else {
            return nil
        }

        self.srcKey = srcKey
        self.dstKey = dstKey
    }

    var hidMapping: HIDUserKeyMapping {
        [
            kIOHIDKeyboardModifierMappingSrcKey: NSNumber(value: srcKey),
            kIOHIDKeyboardModifierMappingDstKey: NSNumber(value: dstKey)
        ]
    }
}

struct PersistedPrefixRoutingSnapshot: Codable, Equatable {
    let originalMappings: [PersistedHIDUserKeyMapping]
}

final class PrefixRoutingStateStore {
    private let fileURL: URL
    private let fileManager: FileManager

    var hasSnapshot: Bool {
        fileManager.fileExists(atPath: fileURL.path)
    }

    init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    func save(originalMappings: [HIDUserKeyMapping]) throws {
        let snapshot = PersistedPrefixRoutingSnapshot(
            originalMappings: originalMappings.compactMap(PersistedHIDUserKeyMapping.init(mapping:))
        )
        let data = try JSONEncoder.capsNav().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    func loadOriginalMappings() throws -> [HIDUserKeyMapping]? {
        guard hasSnapshot else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)
        let snapshot = try JSONDecoder.capsNav().decode(PersistedPrefixRoutingSnapshot.self, from: data)
        return snapshot.originalMappings.map(\.hidMapping)
    }

    func clear() throws {
        guard hasSnapshot else {
            return
        }

        try fileManager.removeItem(at: fileURL)
    }
}
