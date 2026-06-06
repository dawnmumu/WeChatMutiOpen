import Foundation

public struct SourceApplication: Codable, Equatable, Identifiable, Sendable {
    public var id: String { bundleIdentifier }
    public let displayName: String
    public let bundleIdentifier: String
    public let executableName: String
    public let url: URL
    public let version: String?

    public init(
        displayName: String,
        bundleIdentifier: String,
        executableName: String,
        url: URL,
        version: String? = nil
    ) {
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.url = url
        self.version = version
    }
}

public struct ClonePlan: Codable, Equatable, Sendable {
    public let id: String
    public let sourceBundleIdentifier: String
    public let sourceURL: URL
    public let displayName: String
    public let appFileName: String
    public let bundleIdentifier: String
    public let executableName: String
    public let slug: String

    public init(
        id: String,
        sourceBundleIdentifier: String,
        sourceURL: URL,
        displayName: String,
        appFileName: String,
        bundleIdentifier: String,
        executableName: String,
        slug: String
    ) {
        self.id = id
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceURL = sourceURL
        self.displayName = displayName
        self.appFileName = appFileName
        self.bundleIdentifier = bundleIdentifier
        self.executableName = executableName
        self.slug = slug
    }
}

public struct CloneRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public var displayName: String
    public var bundleIdentifier: String
    public var sourceBundleIdentifier: String
    public var sourceVersion: String?
    public var sourcePath: String
    public var clonePath: String
    public var customIconPath: String?
    public var createdAt: Date
    public var lastRepairedAt: Date?

    public init(
        id: String,
        displayName: String,
        bundleIdentifier: String,
        sourceBundleIdentifier: String,
        sourceVersion: String? = nil,
        sourcePath: String,
        clonePath: String,
        customIconPath: String? = nil,
        createdAt: Date,
        lastRepairedAt: Date?
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceVersion = sourceVersion
        self.sourcePath = sourcePath
        self.clonePath = clonePath
        self.customIconPath = customIconPath
        self.createdAt = createdAt
        self.lastRepairedAt = lastRepairedAt
    }
}
