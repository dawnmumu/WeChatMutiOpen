import Foundation

public final class CloneService {
    public struct Configuration: Equatable {
        public let supportRoot: URL
        public let clonesRoot: URL

        public init(supportRoot: URL, clonesRoot: URL) {
            self.supportRoot = supportRoot
            self.clonesRoot = clonesRoot
        }

        public var storeURL: URL {
            supportRoot.appendingPathComponent("clones.json")
        }

        public static var `default`: Configuration {
            let home = FileManager.default.homeDirectoryForCurrentUser
            return Configuration(
                supportRoot: home.appendingPathComponent("Library/Application Support/MacMultiOpen", isDirectory: true),
                clonesRoot: home.appendingPathComponent("Applications/MacMultiOpen", isDirectory: true)
            )
        }
    }

    public let configuration: Configuration
    private let shell: ShellRunning
    private let reader: SourceApplicationReader
    private let planner: ClonePlanner
    private let cloneWriter: CloneAppWriter
    private let store: CloneStore
    private let fileManager: FileManager

    public init(
        configuration: Configuration = .default,
        shell: ShellRunning = SystemShellRunner(),
        reader: SourceApplicationReader = SourceApplicationReader(),
        planner: ClonePlanner = ClonePlanner(),
        cloneWriter: CloneAppWriter = CloneAppWriter(),
        fileManager: FileManager = .default
    ) {
        self.configuration = configuration
        self.shell = shell
        self.reader = reader
        self.planner = planner
        self.cloneWriter = cloneWriter
        self.store = CloneStore(storeURL: configuration.storeURL)
        self.fileManager = fileManager
    }

    public func listClones() throws -> [CloneRecord] {
        try store.load().sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    @discardableResult
    public func createClone(sourceURL: URL, displayName: String?) throws -> CloneRecord {
        let source = try reader.read(sourceURL)
        var records = try store.load()
        let plan = try planner.planClone(
            source: source,
            requestedName: displayName,
            existingCloneNames: records.map(\.displayName)
        )
        let destination = configuration.clonesRoot.appendingPathComponent(plan.appFileName, isDirectory: true)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw MultiOpenError.cloneAlreadyExists(destination)
        }

        try materializeClone(plan: plan, destination: destination)
        let createdAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        let record = CloneRecord(
            id: plan.id,
            displayName: plan.displayName,
            bundleIdentifier: plan.bundleIdentifier,
            sourceBundleIdentifier: source.bundleIdentifier,
            sourceVersion: source.version,
            sourcePath: source.url.path,
            clonePath: destination.path,
            createdAt: createdAt,
            lastRepairedAt: nil
        )
        records.append(record)
        try store.save(records)
        return record
    }

    @discardableResult
    public func repairClone(idOrName: String) throws -> CloneRecord {
        try repairClone(idOrName: idOrName, sourceOverride: nil)
    }

