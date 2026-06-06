import Foundation

public enum MultiOpenError: Error, CustomStringConvertible, LocalizedError {
    case invalidApplication(URL)
    case missingInfoPlist(URL)
    case missingBundleIdentifier(URL)
    case missingExecutableName(URL)
    case invalidCloneName(String)
    case cloneNameAlreadyExists(String)
    case cloneAlreadyExists(URL)
    case cloneNotFound(String)
    case invalidIcon(URL)
    case commandFailed(executable: String, arguments: [String], status: Int32, output: String)
    case entitlementsNotFound(URL)

    public var description: String {
        switch self {
        case .invalidApplication(let url):
            return "不是有效的 macOS App：\(url.path)"
        case .missingInfoPlist(let url):
            return "缺少 Info.plist：\(url.path)"
        case .missingBundleIdentifier(let url):
            return "缺少 CFBundleIdentifier：\(url.path)"
        case .missingExecutableName(let url):
            return "缺少 CFBundleExecutable：\(url.path)"
        case .invalidCloneName(let name):
            return "分身名称无效：\(name)"
        case .cloneNameAlreadyExists(let name):
            return "分身名称已存在：\(name)"
        case .cloneAlreadyExists(let url):
            return "分身 App 已存在：\(url.path)"
        case .cloneNotFound(let id):
            return "找不到分身：\(id)"
        case .invalidIcon(let url):
            return "图标文件无效：\(url.path)"
        case .commandFailed(let executable, let arguments, let status, let output):
            return "命令失败：\(executable) \(arguments.joined(separator: " "))，退出码 \(status)：\(output)"
        case .entitlementsNotFound(let url):
            return "无法读取签名权限：\(url.path)"
        }
    }

    public var errorDescription: String? { description }
}
