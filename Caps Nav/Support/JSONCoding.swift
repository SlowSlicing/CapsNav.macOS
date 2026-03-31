import Foundation

extension JSONDecoder {
    static func capsNav() -> JSONDecoder {
        JSONDecoder()
    }
}

extension JSONEncoder {
    static func capsNav() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
