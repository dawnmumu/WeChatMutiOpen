import Foundation

public final class CloneStore {
    public let storeURL: URL

    public init(storeURL: URL) {
        self.storeURL = storeURL
    }

    public func load() throws -> [CloneRecord] {
        guard FileManager.default.fileExists(atPath: storeURL.path) else {
            return []
        }
        let data = try Data(contentsOf: storeURL)
        return try JSONDecoder.multiOpen.decode([CloneRecord].self, from: data)
    }

    public func save(_ records: [CloneRecord]) throws {
        let parent = storeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try JSONEncoder.multiOpen.encode(records)
        try data.write(to: storeURL, options: .atomic)
    }
}

extension JSONEncoder {
    static var multiOpen: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

extension JSONDecoder {
    static var multiOpen: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
