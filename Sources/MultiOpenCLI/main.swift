import Foundation
import MultiOpenKit

let service = CloneService()
let locator = AppLocator()
let arguments = Array(CommandLine.arguments.dropFirst())

func usage() {
    print("""
    微信多开工具 CLI

    用法:
      multiopen scan
      multiopen list
      multiopen create --source /Applications/WeChat.app [--name 工作微信]
      multiopen launch <id或名称>
      multiopen update <id或名称>
      multiopen update-all
      multiopen set-icon <id或名称> --icon /path/to/icon.png
      multiopen repair <id或名称>
      multiopen delete <id或名称>
      multiopen reveal <id或名称>
      multiopen doctor
    """)
}

func value(after flag: String, in args: [String]) -> String? {
    guard let index = args.firstIndex(of: flag), args.indices.contains(index + 1) else {
        return nil
    }
    return args[index + 1]
}

func printRecord(_ record: CloneRecord) {
    print("\(record.displayName)")
    print("  id: \(record.id)")
    print("  bundle: \(record.bundleIdentifier)")
    print("  source: \(record.sourcePath)")
    if let sourceVersion = record.sourceVersion {
        print("  source-version: \(sourceVersion)")
    }
    print("  app: \(record.clonePath)")
    if let customIconPath = record.customIconPath {
        print("  icon: \(customIconPath)")
    }
}

do {
    guard let command = arguments.first else {
        usage()
        exit(0)
    }

    switch command {
    case "scan":
        let sources = locator.locateSupportedApplications()
        if sources.isEmpty {
            print("未发现微信或企业微信。")
        } else {
            for source in sources {
                print("\(source.displayName) \(source.version ?? "")")
                print("  bundle: \(source.bundleIdentifier)")
                print("  app: \(source.url.path)")
            }
        }

    case "list":
        let records = try service.listClones()
        if records.isEmpty {
            print("还没有分身。")
        } else {
            for record in records {
                printRecord(record)
                print("  status: \(service.isRunning(record) ? "运行中" : "未运行")")
            }
        }

    case "create":
        guard let source = value(after: "--source", in: arguments) else {
            throw MultiOpenError.invalidApplication(URL(fileURLWithPath: "--source 未提供"))
        }
        let name = value(after: "--name", in: arguments)
        let record = try service.createClone(sourceURL: URL(fileURLWithPath: source, isDirectory: true), displayName: name)
        print("已创建分身：")
        printRecord(record)

    case "launch":
        guard arguments.count >= 2 else {
            throw MultiOpenError.cloneNotFound("")
        }
        try service.launchClone(idOrName: arguments.dropFirst().joined(separator: " "))
        print("已启动。")

    case "repair":
        guard arguments.count >= 2 else {
            throw MultiOpenError.cloneNotFound("")
        }
        let record = try service.repairClone(idOrName: arguments.dropFirst().joined(separator: " "))
        print("已修复分身：\(record.displayName)")

    case "update":
        guard arguments.count >= 2 else {
            throw MultiOpenError.cloneNotFound("")
        }
        let record = try service.updateClone(idOrName: arguments.dropFirst().joined(separator: " "))
        print("已更新分身：\(record.displayName)")

    case "update-all":
        let updated = try service.updateOutdatedClones(sources: locator.locateSupportedApplications(), skipRunning: true)
        if updated.isEmpty {
            print("没有需要更新的分身。")
        } else {
            print("已更新分身：\(updated.map(\.displayName).joined(separator: "、"))")
        }

    case "set-icon":
        guard let icon = value(after: "--icon", in: arguments) else {
            throw MultiOpenError.invalidIcon(URL(fileURLWithPath: "--icon 未提供"))
        }
        let nameParts = arguments.dropFirst().filter { $0 != "--icon" && $0 != icon }
        guard !nameParts.isEmpty else {
            throw MultiOpenError.cloneNotFound("")
        }
        let record = try service.setCloneIcon(
            idOrName: nameParts.joined(separator: " "),
            iconURL: URL(fileURLWithPath: icon)
        )
        print("已修改图标：\(record.displayName)")

    case "delete":
        guard arguments.count >= 2 else {
            throw MultiOpenError.cloneNotFound("")
        }
        try service.deleteClone(idOrName: arguments.dropFirst().joined(separator: " "))
        print("已删除。")

    case "reveal":
        guard arguments.count >= 2 else {
            throw MultiOpenError.cloneNotFound("")
        }
        try service.revealClone(idOrName: arguments.dropFirst().joined(separator: " "))
        print("已在 Finder 中显示。")

    case "doctor":
        print("配置目录：\(CloneService.Configuration.default.supportRoot.path)")
        print("分身目录：\(CloneService.Configuration.default.clonesRoot.path)")
        print("已发现源应用：\(locator.locateSupportedApplications().count)")
        print("已创建分身：\(try service.listClones().count)")

    default:
        usage()
        exit(1)
    }
} catch {
    fputs("错误：\(error)\n", stderr)
    exit(1)
}
