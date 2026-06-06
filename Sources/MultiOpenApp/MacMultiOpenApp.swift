import SwiftUI
import AppKit
import MultiOpenKit
import UniformTypeIdentifiers

@main
struct MacMultiOpenApp: App {
    var body: some Scene {
        WindowGroup("微信多开工具") {
            ContentView()
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.titleBar)
    }
}

enum AppListItem: Identifiable {
    case source(SourceApplication)
    case clone(CloneRecord)

    var id: String {
        switch self {
        case .source(let source):
            return "source-\(source.bundleIdentifier)"
        case .clone(let clone):
            return "clone-\(clone.id)"
        }
    }

    var title: String {
        switch self {
        case .source(let source):
            return source.displayName
        case .clone(let clone):
            return clone.displayName
        }
    }

    var subtitle: String {
        switch self {
        case .source:
            return "系统应用"
        case .clone:
            return "分身应用"
        }
    }

    var sourceBundleIdentifier: String {
        switch self {
        case .source(let source):
            return source.bundleIdentifier
        case .clone(let clone):
            return clone.sourceBundleIdentifier
        }
    }

    var canDelete: Bool {
        if case .clone = self { return true }
        return false
    }

    var customIconPath: String? {
        if case .clone(let clone) = self {
            return clone.customIconPath
        }
        return nil
    }
}

struct AppGroup: Identifiable {
    let id: String
    let title: String
    let items: [AppListItem]
}

@MainActor
final class MultiOpenViewModel: ObservableObject {
    @Published var sources: [SourceApplication] = []
    @Published var clones: [CloneRecord] = []
    @Published var selectedItemID: String?
    @Published var cloneName: String = ""
    @Published var message: String = "就绪"
    @Published var isBusy = false
    @Published var runningItemIDs: Set<String> = []
    @Published var outdatedCloneIDs: Set<String> = []
    @Published var autoUpdateEnabled = true

    private let service = CloneService()
    private let locator = AppLocator()

    var groups: [AppGroup] {
        let allSourceIDs = Set(sources.map(\.bundleIdentifier))
        var result: [AppGroup] = []

        for source in sources {
            let items = [AppListItem.source(source)] + clones
                .filter { $0.sourceBundleIdentifier == source.bundleIdentifier }
                .map(AppListItem.clone)
            result.append(AppGroup(
                id: source.bundleIdentifier,
                title: groupTitle(for: source),
                items: items
            ))
        }

        let orphanClones = clones
            .filter { !allSourceIDs.contains($0.sourceBundleIdentifier) }
            .map(AppListItem.clone)
        if !orphanClones.isEmpty {
            result.append(AppGroup(id: "other", title: "其他", items: orphanClones))
        }

        return result
    }

    var createdCount: Int { clones.count }
    var selectedItem: AppListItem? {
        groups.flatMap(\.items).first { $0.id == selectedItemID }
    }
    var selectedSource: SourceApplication? {
        if case .source(let source) = selectedItem {
            return source
        }
        if let clone = selectedClone {
            return sources.first { $0.bundleIdentifier == clone.sourceBundleIdentifier }
        }
        return sources.first
    }
    var selectedClone: CloneRecord? {
        if case .clone(let clone) = selectedItem {
            return clone
        }
        return nil
    }

    func load(autoUpdate: Bool = true) {
        sources = locator.locateSupportedApplications()
        do {
            var loadedClones = try service.listClones()
            if autoUpdate && autoUpdateEnabled {
                let updated = try service.updateOutdatedClones(sources: sources, skipRunning: true)
                if !updated.isEmpty {
                    message = "已自动更新：\(updated.map(\.displayName).joined(separator: "、"))"
                    loadedClones = try service.listClones()
                }
            }
            clones = loadedClones
            let validIDs = Set(groups.flatMap(\.items).map(\.id))
            if selectedItemID == nil || !validIDs.contains(selectedItemID ?? "") {
                selectedItemID = groups.first?.items.first?.id
            }
            refreshVersionStatus()
            refreshRunningStatus()
        } catch {
            message = "读取分身失败：\(error)"
        }
    }

