import Foundation

public struct AppLocator {
    private let reader: SourceApplicationReader
    private let searchRoots: [URL]
    private let supportedBundleIdentifiers: Set<String>

    public init(
        reader: SourceApplicationReader = SourceApplicationReader(),
        searchRoots: [URL] = AppLocator.defaultSearchRoots,
        supportedBundleIdentifiers: Set<String> = [
            "com.tencent.xinWeChat",
            "com.tencent.WeWorkMac",
            "com.tencent.weworkmac"
        ]
    ) {
        self.reader = reader
        self.searchRoots = searchRoots
        self.supportedBundleIdentifiers = supportedBundleIdentifiers
    }

    public func locateSupportedApplications() -> [SourceApplication] {
        var results: [SourceApplication] = []
        let fileManager = FileManager.default

        for root in searchRoots where fileManager.fileExists(atPath: root.path) {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator where url.pathExtension == "app" {
                guard let app = try? reader.read(url) else {
                    continue
                }
                if supportedBundleIdentifiers.contains(app.bundleIdentifier) {
                    results.append(app)
                }
            }
        }

        return Array(Dictionary(grouping: results, by: { $0.url.path }).compactMap { $0.value.first })
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    public static var defaultSearchRoots: [URL] {
        var roots = [URL(fileURLWithPath: "/Applications", isDirectory: true)]
        roots.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true))
        return roots
    }
}
