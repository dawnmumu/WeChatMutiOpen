import Foundation

public struct ClonePlanner {
    private let slugifier: Slugifier
    private let bundlePrefix: String

    public init(
        slugifier: Slugifier = Slugifier(),
        bundlePrefix: String = "local.codex.macmultiopen"
    ) {
        self.slugifier = slugifier
        self.bundlePrefix = bundlePrefix
    }

    public func planClone(
        source: SourceApplication,
        requestedName: String?,
        existingCloneNames: [String]
    ) throws -> ClonePlan {
        let displayName = try resolveDisplayName(
            source: source,
            requestedName: requestedName,
            existingCloneNames: existingCloneNames
        )
        let slug = slugifier.slug(displayName)
        let sourceComponent = slugifier.bundleIdentifierComponent(source.bundleIdentifier)
        let bundleIdentifier = "\(bundlePrefix).\(sourceComponent).\(slug)"

        return ClonePlan(
            id: UUID().uuidString.lowercased(),
            sourceBundleIdentifier: source.bundleIdentifier,
            sourceURL: source.url,
            displayName: displayName,
            appFileName: "\(displayName).app",
            bundleIdentifier: bundleIdentifier,
            executableName: source.executableName,
            slug: slug
        )
    }

    public func planRepair(record: CloneRecord, source: SourceApplication) -> ClonePlan {
        ClonePlan(
            id: record.id,
            sourceBundleIdentifier: record.sourceBundleIdentifier,
            sourceURL: source.url,
            displayName: record.displayName,
            appFileName: URL(fileURLWithPath: record.clonePath).lastPathComponent,
            bundleIdentifier: record.bundleIdentifier,
            executableName: source.executableName,
            slug: record.bundleIdentifier.split(separator: ".").last.map(String.init) ?? slugifier.slug(record.displayName)
        )
    }

    private func resolveDisplayName(
        source: SourceApplication,
        requestedName: String?,
        existingCloneNames: [String]
    ) throws -> String {
        if let requestedName {
            let trimmed = requestedName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                throw MultiOpenError.invalidCloneName(requestedName)
            }
            guard !existingCloneNames.contains(trimmed) else {
                throw MultiOpenError.cloneNameAlreadyExists(trimmed)
            }
            return trimmed
        }

        var index = 1
        while true {
            let candidate = "\(source.displayName) 分身 \(index)"
            if !existingCloneNames.contains(candidate) {
                return candidate
            }
            index += 1
        }
    }
}
