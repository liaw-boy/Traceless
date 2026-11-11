import SwiftUI
import AppKit
import Combine
import AppSweepCore

public enum NavigationTab: String, CaseIterable, Identifiable {
    case apps = "已安裝應用"
    case dragDrop = "拖曳清理"
    case leftovers = "孤立殘留清理"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .apps: return "app.badge.checkmark"
        case .dragDrop: return "arrow.down.doc"
        case .leftovers: return "sparkles"
        }
    }
}

public enum AppFilterMode: String, CaseIterable, Identifiable {
    case all = "全部"
    case user = "第三方"
    case unused = "長期未開"
    case system = "系統"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .user: return "person.crop.circle"
        case .unused: return "moon.zzz"
        case .system: return "apple.logo"
        }
    }
}

public enum AppSortOption: String, CaseIterable, Identifiable {
    case sizeDesc = "容量 (大到小)"
    case sizeAsc = "容量 (小到大)"
    case lastUsed = "上次開啟時間"
    case installDate = "安裝修改時間"
    case name = "名稱 (A-Z)"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .sizeDesc: return "arrow.down.circle"
        case .sizeAsc: return "arrow.up.circle"
        case .lastUsed: return "clock"
        case .installDate: return "calendar"
        case .name: return "textformat"
        }
    }
}

@MainActor
public final class AppState: ObservableObject {
    // Navigation
    @Published public var activeTab: NavigationTab = .apps

    // Installed Apps
    @Published public var installedApps: [AppInfo] = []
    @Published public var isLoadingApps: Bool = false
    @Published public var selectedApp: AppInfo?

    // Residual Inspection
    @Published public var residualItems: [ResidualItem] = []
    @Published public var isLoadingResiduals: Bool = false

    // Leftovers
    @Published public var leftoverGroups: [LeftoverAppGroup] = []
    @Published public var isLoadingLeftovers: Bool = false
    @Published public var leftoverSearchText: String = ""
    @Published public var leftoverFilterMode: LeftoverFilterMode = .all
    @Published public var leftoverSortOption: LeftoverSortOption = .sizeDesc

    // Search & Filter (Apps)
    @Published public var searchText: String = ""
    @Published public var filterMode: AppFilterMode = .user
    @Published public var sortOption: AppSortOption = .sizeDesc

    // Modals & Feedback
    @Published public var showConfirmSheet: Bool = false
    @Published public var showResetConfirmSheet: Bool = false
    @Published public var showPermissionSheet: Bool = false
    @Published public var hasFullDiskAccess: Bool = false
    @Published public var isUninstalling: Bool = false
    @Published public var lastResult: UninstallResult?
    @Published public var showToast: Bool = false
    @Published public var toastMessage: String = ""
    @Published public var quitAppBeforeTrash: Bool = true

    // Services
    private let appScanner = AppScanner()
    private let residualScanner = ResidualScanner()
    private let leftoverScanner = LeftoverScanner()
    private let uninstaller = Uninstaller()

    public init() {}

    // MARK: - Computed Properties