    func createClone() {
        guard let source = selectedSource ?? sources.first else {
            message = "未发现可创建分身的微信。"
            return
        }
        runBusy("正在创建分身...") {
            let name = self.cloneName.trimmingCharacters(in: .whitespacesAndNewlines)
            let record = try self.service.createClone(
                sourceURL: source.url,
                displayName: name.isEmpty ? nil : name
            )
            self.cloneName = ""
            self.load(autoUpdate: false)
            self.selectedItemID = AppListItem.clone(record).id
            self.message = "已创建：\(record.displayName)"
        }
    }

    func launchSelectedItem() {
        guard let item = selectedItem else {
            message = "请选择要启动的应用。"
            return
        }
        launch(item)
    }

    func launch(_ item: AppListItem) {
        runBusy("正在启动...") {
            switch item {
            case .source(let source):
                try self.service.launchSource(source)
                self.message = "已启动：\(source.displayName)"
            case .clone(let clone):
                try self.service.launchClone(idOrName: clone.id)
                self.message = "已启动：\(clone.displayName)"
            }
            self.load(autoUpdate: false)
        }
    }

    func repairSelectedClone() {
        guard let clone = selectedClone else { return }
        runBusy("正在修复...") {
            let record = try self.service.repairClone(idOrName: clone.id)
            self.load(autoUpdate: false)
            self.selectedItemID = AppListItem.clone(record).id
            self.message = "已修复：\(record.displayName)"
        }
    }

    func updateSelectedClone() {
        guard let clone = selectedClone else { return }
        if service.isRunning(clone) {
            message = "请先退出 \(clone.displayName)，再更新分身。"
            return
        }
        runBusy("正在更新分身...") {
            let record = try self.service.updateClone(idOrName: clone.id)
            self.load(autoUpdate: false)
            self.selectedItemID = AppListItem.clone(record).id
            self.message = "已更新：\(record.displayName)"
        }
    }

    func chooseIconForSelectedClone() {
        guard let clone = selectedClone else { return }
        let panel = NSOpenPanel()
        panel.title = "选择分身图标"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        var contentTypes: [UTType] = [.png, .jpeg, .tiff, .heic]
        if let icns = UTType(filenameExtension: "icns") {
            contentTypes.append(icns)
        }
        panel.allowedContentTypes = contentTypes
        guard panel.runModal() == .OK, let iconURL = panel.url else {
            return
        }
        runBusy("正在修改图标...") {
            let record = try self.service.setCloneIcon(idOrName: clone.id, iconURL: iconURL)
            self.load(autoUpdate: false)
            self.selectedItemID = AppListItem.clone(record).id
            self.message = "已修改图标：\(record.displayName)"
        }
    }

    func deleteSelectedClone() {
        guard let clone = selectedClone else { return }
        runBusy("正在删除...") {
            try self.service.deleteClone(idOrName: clone.id)
            self.load(autoUpdate: false)
            self.message = "已删除：\(clone.displayName)"
        }
    }

    func revealSelectedClone() {
        guard let clone = selectedClone else { return }
        runBusy("正在打开 Finder...") {
            try self.service.revealClone(idOrName: clone.id)
            self.message = "已显示：\(clone.displayName)"
        }
    }

    func isRunning(_ item: AppListItem) -> Bool {
        runningItemIDs.contains(item.id)
    }

    func needsUpdate(_ item: AppListItem) -> Bool {
        if case .clone(let clone) = item {
            return outdatedCloneIDs.contains(clone.id)
        }
        return false
    }

    private func groupTitle(for source: SourceApplication) -> String {
        let lower = source.bundleIdentifier.lowercased()
        if lower.contains("wework") || source.displayName.contains("企业") {
            return "企业微信"
        }
        return "WECHAT"
    }

    private func runBusy(_ pendingMessage: String, operation: () throws -> Void) {
        guard !isBusy else { return }
        isBusy = true
        message = pendingMessage
        do {
            try operation()
        } catch {
            message = "失败：\(error)"
        }
        isBusy = false
    }

