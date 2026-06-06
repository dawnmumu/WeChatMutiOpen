import Foundation

public struct CloneAppWriter {
    private let plistTools: PropertyListTools
    private let fileManager: FileManager

    public init(
        plistTools: PropertyListTools = PropertyListTools(),
        fileManager: FileManager = .default
    ) {
        self.plistTools = plistTools
        self.fileManager = fileManager
    }

    public func writeCloneApp(plan: ClonePlan, destination: URL) throws {
        try fileManager.copyItem(at: plan.sourceURL, to: destination)
        let infoURL = destination.appendingPathComponent("Contents/Info.plist")
        var plist = try plistTools.readDictionary(from: infoURL)

        plist["CFBundleIdentifier"] = plan.bundleIdentifier
        plist["CFBundleName"] = plan.displayName
        plist["CFBundleDisplayName"] = plan.displayName
        plist["LSMultipleInstancesProhibited"] = false

        if let urlTypes = plist["CFBundleURLTypes"] as? [[String: Any]] {
            plist["CFBundleURLTypes"] = urlTypes.map { item in
                var updated = item
                updated["CFBundleURLName"] = plan.bundleIdentifier
                if let schemes = item["CFBundleURLSchemes"] as? [String] {
                    updated["CFBundleURLSchemes"] = schemes.map { "\($0)-\(plan.slug)" }
                }
                return updated
            }
        }

        try plistTools.writeDictionary(plist, to: infoURL)
    }
}
