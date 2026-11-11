import SwiftUI
import AppKit
import TracelessCore

public struct AppDetailView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        Group {
            if let app = state.selectedApp {
                VStack(spacing: 0) {
                    hero(app)
                    content(app)
                    actionBar(app)
                }
                .confirmationDialog(
                    "將 \(state.selectedResiduals.count) 個項目移至垃圾桶？",
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
                    "重置「\(app.name)」？",
                    isPresented: $state.showResetConfirmSheet,
                    titleVisibility: .visible
                ) {
                    Button("重置", role: .destructive) {
                        Task { await state.executeResetApp() }
                    }
                } message: {
                    Text("App 本身會保留，它的偏好設定、快取、容器與登入狀態會移至垃圾桶。下次開啟時就像剛安裝。")
                }
            } else {
                EmptyStateView(title: "選一個 App", message: "左邊選取後，這裡會列出它在 Mac 上留下的所有檔案。")
            }
        }
        .background(Palette.surface)
    }

    private func confirmMessage(_ app: AppInfo) -> String {
        var lines = ["可釋放 \(state.formattedTotalSelectedSize)。清空垃圾桶前都能復原。"]
        if app.isRunning && state.quitAppBeforeTrash {
            lines.append("「\(app.name)」正在執行，會先結束它。")
        }
        if state.selectedResiduals.contains(where: { !$0.url.path.hasPrefix(PathUtils.homeDirectory.path + "/") && $0.category != .appBundle }) {
            lines.append("部分項目在系統資料夾，可能會要求管理者密碼。")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Hero

    private func hero(_ app: AppInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 16) {
                Image(nsImage: app.icon())
                    .resizable()
                    .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(app.name)
                            .font(.display(24))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if app.isSystemApp {
                            StatusBadge(text: "系統", icon: "lock.fill")
                        }
                        if app.isRunning {
                            StatusBadge(text: "執行中", color: Palette.pine)
                        }
                    }
                    Text(app.bundleIdentifier.isEmpty ? PathUtils.abbreviatingWithTilde(url: app.url) : app.bundleIdentifier)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .textSelection(.enabled)
                        .lineLimit(1)
                }

                Spacer(minLength: 12)

                HStack(spacing: 8) {
                    Button { state.revealInFinder(url: app.url) } label: {
                        Label("在 Finder 顯示", systemImage: "folder")
                    }
                    .buttonStyle(QuietButtonStyle())
                    if !app.isSystemApp {
                        Button("重置…") { state.showResetConfirmSheet = true }
                            .buttonStyle(QuietButtonStyle())
                            .help("保留 App，只清除它的資料")
                            .disabled(state.isUninstalling || state.isLoadingResiduals)
                    }
                }
            }

            // Facts as label/value pairs rather than one run-on line.
            HStack(alignment: .top, spacing: 28) {
                fact("版本", app.version.isEmpty ? "—" : app.version)
                fact("架構", app.architecture)
                fact("上次開啟", app.lastUsedDescription)
                fact("位置", PathUtils.abbreviatingWithTilde(url: app.url.deletingLastPathComponent()))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    private func fact(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Palette.muted)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.ink)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(_ app: AppInfo) -> some View {
        if state.isLoadingResiduals {
            VStack(spacing: 12) {
                ProgressView().controlSize(.small)
                Text("正在尋找它留下的檔案")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if state.residualItems.isEmpty {
            EmptyStateView(title: "沒有找到相關檔案", message: "這個 App 沒有在資料庫留下其他東西。")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                StorageBreakdownBar(items: state.residualItems)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)

                if app.isSystemApp {
                    notice(icon: "lock", color: Palette.muted, text: "系統 App 受 macOS 保護，無法移除；以下只供檢視。")
                } else if !state.hasFullDiskAccess && state.residualItems.contains(where: { $0.category == .containers }) {
                    notice(icon: "exclamationmark.triangle.fill", color: Palette.ochre,
                           text: "沙盒容器需要「完全取用磁碟」權限才能移除。") {
                        Button("開啟設定") { PermissionManager.openFullDiskAccessSettings() }
                            .buttonStyle(QuietButtonStyle())
                    }
                }

                Rectangle().fill(Palette.hairline).frame(height: 0.5)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(categories, id: \.self) { category in
                            section(category, locked: app.isSystemApp)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
            }
        }
    }

    private func notice(icon: String, color: Color, text: String) -> some View {
        notice(icon: icon, color: color, text: text) { EmptyView() }
    }

    private func notice<Trailing: View>(icon: String, color: Color, text: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            Text(text).font(.system(size: 12)).foregroundStyle(Palette.ink)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var categories: [ResidualCategory] {
        Set(state.residualItems.map(\.category)).sorted { $0.sortOrder < $1.sortOrder }
    }

    private func section(_ category: ResidualCategory, locked: Bool) -> some View {
        let items = state.residualItems.filter { $0.category == category }
        let selectable = items.filter { !$0.isProtected }
        let selectedCount = selectable.filter(\.isSelected).count
        let value: Checkbox.Value = selectedCount == 0 ? .off : (selectedCount == selectable.count ? .on : .mixed)

        return Section {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    ResidualItemRow(
                        item: item,
                        isLocked: locked,
                        onToggle: { state.toggleItemSelection(id: item.id) },
                        onReveal: { state.revealInFinder(url: item.url) }
                    )
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
                }
            }
            .padding(.bottom, 14)
        } header: {
            HStack(spacing: 10) {
                Checkbox(value: value, isEnabled: !selectable.isEmpty && !locked) {
                    state.toggleCategorySelection(category: category)
                }
                RoundedRectangle(cornerRadius: 2).fill(category.tint).frame(width: 3, height: 14)
                Text(category.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Text("\(items.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                Spacer()
                Text(FileSizeFormatter.format(items.reduce(0) { $0 + $1.size }))
                    .font(.display(13))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Palette.surface)
        }
    }

    // MARK: Action bar

    private func actionBar(_ app: AppInfo) -> some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Checkbox(value: state.quitAppBeforeTrash ? .on : .off) { state.quitAppBeforeTrash.toggle() }
                Text("先結束執行中的 App")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
                    .onTapGesture { state.quitAppBeforeTrash.toggle() }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("先結束執行中的 App")

            Spacer()

            Text(summary)
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()

            Button {
                state.showConfirmSheet = true
            } label: {
                HStack(spacing: 6) {
                    if state.isUninstalling {
                        ProgressView().controlSize(.small).tint(.white)
                    }
                    Text("移至垃圾桶")
                }
            }
            .buttonStyle(SolidButtonStyle(color: Palette.brickFill))
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(app.isSystemApp || state.selectedResiduals.isEmpty || state.isUninstalling || state.isLoadingResiduals)
            .help(app.isSystemApp ? "系統 App 無法移除" : "將勾選的項目移至垃圾桶（⌘⌫）")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Palette.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
    }

    private var summary: String {
        let count = state.selectedResiduals.count
        return count == 0 ? "尚未勾選項目" : "已勾選 \(count) 項，可釋放 \(state.formattedTotalSelectedSize)"
    }
}