    public var filteredApps: [AppInfo] {
        var list = installedApps

        // Filter
        switch filterMode {
        case .all:
            break
        case .user:
            list = list.filter { !$0.isSystemApp }
        case .unused:
            list = list.filter { !$0.isSystemApp && $0.isUnusedOver3Months }
        case .system:
            list = list.filter { $0.isSystemApp }
        }

        // Search
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.bundleIdentifier.lowercased().contains(q)
            }
        }

        // Sort
        switch sortOption {
        case .sizeDesc:
            list.sort { $0.size > $1.size }
        case .sizeAsc:
            list.sort { $0.size < $1.size }
        case .lastUsed:
            list.sort { ($0.lastUsedDate ?? .distantPast) > ($1.lastUsedDate ?? .distantPast) }
        case .installDate:
            list.sort { ($0.installDate ?? $0.lastModified ?? .distantPast) > ($1.installDate ?? $1.lastModified ?? .distantPast) }
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }

        return list
    }

    public var selectedResiduals: [ResidualItem] {
        residualItems.filter { $0.isSelected && !$0.isProtected }
    }

    public var totalSelectedSize: Int64 {
        selectedResiduals.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSelectedSize: String {
        FileSizeFormatter.format(totalSelectedSize)
    }

    public var filteredLeftoverGroups: [LeftoverAppGroup] {
        var list = leftoverGroups

        // Filter Mode
        switch leftoverFilterMode {
        case .all:
            break
        case .large:
            list = list.filter { $0.totalSize >= 50 * 1024 * 1024 }
        case .containers:
            list = list.filter { $0.hasContainers }
        case .caches:
            list = list.filter { $0.hasCaches }
        case .preferences:
            list = list.filter { $0.hasPreferences }
        }

        // Search
        let q = leftoverSearchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            list = list.filter {
                $0.name.lowercased().contains(q) ||
                $0.id.lowercased().contains(q) ||
                $0.items.contains { $0.name.lowercased().contains(q) || $0.path.lowercased().contains(q) }
            }
        }

        // Sort
        switch leftoverSortOption {
        case .sizeDesc:
            list.sort { $0.totalSize > $1.totalSize }
        case .sizeAsc:
            list.sort { $0.totalSize < $1.totalSize }
        case .name:
            list.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .itemCount:
            list.sort { $0.items.count > $1.items.count }
        }

        return list
    }

    public var totalLeftoverSize: Int64 {
        filteredLeftoverGroups.reduce(0) { $0 + $1.totalSize }
    }

    public var formattedTotalLeftoverSize: String {
        FileSizeFormatter.format(totalLeftoverSize)
    }

    public var totalSelectedLeftoverCount: Int {
        filteredLeftoverGroups.flatMap { $0.items }.filter { $0.isSelected }.count
    }

    public var totalSelectedLeftoverSize: Int64 {
        filteredLeftoverGroups.flatMap { $0.items }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    public var formattedTotalSelectedLeftoverSize: String {
        FileSizeFormatter.format(totalSelectedLeftoverSize)
    }

    // MARK: - Actions

    public func loadApps() async {
        isLoadingApps = true
        self.hasFullDiskAccess = PermissionManager.hasFullDiskAccess
        let apps = await appScanner.scanInstalledApplications()
        self.installedApps = apps
        self.isLoadingApps = false

        if selectedApp == nil, let first = filteredApps.first {
            await selectApp(first)
        }
    }

    public func selectApp(_ app: AppInfo) async {
        self.selectedApp = app
        self.isLoadingResiduals = true
        let items = await residualScanner.scanResiduals(for: app)
        self.residualItems = items
        self.isLoadingResiduals = false
    }

    public func toggleItemSelection(id: UUID) {
        if let idx = residualItems.firstIndex(where: { $0.id == id }) {
            if !residualItems[idx].isProtected {
                residualItems[idx].isSelected.toggle()
            }
        }
    }

    public func toggleCategorySelection(category: ResidualCategory) {
        let items = residualItems.filter { $0.category == category && !$0.isProtected }
        guard !items.isEmpty else { return }
        let allSelected = items.allSatisfy { $0.isSelected }
        let target = !allSelected
        for idx in residualItems.indices {
            if residualItems[idx].category == category && !residualItems[idx].isProtected {
                residualItems[idx].isSelected = target
            }
        }
    }

    public func setAllSelected(_ select: Bool) {
        for idx in residualItems.indices {
            if !residualItems[idx].isProtected {
                residualItems[idx].isSelected = select
            }
        }
    }

    public func loadAppFromURL(_ url: URL) async {
        if let app = await appScanner.parseApp(at: url) {
            if !installedApps.contains(where: { $0.url == app.url }) {
                installedApps.insert(app, at: 0)
            }
            self.selectedApp = app
            self.activeTab = .apps
            await selectApp(app)
        } else {
            notify("無法辨識此應用程式套件")
        }
    }

    public func scanLeftovers() async {
        isLoadingLeftovers = true
        let groups = await leftoverScanner.scanLeftovers(installedApps: self.installedApps)
        self.leftoverGroups = groups
        self.isLoadingLeftovers = false
    }

    public func toggleLeftoverItem(groupId: String, itemId: UUID) {
        guard let gIdx = leftoverGroups.firstIndex(where: { $0.id == groupId }) else { return }
        if let iIdx = leftoverGroups[gIdx].items.firstIndex(where: { $0.id == itemId }) {
            leftoverGroups[gIdx].items[iIdx].isSelected.toggle()
        }
    }

    public func toggleLeftoverGroupSelection(groupId: String, select: Bool) {
        guard let gIdx = leftoverGroups.firstIndex(where: { $0.id == groupId }) else { return }
        for i in leftoverGroups[gIdx].items.indices {
            leftoverGroups[gIdx].items[i].isSelected = select
        }
    }

    public func selectAllLeftovers(_ select: Bool) {
        let visibleIds = Set(filteredLeftoverGroups.map { $0.id })
        for gIdx in leftoverGroups.indices {
            if visibleIds.contains(leftoverGroups[gIdx].id) {
                for i in leftoverGroups[gIdx].items.indices {
                    leftoverGroups[gIdx].items[i].isSelected = select
                }
            }
        }
    }

    public func executeUninstall() async {
        guard let app = selectedApp else { return }
        isUninstalling = true
        showConfirmSheet = false

        let itemsToTrash = selectedResiduals
        let result = await uninstaller.uninstall(
            items: itemsToTrash,
            appBundleIdentifier: app.bundleIdentifier,
            quitIfRunning: quitAppBeforeTrash
        )

        self.lastResult = result
        self.isUninstalling = false

        if result.hasPermissionError {
            self.showPermissionSheet = true
            notify("⚠️ 部分沙盒容器因系統權限保護無法移動，請授權完全磁碟取用。")
            if result.trashedCount > 0 {
                self.installedApps.removeAll { $0.url == app.url }
                self.selectedApp = filteredApps.first
                if let next = selectedApp {
                    await selectApp(next)
                }
            }
        } else if result.isSuccess || result.trashedCount > 0 {
            notify("成功移至垃圾桶！釋放了 \(result.formattedFreedBytes)")
            self.installedApps.removeAll { $0.url == app.url }
            self.selectedApp = filteredApps.first
            if let next = selectedApp {
                await selectApp(next)
            } else {
                self.residualItems = []
            }
        } else {
            notify("移除失敗或未選擇任何項目")
        }
    }

    /// Resets the application (removes caches & preferences, but keeps .app bundle)
    public func executeResetApp() async {
        guard let app = selectedApp else { return }
        showResetConfirmSheet = false
        isUninstalling = true

        let nonBundleItems = residualItems.filter { $0.category != .appBundle && !$0.isProtected }
        guard !nonBundleItems.isEmpty else {
            notify("此應用程式無可重置的快取或偏好設定")
            isUninstalling = false
            return
        }

        let result = await uninstaller.uninstall(
            items: nonBundleItems,
            appBundleIdentifier: app.bundleIdentifier,
            quitIfRunning: true
        )

        self.isUninstalling = false
        if result.trashedCount > 0 {
            notify("成功重置 \(app.name)！已清除 \(result.formattedFreedBytes) 快取設定")
            await selectApp(app)
        } else {
            notify("重置失敗")
        }
    }

    public func executeLeftoverGroupUninstall(group: LeftoverAppGroup) async {
        let items = group.items.filter { $0.isSelected }
        guard !items.isEmpty else {
            notify("請先勾選欲清理的殘留項目")
            return
        }

        let result = await uninstaller.uninstall(items: items, quitIfRunning: false)
        self.lastResult = result
        if result.hasPermissionError {
            self.showPermissionSheet = true
            notify("⚠️ 清理 \(group.name) 失敗：沙盒容器需要「完全取用磁碟」權限。")
            if result.trashedCount > 0 {
                await scanLeftovers()
            }
        } else if result.trashedCount > 0 {
            notify("成功清除 \(group.name) 殘留檔案！釋放了 \(result.formattedFreedBytes)")
            await scanLeftovers()
        } else {
            notify("殘留清理失敗")
        }
    }

    public func executeAllSelectedLeftoversUninstall() async {
        let allSelected = leftoverGroups.flatMap { $0.items }.filter { $0.isSelected }
        guard !allSelected.isEmpty else {
            notify("請先勾選欲清理的殘留項目")
            return
        }

        let result = await uninstaller.uninstall(items: allSelected, quitIfRunning: false)
        self.lastResult = result
        if result.hasPermissionError {
            self.showPermissionSheet = true
            notify("⚠️ 清理部分項目失敗：沙盒容器需要「完全取用磁碟」權限。")
            if result.trashedCount > 0 {
                await scanLeftovers()
            }
        } else if result.trashedCount > 0 {
            notify("成功清除 \(result.trashedCount) 個孤立殘留檔案！釋放了 \(result.formattedFreedBytes)")
            await scanLeftovers()
        } else {
            notify("殘留清理失敗")
        }
    }

    public func revealInFinder(url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func openTrash() {
        if let trashURL = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first {
            NSWorkspace.shared.open(trashURL)
        }
    }

    private func notify(_ msg: String) {
        self.toastMessage = msg
        self.showToast = true
        Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if self.toastMessage == msg {
                self.showToast = false
            }
        }
    }
}
