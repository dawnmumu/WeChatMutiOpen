import Foundation

public struct SourceApplicationReader {
    private let plistTools: PropertyListTools

    public init(plistTools: PropertyListTools = PropertyListTools()) {
        self.plistTools = plistTools
    }

    public func read(_ appURL: URL) throws -> SourceApplication {
        guard appURL.pathExtension == "app" else {
            throw MultiOpenError.invalidApplication(appURL)
        }

        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard FileManager.default.fileExists(atPath: infoURL.path) else {
            throw MultiOpenError.missingInfoPlist(infoURL)
        }

        let plist = try plistTools.readDictionary(from: infoURL)
        guard let bundleIdentifier = plist["CFBundleIdentifier"] as? String, !bundleIdentifier.isEmpty else {
            throw MultiOpenError.missingBundleIdentifier(infoURL)
        }
        guard let executableName = plist["CFBundleExecutable"] as? String, !executableName.isEmpty else {
            throw MultiOpenError.missingExecutableName(infoURL)
        }

        let displayName = (plist["CFBundleDisplayName"] as? String)
            ?? (plist["CFBundleName"] as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let shortVersion = plist["CFBundleShortVersionString"] as? String
        let buildVersion = plist["CFBundleVersion"] as? String
        let version: String?
        if let shortVersion, let buildVersion, shortVersion != buildVersion {
            version = "\(shortVersion) (\(buildVersion))"
        } else {
            version = shortVersion ?? buildVersion
        }

        return SourceApplication(
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            executableName: executableName,
            url: appURL,
            version: version
        )
    }
}
