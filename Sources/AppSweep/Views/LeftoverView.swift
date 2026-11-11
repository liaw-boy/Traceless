import SwiftUI
import AppKit
import AppSweepCore

public struct LeftoverView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // 1. Unified Header Controls (Matching AppListView Exactly)
            VStack(spacing: 10) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.accent)
                        .font(.system(size: 13, weight: .semibold))

                    TextField("搜尋孤立殘留名稱、Bundle ID 或路徑...", text: $state.leftoverSearchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !state.leftoverSearchText.isEmpty {
                        Button {
                            state.leftoverSearchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )

                // Filter & Sort Row
                HStack(spacing: 8) {
                    CustomLeftoverFilterControl(selected: $state.leftoverFilterMode)

                    Spacer(minLength: 0)

                    CustomLeftoverSortMenu(currentSort: $state.leftoverSortOption)
                }
            }
            .padding(12)
            .background(AppTheme.sidebarBg.opacity(0.5))

            Divider()
                .opacity(0.4)

            // 2. Action Toolbar (Select All / Rescan / Clean Selected)
            HStack(spacing: 12) {
                // Left: Count & Select All
                HStack(spacing: 10) {
                    Text("共 \(state.filteredLeftoverGroups.count) 個應用殘留組")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)

                    if !state.filteredLeftoverGroups.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.4))

                        Button("全選") {
                            state.selectAllLeftovers(true)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(AppTheme.cyan)

                        Text("|")
                            .foregroundColor(.secondary.opacity(0.4))

                        Button("全不選") {
                            state.selectAllLeftovers(false)
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Right: Rescan & Master Clean
                HStack(spacing: 10) {
                    // Rescan Button
                    Button {
                        Task {
                            await state.scanLeftovers()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .rotationEffect(.degrees(state.isLoadingLeftovers ? 360 : 0))
                                .animation(state.isLoadingLeftovers ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: state.isLoadingLeftovers)
                            Text(state.isLoadingLeftovers ? "比對中..." : "重新掃描")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isLoadingLeftovers)

                    // Master Clean Button
                    if !state.leftoverGroups.isEmpty {
                        Button {
                            Task {
                                await state.executeAllSelectedLeftoversUninstall()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "trash.fill")
                                Text("清理選定 (\(state.totalSelectedLeftoverCount) 項 · \(state.formattedTotalSelectedLeftoverSize))")
                            }
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                state.totalSelectedLeftoverCount == 0 ?
                                    LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                                    AppTheme.dangerGradient
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .shadow(color: state.totalSelectedLeftoverCount == 0 ? .clear : Color.red.opacity(0.35), radius: 5, y: 2)
                        }
                        .buttonStyle(.plain)
                        .disabled(state.totalSelectedLeftoverCount == 0)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(AppTheme.cardSubtle.opacity(0.8))

            Divider()
                .opacity(0.3)

            // 3. Main Content
            if state.isLoadingLeftovers {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("正在深層比對系統中的孤立殘留項目...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredLeftoverGroups.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 42))
                        .foregroundColor(AppTheme.emerald)

                    Text(state.leftoverGroups.isEmpty ? "系統乾淨！未發現已刪除應用的孤立殘留檔案" : "沒有符合篩選條件的孤立殘留")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    Text("AppSweep 已自動排除所有仍安裝在系統中的應用程式資料")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Button("重新掃描") {
                        Task { await state.scanLeftovers() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(AppTheme.cyan)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(state.filteredLeftoverGroups) { group in
                            leftoverGroupCard(group: group)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .background(AppTheme.canvasBg)
        .task {
            if state.leftoverGroups.isEmpty && !state.isLoadingLeftovers {
                await state.scanLeftovers()
            }
        }
    }

    private func leftoverGroupCard(group: LeftoverAppGroup) -> some View {
        let hasSelection = group.items.contains { $0.isSelected }
        let allSelected = group.items.allSatisfy { $0.isSelected }

        return VStack(spacing: 0) {
            // Group Header Card
            HStack(spacing: 10) {
                CustomCheckbox(
                    isChecked: allSelected,
                    onToggle: { state.toggleLeftoverGroupSelection(groupId: group.id, select: !allSelected) }
                )

                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.cardSubtle)
                        .frame(width: 32, height: 32)
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.cyan)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(group.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        if group.hasContainers {
                            Text("容器")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(AppTheme.amber)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(AppTheme.amber.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Text(group.id)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(group.formattedTotalSize)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)

                Button {
                    Task {
                        await state.executeLeftoverGroupUninstall(group: group)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("清理此組")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(hasSelection ? .white : .secondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4.5)
                    .background(hasSelection ? AppTheme.coral.opacity(0.85) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .disabled(!hasSelection)
            }
            .padding(12)
            .background(AppTheme.cardBg)

            Divider()
                .opacity(0.3)

            // Child Residual Items
            VStack(spacing: 6) {
                ForEach(group.items) { item in
                    ResidualItemRow(
                        item: item,
                        onToggle: { state.toggleLeftoverItem(groupId: group.id, itemId: item.id) },
                        onReveal: { state.revealInFinder(url: item.url) }
                    )
                }
            }
            .padding(10)
            .background(Color.black.opacity(0.15))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }
}
