import SwiftUI
import AppKit
import TracelessCore

public struct AppDetailView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        if let app = state.selectedApp {
            VStack(spacing: 0) {
                header(app)
                Divider()
                content(app)
                Divider()
                footer(app)
            }
            .confirmationDialog(
                "要將 \(state.selectedResiduals.count) 個項目移至垃圾桶嗎？",
                isPresented: $state.showConfirmSheet,
                titleVisibility: .visible
            ) {
                Button("移至垃圾桶", role: .destructive) {
                    Task { await state.executeUninstall() }
                }
            } message: {
                Text(confirmMessage(app))
            }
            .confirmationDialog(
                "要重置「\(app.name)」嗎？",
                isPresented: $state.showResetConfirmSheet,
                titleVisibility: .visible
            ) {
                Button("重置", role: .destructive) {
                    Task { await state.executeResetApp() }
                }
            } message: {
                Text("會保留應用程式本身，並把它的偏好設定、快取、容器與登入狀態移至垃圾桶。下次開啟時就像剛安裝一樣。")
            }
        } else {
            ContentUnavailableView("選擇一個應用程式", systemImage: "app.dashed", description: Text("左側選取後，這裡會列出它在磁碟上的所有相關檔案。"))
        }
    }

    private func confirmMessage(_ app: AppInfo) -> String {
        var lines = ["將釋放 \(state.formattedTotalSelectedSize)。檔案會先放進垃圾桶，清空前都能復原。"]
        if app.isRunning && state.quitAppBeforeTrash {
            lines.append("「\(app.name)」正在執行，會先結束它。")
        }
        if state.selectedResiduals.contains(where: { !$0.url.path.hasPrefix(PathUtils.homeDirectory.path + "/") && $0.category != .appBundle }) {
            lines.append("部分項目位於系統資料夾，可能需要輸入管理者密碼。")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Header

    private func header(_ app: AppInfo) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(nsImage: app.icon())
                .resizable()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    if app.isSystemApp {
                        StatusBadge(text: "系統", icon: "lock.fill")
                    }
                    if app.isRunning {
                        StatusBadge(text: "執行中", color: .green)
                    }
                }
                Text([app.version.isEmpty ? nil : "版本 \(app.version)", app.architecture, app.lastUsedDescription]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(app.bundleIdentifier.isEmpty ? PathUtils.abbreviatingWithTilde(url: app.url) : app.bundleIdentifier)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    state.revealInFinder(url: app.url)
                } label: {
                    Image(systemName: "folder")
                }
                .help("在 Finder 中顯示")

                if !app.isSystemApp {
                    Button("重置…") { state.showResetConfirmSheet = true }
                        .help("保留應用程式，只清除它的資料")
                        .disabled(state.isUninstalling || state.isLoadingResiduals)
                }
            }
            .controlSize(.regular)
        }
        .padding(16)
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ app: AppInfo) -> some View {
        if state.isLoadingResiduals {
            ProgressView("正在尋找相關檔案…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.residualItems.isEmpty {
            ContentUnavailableView("沒有找到相關檔案", systemImage: "checkmark.circle", description: Text("這個應用程式沒有在資料庫中留下其他資料。"))
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if app.isSystemApp {
                    Label("系統應用程式受 macOS 保護，無法移除。以下僅供檢視。", systemImage: "lock")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                } else if !state.hasFullDiskAccess && state.residualItems.contains(where: { $0.category == .containers }) {
                    permissionHint
                }
                StorageBreakdownBar(items: state.residualItems)
                    .padding(16)

                List {
                    ForEach(categories, id: \.self) { category in
                        section(category, locked: app.isSystemApp)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var permissionHint: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("沙盒容器需要「完全取用磁碟」權限才能移除。")
                .font(.callout)
            Spacer()
            Button("開啟設定") { PermissionManager.openFullDiskAccessSettings() }
                .controlSize(.small)
        }
        .padding(10)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var categories: [ResidualCategory] {
        Set(state.residualItems.map(\.category)).sorted { $0.sortOrder < $1.sortOrder }
    }

    private func section(_ category: ResidualCategory, locked: Bool) -> some View {
        let items = state.residualItems.filter { $0.category == category }
        let selectable = items.filter { !$0.isProtected }
        let selectedCount = selectable.filter(\.isSelected).count
        let checkState: Bool? = selectedCount == 0 ? false : (selectedCount == selectable.count ? true : nil)

        return Section {
            ForEach(items) { item in
                ResidualItemRow(
                    item: item,
                    onToggle: { state.toggleItemSelection(id: item.id) },
                    onReveal: { state.revealInFinder(url: item.url) }
                )
                .disabled(locked)
            }
        } header: {
            HStack(spacing: 8) {
                Toggle(isOn: Binding(get: { checkState ?? false }, set: { _ in state.toggleCategorySelection(category: category) })) {
                    Label(category.displayName, systemImage: category.iconName)
                }
                .toggleStyle(.checkbox)
                .disabled(selectable.isEmpty || locked)
                .modifier(MixedState(isMixed: checkState == nil))

                Spacer()
                Text(FileSizeFormatter.format(items.reduce(0) { $0 + $1.size }))
                    .monospacedDigit()
            }
        }
    }

    // MARK: Footer

    private func footer(_ app: AppInfo) -> some View {
        HStack(spacing: 12) {
            Toggle("先結束執行中的應用程式", isOn: $state.quitAppBeforeTrash)
                .toggleStyle(.checkbox)
                .font(.callout)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("已選 \(state.selectedResiduals.count) 項")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.formattedTotalSelectedSize)
                    .font(.headline)
                    .monospacedDigit()
            }

            Button(role: .destructive) {
                state.showConfirmSheet = true
            } label: {
                if state.isUninstalling {
                    ProgressView().controlSize(.small)
                } else {
                    Text("移至垃圾桶…")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(app.isSystemApp || state.selectedResiduals.isEmpty || state.isUninstalling || state.isLoadingResiduals)
            .help(app.isSystemApp ? "系統應用程式無法移除" : "將勾選的項目移至垃圾桶（⌘⌫）")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// Shows a dash in a checkbox when only some items in a group are selected.
struct MixedState: ViewModifier {
    let isMixed: Bool
    func body(content: Content) -> some View {
        content.overlay(alignment: .leading) {
            if isMixed {
                // shortcut: SwiftUI has no native mixed checkbox on macOS 14; draw the dash over the box.
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 2)
                    .padding(.leading, 3)
                    .allowsHitTesting(false)
            }
        }
    }
}