    private func refreshRunningStatus() {
        let currentSources = sources
        let currentClones = clones
        DispatchQueue.global(qos: .utility).async {
            let statusService = CloneService()
            var runningIDs = Set<String>()
            for source in currentSources where statusService.isSourceRunning(source) {
                runningIDs.insert(AppListItem.source(source).id)
            }
            for clone in currentClones where statusService.isRunning(clone) {
                runningIDs.insert(AppListItem.clone(clone).id)
            }
            DispatchQueue.main.async {
                self.runningItemIDs = runningIDs
            }
        }
    }

    private func refreshVersionStatus() {
        var ids = Set<String>()
        for clone in clones {
            guard let source = service.currentSource(for: clone, candidates: sources),
                  service.isClone(clone, outdatedComparedTo: source) else {
                continue
            }
            ids.insert(clone.id)
        }
        outdatedCloneIDs = ids
    }
}

struct ContentView: View {
    @StateObject private var model = MultiOpenViewModel()

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                appListPane
                Divider()
                infoPane
            }
            statusBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            model.load()
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label("微信多开工具", systemImage: "macwindow")
                .font(.system(size: 15, weight: .bold))
            Text("已创建/修复分身")
                .foregroundStyle(.secondary)
            Text("\(model.createdCount)")
                .foregroundStyle(.red)
                .fontWeight(.bold)
            Text("个")
            Spacer()
            Label("系统微信可直接启动", systemImage: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            Toggle("自动更新分身", isOn: $model.autoUpdateEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 13, weight: .medium))
                .onChange(of: model.autoUpdateEnabled) { isEnabled in
                    if isEnabled {
                        model.load(autoUpdate: true)
                    }
                }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 18)
        .frame(height: 52)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var appListPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(model.groups) { group in
                        groupHeader(group)
                        ForEach(group.items) { item in
                            AppRow(
                                item: item,
                                isSelected: model.selectedItemID == item.id,
                                isRunning: model.isRunning(item),
                                needsUpdate: model.needsUpdate(item),
                                isBusy: model.isBusy,
                                launch: { model.launch(item) },
                                update: { model.updateSelectedClone() },
                                changeIcon: { model.chooseIconForSelectedClone() },
                                delete: { model.deleteSelectedClone() },
                                select: { model.selectedItemID = item.id }
                            )
                        }
                    }
                }
                .padding(.vertical, 18)
            }

            createPanel
        }
        .frame(minWidth: 600)
        .background(Color.white)
    }

    private func groupHeader(_ group: AppGroup) -> some View {
        HStack {
            Text(group.title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(1.2)
            Text("\(group.items.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Button {
                if let source = group.items.compactMap({ item -> SourceApplication? in
                    if case .source(let source) = item { return source }
                    return nil
                }).first {
                    model.selectedItemID = AppListItem.source(source).id
                    model.createClone()
                }
            } label: {
                Label("新建", systemImage: "plus")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.red)
            .disabled(model.isBusy)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var createPanel: some View {
        HStack(spacing: 10) {
            TextField("新分身名称", text: $model.cloneName)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(Color.black.opacity(0.045))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                model.createClone()
            } label: {
                Label("新建分身", systemImage: "plus")
            }
            .buttonStyle(PrimaryRedButtonStyle())
            .disabled(model.sources.isEmpty || model.isBusy)
        }
        .padding(14)
        .background(Color.white)
    }

    private var infoPane: some View {
        VStack(spacing: 0) {
            ScrollView {
                guideContent
            }
            .padding(18)
        }
        .frame(width: 330)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.72))
    }

    private var guideContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("使用说明", systemImage: "book.closed.fill")
                .font(.system(size: 16, weight: .bold))

            Text("左侧第一项是系统默认安装的微信，选中后点击启动。")
            Text("输入名称并点击新建分身，会生成一个独立微信。")
            Text("选中分身后可启动、更新、修改图标或删除。")
            Text("开启自动更新后，源微信版本变化时会自动更新未运行的分身。")
            Text("如果分身正在运行，请退出后点击更新按钮手动更新。")
            Text("删除分身不会影响系统微信。")
            Text("分身目录位于 ~/Applications/MacMultiOpen。")
        }
        .font(.system(size: 14))
        .lineSpacing(5)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
            }
            Text(model.message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct AppRow: View {
    let item: AppListItem
    let isSelected: Bool
    let isRunning: Bool
    let needsUpdate: Bool
    let isBusy: Bool
    let launch: () -> Void
    let update: () -> Void
    let changeIcon: () -> Void
    let delete: () -> Void
    let select: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(item: item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(statusColor)
            }
            Spacer()
            if isSelected {
                Button("启动", action: launch)
                    .buttonStyle(SelectedRowButtonStyle())
                    .disabled(isBusy)
                if item.canDelete {
                    Button(action: changeIcon) {
                        Image(systemName: "photo")
                    }
                    .buttonStyle(SelectedIconButtonStyle())
                    .help("修改图标")
                    .disabled(isBusy)
                    Button(action: update) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(SelectedIconButtonStyle(isHighlighted: needsUpdate))
                    .help(needsUpdate ? "更新分身到当前微信版本" : "手动更新分身")
                    .disabled(isBusy)
                    Button(action: delete) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(TrashButtonStyle())
                    .disabled(isBusy)
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 64)
        .background(isSelected ? Color(red: 0.89, green: 0.18, blue: 0.23) : Color.white)
        .contentShape(Rectangle())
        .onTapGesture {
            select()
            if !isSelected {
                return
            }
            launch()
        }
        .contextMenu {
            Button("启动", action: launch)
            if item.canDelete {
                Button("修改图标", action: changeIcon)
                Button(needsUpdate ? "更新分身" : "手动更新分身", action: update)
                Button("删除", role: .destructive, action: delete)
            }
        }
    }

    private var statusText: String {
        if isRunning {
            return "运行中"
        }
        if needsUpdate {
            return "有新版本"
        }
        return "点击启动"
    }

    private var statusColor: Color {
        if isRunning {
            return isSelected ? Color.white.opacity(0.85) : Color.green
        }
        if needsUpdate {
            return isSelected ? Color.white.opacity(0.85) : Color.orange
        }
        return isSelected ? Color.white.opacity(0.65) : Color.secondary
    }
}

struct AppIconView: View {
    let item: AppListItem

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            iconContent
            if case .clone = item {
                Text("2")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 14, height: 14)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
                    .offset(x: 4, y: 4)
            }
        }
    }

    @ViewBuilder
    private var iconContent: some View {
        if let customIcon {
            Image(nsImage: customIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconBackground)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: item.sourceBundleIdentifier.lowercased().contains("wework") ? "bubble.left.and.bubble.right.fill" : "message.fill")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                )
        }
    }

    private var customIcon: NSImage? {
        guard let path = item.customIconPath else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private var iconBackground: Color {
        item.sourceBundleIdentifier.lowercased().contains("wework")
            ? Color(red: 0.16, green: 0.62, blue: 0.95)
            : Color(red: 0.05, green: 0.78, blue: 0.34)
    }
}

struct PrimaryRedButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(Color(red: 0.88, green: 0.14, blue: 0.19).opacity(configuration.isPressed ? 0.75 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SelectedRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Color(red: 0.86, green: 0.08, blue: 0.14))
            .padding(.horizontal, 14)
            .frame(height: 30)
            .background(Color.white.opacity(configuration.isPressed ? 0.8 : 0.96))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SelectedIconButtonStyle: ButtonStyle {
    var isHighlighted = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(backgroundColor.opacity(configuration.isPressed ? 0.26 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var backgroundColor: Color {
        isHighlighted ? Color.orange.opacity(0.9) : Color.white.opacity(0.18)
    }
}

struct TrashButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color.white.opacity(configuration.isPressed ? 0.14 : 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
