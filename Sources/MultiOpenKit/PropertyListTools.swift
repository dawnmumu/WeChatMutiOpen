import Foundation

public struct PropertyListTools {
    public init() {}

    public func readDictionary(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return value as? [String: Any] ?? [:]
    }

    public func writeDictionary(_ dictionary: [String: Any], to url: URL) throws {
        let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
        try data.write(to: url, options: .atomic)
    }

    public func dictionary(fromPropertyListText text: String) throws -> [String: Any] {
        let data = Data(text.utf8)
        let value = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return value as? [String: Any] ?? [:]
    }
}
