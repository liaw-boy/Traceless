import SwiftUI
import AppKit
import TracelessCore

public struct AppListView: View {
    @ObservedObject var state: AppState
    @FocusState private var listFocused: Bool

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                FilterChips(options: AppFilterMode.allCases, selection: $state.filterMode)
                Spacer(minLength: 0)
                sortMenu
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            if state.isLoadingApps && state.installedApps.isEmpty {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.small)
                    Text("正在讀取應用程式")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredApps.isEmpty {
                EmptyStateView(
                    title: "沒有符合的應用程式",
                    message: state.filterMode == .unused ? "每個 App 最近三個月內都開啟過。" : "換個關鍵字或篩選條件試試。",
                )
            } else {
                let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(state.filteredApps) { app in
                                AppRow(app: app,
                                       isSelected: state.selectedApp?.id == app.id,
                                       isRunning: running.contains(app.bundleIdentifier))
                                    .id(app.id)
                                    .onTapGesture {
                                        listFocused = true
                                        Task { await state.selectApp(app) }
                                    }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .focusable()
                    .focusEffectDisabled()
                    .focused($listFocused)
                    .onMoveCommand { direction in
                        moveSelection(direction == .up ? -1 : direction == .down ? 1 : 0, proxy: proxy)
                    }
                }
            }

            Rectangle().fill(Palette.hairline).frame(height: 0.5)
            HStack {
                Text("\(state.filteredApps.count) 個應用程式")
                Spacer()
                Text("共 \(FileSizeFormatter.format(state.filteredApps.reduce(0) { $0 + $1.size }))")
                    .monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(Palette.muted)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
        }
        .background(Palette.canvas)
    }

    private var sortMenu: some View {
        Menu {
            Picker("排序方式", selection: $state.sortOption) {
                ForEach(AppSortOption.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .foregroundStyle(Palette.muted)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("排序：\(state.sortOption.rawValue)")
        .accessibilityLabel("排序方式")
    }

    /// Arrow keys move through the list like a native table.
    private func moveSelection(_ delta: Int, proxy: ScrollViewProxy) {
        let apps = state.filteredApps
        guard delta != 0, !apps.isEmpty else { return }
        let current = apps.firstIndex { $0.id == state.selectedApp?.id } ?? -1
        let next = apps[min(max(current + delta, 0), apps.count - 1)]
        proxy.scrollTo(next.id)
        Task { await state.selectApp(next) }
    }
}

private struct AppRow: View {
    let app: AppInfo
    let isSelected: Bool
    let isRunning: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 11) {
            Image(nsImage: app.icon())
                .resizable()
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if isRunning {
                        Circle()
                            .fill(isSelected ? Color.white : Palette.pine)
                            .frame(width: 6, height: 6)
                            .help("執行中")
                            .accessibilityLabel("執行中")
                    }
                }
                Text(app.lastUsedDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(subtitleColor)
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(app.formattedSize)
                .font(.display(12, .medium))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Palette.muted)
        }
        .foregroundStyle(isSelected ? Color.white : Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(background, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var background: Color {
        if isSelected { return Palette.pineFill }
        return isHovered ? Palette.pineWash.opacity(0.6) : .clear
    }

    private var subtitleColor: Color {
        if isSelected { return Color.white.opacity(0.8) }
        return app.isUnusedOver3Months && !app.isSystemApp ? Palette.ochre : Palette.muted
    }
}
