import Foundation

public struct CommandResult: Equatable {
    public let status: Int32
    public let stdout: String
    public let stderr: String

    public init(status: Int32, stdout: String, stderr: String) {
        self.status = status
        self.stdout = stdout
        self.stderr = stderr
    }

    public var output: String {
        [stdout, stderr]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

public protocol ShellRunning: AnyObject {
    func run(_ executable: String, _ arguments: [String]) throws -> CommandResult
}

public final class SystemShellRunner: ShellRunning {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacMultiOpen-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let stdoutURL = tempRoot.appendingPathComponent("stdout.txt")
        let stderrURL = tempRoot.appendingPathComponent("stderr.txt")
        FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
        FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)
        process.standardOutput = stdoutHandle
        process.standardError = stderrHandle

        try process.run()
        process.waitUntilExit()
        try? stdoutHandle.close()
        try? stderrHandle.close()

        let stdout = String(data: try Data(contentsOf: stdoutURL), encoding: .utf8) ?? ""
        let stderr = String(data: try Data(contentsOf: stderrURL), encoding: .utf8) ?? ""

        return CommandResult(status: process.terminationStatus, stdout: stdout, stderr: stderr)
    }
}
