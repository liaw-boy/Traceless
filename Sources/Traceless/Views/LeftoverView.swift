import SwiftUI
import AppKit
import TracelessCore

public struct LeftoverView: View {
    @ObservedObject var state: AppState
    @State private var collapsed: Set<String> = []

    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("已移除 App 留下的檔案")
                            .font(.display(22))
                            .foregroundStyle(Palette.ink)
                        Text("這些資料夾找不到對應的已安裝 App。全部預設不勾選，確認後再清理。")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                    }
                    Spacer()
                    if !state.leftoverGroups.isEmpty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(FileSizeFormatter.format(state.leftoverGroups.reduce(0) { $0 + $1.totalSize }))
                                .font(.display(22))
                                .monospacedDigit()
                                .foregroundStyle(Palette.ink)
                            Text("\(state.leftoverGroups.count) 組殘留")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.muted)
                        }
                    }
                }
                HStack {
                    FilterChips(options: LeftoverFilterMode.allCases, selection: $state.leftoverFilterMode)
                    Spacer()
                    Menu {
                        Picker("排序方式", selection: $state.leftoverSortOption) {
                            ForEach(LeftoverSortOption.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                        }
                        .pickerStyle(.inline)
                    } label: {
                        Image(systemName: "arrow.up.arrow.down").foregroundStyle(Palette.muted)
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("排序：\(state.leftoverSortOption.rawValue)")
                    .accessibilityLabel("排序方式")
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Rectangle().fill(Palette.hairline).frame(height: 0.5)

            if state.isLoadingLeftovers {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text("正在比對已移除 App 留下的檔案")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredLeftoverGroups.isEmpty && state.inspection.isEmpty {
                EmptyStateView(
                    title: state.leftoverGroups.isEmpty ? "沒有殘留檔案" : "沒有符合的項目",
                    message: "仍安裝中、正在執行或最近 30 天有使用的資料不會出現在這裡。",
                ) {
                    Button("重新掃描") { Task { await state.scanLeftovers() } }
                        .buttonStyle(QuietButtonStyle())
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        systemSection
                        ForEach(state.filteredLeftoverGroups) { group in
                            groupBlock(group)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
            }

            actionBar
        }
        .background(Palette.surface)
        .confirmationDialog(
            "將 \(state.totalSelectedLeftoverCount) 個殘留項目移至垃圾桶？",
            isPresented: $state.showLeftoverConfirm,
            titleVisibility: .visible
        ) {
            Button("移至垃圾桶", role: .destructive) {
                Task { await state.executeAllSelectedLeftoversUninstall() }
            }
        } message: {
            Text("可釋放 \(state.formattedTotalSelectedLeftoverSize)。清空垃圾桶前都能復原。")
        }
        .task {
            if state.leftoverGroups.isEmpty {
                await state.scanLeftovers()
            }
        }
    }

    // MARK: Background & system items

    /// Things macOS will not let another app delete: still-running helpers, system extensions and
    /// login/background items. Each row says what it is and offers the one action that works.
    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("背景與系統項目")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("狀態列殘留圖示多半來自這裡")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            ForEach(state.inspection.ghostProcesses) { ghost in
                systemRow(icon: "bolt.horizontal.circle", title: "\(ghost.name) 仍在執行",
                          detail: "所屬 App 已移除。\(PathUtils.abbreviatingWithTilde(url: URL(fileURLWithPath: ghost.path)))") {
                    Button("結束") { Task { await state.quitGhost(ghost) } }
                        .buttonStyle(QuietButtonStyle())
                }
            }
            ForEach(state.inspection.orphanedExtensions) { ext in
                systemRow(icon: "puzzlepiece.extension", title: ext.name,
                          detail: "系統延伸功能，所屬 App 已移除（\(ext.id)）。macOS 只允許在系統設定中停用。") {
                    Button("開啟設定") { PermissionManager.openLoginItemsSettings() }
                        .buttonStyle(QuietButtonStyle())
                }
            }
            systemRow(icon: "person.badge.clock", title: "登入項目與背景項目",
                      detail: "已移除 App 留下的開機啟動登記，只能在系統設定中關閉。") {
                Button("開啟設定") { PermissionManager.openLoginItemsSettings() }
                    .buttonStyle(QuietButtonStyle())
            }
            .padding(.bottom, 4)
        }
        .background(Palette.canvas.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func systemRow<Action: View>(icon: String, title: String, detail: String, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(Palette.muted)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            action()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    private func groupBlock(_ group: LeftoverAppGroup) -> some View {
        let selected = group.items.filter(\.isSelected).count
        let value: Checkbox.Value = selected == 0 ? .off : (selected == group.items.count ? .on : .mixed)
        let isExpanded = !collapsed.contains(group.id)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Checkbox(value: value) {
                    state.toggleLeftoverGroupSelection(groupId: group.id, select: value != .on)
                }
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        if isExpanded { collapsed.insert(group.id) } else { collapsed.remove(group.id) }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.ink)
                            .lineLimit(1)
                        if group.hasContainers {
                            StatusBadge(text: "含容器", color: Palette.ochre)
                        }
                        Spacer()
                        Text("\(group.items.count) 項")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.muted)
                        Text(group.formattedTotalSize)
                            .font(.display(13))
                            .monospacedDigit()
                            .foregroundStyle(Palette.ink)
                            .frame(minWidth: 70, alignment: .trailing)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .rotationEffect(.degrees(isExpanded ? 0 : -90))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(group.name)，\(group.formattedTotalSize)")
                .accessibilityHint(isExpanded ? "收合" : "展開")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.items) { item in
                        ResidualItemRow(
                            item: item,
                            onToggle: { state.toggleLeftoverItem(groupId: group.id, itemId: item.id) },
                            onReveal: { state.revealInFinder(url: item.url) }
                        )
                    }
                }
                .padding(.leading, 18)
                .padding(.bottom, 6)
            }
        }
        .background(Palette.canvas.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            Button("全選") { state.selectAllLeftovers(true) }
                .buttonStyle(QuietButtonStyle())
                .disabled(state.filteredLeftoverGroups.isEmpty)
            Button("全不選") { state.selectAllLeftovers(false) }
                .buttonStyle(QuietButtonStyle())
                .disabled(state.totalSelectedLeftoverCount == 0)
            Spacer()
            Text(state.totalSelectedLeftoverCount == 0 ? "尚未勾選項目" : "已勾選 \(state.totalSelectedLeftoverCount) 項，可釋放 \(state.formattedTotalSelectedLeftoverSize)")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .monospacedDigit()
            Button {
                state.showLeftoverConfirm = true
            } label: {
                HStack(spacing: 6) {
                    if state.isUninstalling { ProgressView().controlSize(.small).tint(.white) }
                    Text("移至垃圾桶")
                }
            }
            .buttonStyle(SolidButtonStyle(color: Palette.brickFill, textColor: .white))
            .disabled(state.totalSelectedLeftoverCount == 0 || state.isUninstalling)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Palette.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
    }
}