    @discardableResult
    private func repairClone(idOrName: String, sourceOverride: SourceApplication?) throws -> CloneRecord {
        var records = try store.load()
        guard let index = records.firstIndex(where: { $0.id == idOrName || $0.displayName == idOrName }) else {
            throw MultiOpenError.cloneNotFound(idOrName)
        }

        let record = records[index]
        let source = try sourceOverride ?? reader.read(URL(fileURLWithPath: record.sourcePath, isDirectory: true))
        let plan = planner.planRepair(record: record, source: source)
        let destination = URL(fileURLWithPath: record.clonePath, isDirectory: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try materializeClone(plan: plan, destination: destination, customIconPath: record.customIconPath)

        var repaired = record
        repaired.sourceBundleIdentifier = source.bundleIdentifier
        repaired.sourceVersion = source.version
        repaired.sourcePath = source.url.path
        repaired.lastRepairedAt = Date(timeIntervalSince1970: floor(Date().timeIntervalSince1970))
        records[index] = repaired
        try store.save(records)
        return repaired
    }

    @discardableResult
    public func updateClone(idOrName: String) throws -> CloneRecord {
        try repairClone(idOrName: idOrName)
    }

    @discardableResult
    public func updateOutdatedClones(
        sources: [SourceApplication],
        skipRunning: Bool = true
    ) throws -> [CloneRecord] {
        var updated: [CloneRecord] = []
        for record in try listClones() {
            guard let source = currentSource(for: record, candidates: sources),
                  isClone(record, outdatedComparedTo: source) else {
                continue
            }
            if skipRunning && isRunning(record) {
                continue
            }
            updated.append(try repairClone(idOrName: record.id, sourceOverride: source))
        }
        return updated
    }

    public func deleteClone(idOrName: String) throws {
        var records = try store.load()
        guard let index = records.firstIndex(where: { $0.id == idOrName || $0.displayName == idOrName }) else {
            throw MultiOpenError.cloneNotFound(idOrName)
        }
        let record = records.remove(at: index)
        let cloneURL = URL(fileURLWithPath: record.clonePath, isDirectory: true)
        if fileManager.fileExists(atPath: cloneURL.path) {
            try fileManager.removeItem(at: cloneURL)
        }
        try store.save(records)
    }

    public func launchClone(idOrName: String) throws {
        let record = try resolveClone(idOrName: idOrName)
        let result = try shell.run("/usr/bin/open", ["-n", record.clonePath])
        try ensureSuccess(result, executable: "/usr/bin/open", arguments: ["-n", record.clonePath])
    }

    public func launchSource(_ source: SourceApplication) throws {
        let result = try shell.run("/usr/bin/open", ["-n", source.url.path])
        try ensureSuccess(result, executable: "/usr/bin/open", arguments: ["-n", source.url.path])
    }

    public func revealClone(idOrName: String) throws {
        let record = try resolveClone(idOrName: idOrName)
        let result = try shell.run("/usr/bin/open", ["-R", record.clonePath])
        try ensureSuccess(result, executable: "/usr/bin/open", arguments: ["-R", record.clonePath])
    }

    @discardableResult
    public func setCloneIcon(idOrName: String, iconURL: URL) throws -> CloneRecord {
        guard fileManager.fileExists(atPath: iconURL.path) else {
            throw MultiOpenError.invalidIcon(iconURL)
        }
        var records = try store.load()
        guard let index = records.firstIndex(where: { $0.id == idOrName || $0.displayName == idOrName }) else {
            throw MultiOpenError.cloneNotFound(idOrName)
        }

        var record = records[index]
        let persistedIconURL = configuration.supportRoot
            .appendingPathComponent("icons", isDirectory: true)
            .appendingPathComponent("\(record.id).icns")
        try createICNS(from: iconURL, at: persistedIconURL)
        try applyCustomIcon(iconPath: persistedIconURL.path, toCloneAt: URL(fileURLWithPath: record.clonePath, isDirectory: true))
        try signClone(URL(fileURLWithPath: record.clonePath, isDirectory: true))
        try verifyClone(URL(fileURLWithPath: record.clonePath, isDirectory: true))

        record.customIconPath = persistedIconURL.path
        records[index] = record
        try store.save(records)
        return record
    }

    public func isRunning(_ record: CloneRecord) -> Bool {
        guard let result = try? shell.run("/bin/ps", ["-axo", "pid=,args="]), result.status == 0 else {
            return false
        }
        return result.output.components(separatedBy: .newlines).contains { $0.contains(record.clonePath) }
    }

    public func isSourceRunning(_ source: SourceApplication) -> Bool {
        guard let result = try? shell.run("/bin/ps", ["-axo", "pid=,args="]), result.status == 0 else {
            return false
        }
        let executablePath = source.url
            .appendingPathComponent("Contents/MacOS")
            .appendingPathComponent(source.executableName)
            .path
        return result.output.components(separatedBy: .newlines).contains { $0.contains(executablePath) }
    }

    public func isClone(_ record: CloneRecord, outdatedComparedTo source: SourceApplication) -> Bool {
        guard record.sourceBundleIdentifier == source.bundleIdentifier,
              let recordedVersion = record.sourceVersion,
              let currentVersion = source.version,
              !recordedVersion.isEmpty,
              !currentVersion.isEmpty else {
            return false
        }
        return recordedVersion != currentVersion
    }

    public func currentSource(for record: CloneRecord, candidates: [SourceApplication]) -> SourceApplication? {
        if let source = candidates.first(where: { $0.url.path == record.sourcePath }) {
            return source
        }
        if let source = candidates.first(where: { $0.bundleIdentifier == record.sourceBundleIdentifier }) {
            return source
        }
        return try? reader.read(URL(fileURLWithPath: record.sourcePath, isDirectory: true))
    }

    private func resolveClone(idOrName: String) throws -> CloneRecord {
        guard let record = try store.load().first(where: { $0.id == idOrName || $0.displayName == idOrName }) else {
            throw MultiOpenError.cloneNotFound(idOrName)
        }
        return record
    }

    private func materializeClone(plan: ClonePlan, destination: URL, customIconPath: String? = nil) throws {
        try fileManager.createDirectory(at: configuration.clonesRoot, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: configuration.supportRoot, withIntermediateDirectories: true)
        try cloneWriter.writeCloneApp(plan: plan, destination: destination)
        if let customIconPath, fileManager.fileExists(atPath: customIconPath) {
            try applyCustomIcon(iconPath: customIconPath, toCloneAt: destination)
        }
        try signClone(destination)
        try verifyClone(destination)
    }

    private func createICNS(from source: URL, at destination: URL) throws {
        let iconDirectory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        if source.pathExtension.lowercased() == "icns" {
            try fileManager.copyItem(at: source, to: destination)
            return
        }

        let iconset = iconDirectory.appendingPathComponent("\(destination.deletingPathExtension().lastPathComponent).iconset", isDirectory: true)
        if fileManager.fileExists(atPath: iconset.path) {
            try fileManager.removeItem(at: iconset)
        }
        try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)
        let sizes: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]
        do {
            for (name, pixels) in sizes {
                let output = iconset.appendingPathComponent(name)
                let arguments = ["-z", "\(pixels)", "\(pixels)", source.path, "--out", output.path]
                let result = try shell.run("/usr/bin/sips", arguments)
                try ensureSuccess(result, executable: "/usr/bin/sips", arguments: arguments)
            }
            let arguments = ["-c", "icns", iconset.path, "-o", destination.path]
            let result = try shell.run("/usr/bin/iconutil", arguments)
            try ensureSuccess(result, executable: "/usr/bin/iconutil", arguments: arguments)
        } catch {
            try? fileManager.removeItem(at: iconset)
            throw error
        }
        try? fileManager.removeItem(at: iconset)
    }

    private func applyCustomIcon(iconPath: String, toCloneAt cloneURL: URL) throws {
        guard fileManager.fileExists(atPath: cloneURL.path) else {
            throw MultiOpenError.cloneNotFound(cloneURL.path)
        }
        let resources = cloneURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)
        try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
        let destination = resources.appendingPathComponent("MacMultiOpenCloneIcon.icns")
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: iconPath), to: destination)

        let infoURL = cloneURL.appendingPathComponent("Contents/Info.plist")
        var plist = try PropertyListTools().readDictionary(from: infoURL)
        plist["CFBundleIconFile"] = "MacMultiOpenCloneIcon"
        try PropertyListTools().writeDictionary(plist, to: infoURL)
        try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: cloneURL.path)
    }

    private func signClone(_ destination: URL) throws {
        let arguments = [
            "--force",
            "--sign",
            "-",
            destination.path
        ]
        let result = try shell.run("/usr/bin/codesign", arguments)
        try ensureSuccess(result, executable: "/usr/bin/codesign", arguments: arguments)
    }

    private func verifyClone(_ destination: URL) throws {
        let arguments = ["--verify", "--strict", destination.path]
        let result = try shell.run("/usr/bin/codesign", arguments)
        try ensureSuccess(result, executable: "/usr/bin/codesign", arguments: arguments)
    }

    private func ensureSuccess(_ result: CommandResult, executable: String, arguments: [String]) throws {
        if result.status != 0 {
            throw MultiOpenError.commandFailed(
                executable: executable,
                arguments: arguments,
                status: result.status,
                output: result.output
            )
        }
    }
}
