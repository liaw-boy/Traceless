import SwiftUI
import AppKit
import AppSweepCore

public struct AppListView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 0) {
            // Header Controls
            VStack(spacing: 10) {
                // Search Bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.accent)
                        .font(.system(size: 13, weight: .semibold))

                    TextField("搜尋應用程式名稱、Bundle ID 或架構...", text: $state.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !state.searchText.isEmpty {
                        Button {
                            state.searchText = ""
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
                    CustomSegmentedControl(selected: $state.filterMode)

                    Spacer(minLength: 0)

                    CustomSortMenu(currentSort: $state.sortOption)
                }
            }
            .padding(12)
            .background(AppTheme.sidebarBg.opacity(0.5))

            Divider()
                .opacity(0.4)

            // App Cards List
            if state.isLoadingApps {
                VStack(spacing: 14) {
                    ProgressView()
                    Text("正在載入系統應用程式與中繼資料...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle")
                        .font(.system(size: 38))
                        .foregroundColor(.secondary.opacity(0.6))

                    Text("找不到符合條件的應用程式")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    if state.filterMode == .unused {
                        Text("您所有的第三方應用程式近期皆有開啟記錄")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(state.filteredApps) { app in
                                AppCardRow(
                                    app: app,
                                    isSelected: state.selectedApp?.id == app.id,
                                    onSelect: {
                                        Task {
                                            await state.selectApp(app)
                                        }
                                    }
                                )
                                .id(app.id)
                            }
                        }
                        .padding(10)
                    }
                }
            }
        }
        .background(AppTheme.canvasBg)
    }
}

private struct AppCardRow: View {
    let app: AppInfo
    let isSelected: Bool
    let onSelect: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            // App Icon with subtle elevation
            Image(nsImage: app.icon(size: 80))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.35), radius: 3, y: 2)

            // Info Stack
            VStack(alignment: .leading, spacing: 3) {
                // Name & Badges
                HStack(spacing: 6) {
                    Text(app.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    archBadge
                    if app.isRunning {
                        StatusBadge(text: "執行中", icon: "bolt.fill", color: AppTheme.emerald)
                    }
                }

                // Subtitle Row: Last used & Version
                HStack(spacing: 6) {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(app.lastUsedDescription)
                    }
                    .foregroundColor(app.isUnusedOver3Months ? AppTheme.amber : .secondary)

                    if !app.version.isEmpty {
                        Text("•")
                            .foregroundColor(.secondary.opacity(0.4))
                        Text("v\(app.version)")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(size: 10.5))
            }

            Spacer(minLength: 4)

            // Size Pill
            Text(app.formattedSize)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(isSelected ? AppTheme.accent.opacity(0.6) : Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(cardBorder, lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
        .onHover { isHovered = $0 }
    }

    private var archBadge: some View {
        Group {
            if app.architecture.contains("Apple Silicon") {
                StatusBadge(text: "Apple Silicon", color: AppTheme.cyan)
            } else if app.architecture.contains("Intel") {
                StatusBadge(text: "Intel", color: AppTheme.amber)
            }
        }
    }

    private var cardBackground: some View {
        ZStack(alignment: .leading) {
            if isSelected {
                LinearGradient(
                    colors: [AppTheme.accent.opacity(0.22), AppTheme.cardBg],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                // Left glowing indicator bar
                Rectangle()
                    .fill(AppTheme.cyan)
                    .frame(width: 3.5)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
            } else {
                (isHovered ? AppTheme.cardBg.opacity(0.9) : AppTheme.cardBg.opacity(0.6))
            }
        }
    }

    private var cardBorder: Color {
        if isSelected {
            return AppTheme.accent.opacity(0.7)
        }
        return isHovered ? Color.white.opacity(0.18) : AppTheme.cardBorder
    }
}
