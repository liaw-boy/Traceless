import SwiftUI
import AppKit
import AppSweepCore

public struct AppDetailView: View {
    @ObservedObject var state: AppState

    public var body: some View {
        Group {
            if let app = state.selectedApp {
                VStack(spacing: 0) {
                    // 1. App Hero Banner
                    appHeroBanner(app: app)

                    Divider()
                        .opacity(0.4)

                    // Contextual Container Warning (if app has sandbox containers and FDA not granted)
                    if !state.hasFullDiskAccess && state.residualItems.contains(where: { $0.category == .containers }) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppTheme.amber)
                                .font(.system(size: 13))

                            VStack(alignment: .leading, spacing: 2) {
                                Text("此應用程式包含沙盒容器（Containers）")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                                Text("受 macOS 系統隱私保護，需授權「完全取用磁碟」權限方可移動容器至垃圾桶。")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Button("前往授權") {
                                PermissionManager.openFullDiskAccessSettings()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.cyan)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4.5)
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(10)
                        .background(AppTheme.amber.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.amber.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                    }

                    // 2. Storage Breakdown Bar
                    if !state.residualItems.isEmpty {
                        StorageBreakdownBar(items: state.residualItems)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)

                        HStack(spacing: 8) {
                            Text("關聯檔案明細 (\(state.residualItems.count) 項 · 依容量排序)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)

                            Spacer()

                            Button("全選") { state.setAllSelected(true) }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(AppTheme.cyan)

                            Text("|")
                                .foregroundColor(.secondary.opacity(0.4))

                            Button("全不選") { state.setAllSelected(false) }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                    }

                    // 3. Residual Items List
                    if state.isLoadingResiduals {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("正在深層比對關聯資料、沙盒與暫存...")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if state.residualItems.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(AppTheme.emerald)
                            Text("未發現其他關聯殘留項目")
                                .font(.system(size: 14, weight: .semibold))
                            Text("此應用程式未在系統庫中留下額外資料。")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                                ForEach(groupedCategories, id: \.self) { category in
                                    categorySection(for: category)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }

                    Divider()
                        .opacity(0.4)

                    // 4. Pinned Bottom Action Toolbar
                    bottomActionToolbar(app: app)
                }
                .background(AppTheme.canvasBg)
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text("請選擇左側應用程式以檢視詳細分析")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)

                    Text("AppSweep 將分析主程式、偏好設定、容器與相關快取")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.canvasBg)
            }
        }
    }

    // MARK: - Hero Banner
    private func appHeroBanner(app: AppInfo) -> some View {
        HStack(spacing: 16) {
            // Crisp Retina App Icon
            Image(nsImage: app.icon(size: 128))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.4), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 5) {
                // Name & Version & System lock
                HStack(spacing: 8) {
                    Text(app.name)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(.white)

                    if !app.version.isEmpty {
                        Text("v\(app.version)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                    }

                    if app.isSystemApp {
                        StatusBadge(text: "系統保護", icon: "lock.shield.fill", color: .secondary)
                    }

                    if app.isRunning {
                        StatusBadge(text: "正在執行", icon: "bolt.fill", color: AppTheme.emerald)
                    }
                }

                // Metadata Badges Row: Arch, Last Used
                HStack(spacing: 8) {
                    // Architecture badge
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                        Text(app.architecture)
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(AppTheme.cyan)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AppTheme.cyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                    // Last used badge
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text("上次開啟：\(app.lastUsedDescription)")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(app.isUnusedOver3Months ? AppTheme.amber : .secondary)
                }

                // Bundle ID & Path
                VStack(alignment: .leading, spacing: 2) {
                    if !app.bundleIdentifier.isEmpty {
                        Text(app.bundleIdentifier)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Text(PathUtils.abbreviatingWithTilde(url: app.url))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }

            Spacer()

            // Header Action Buttons
            VStack(alignment: .trailing, spacing: 6) {
                // Reveal in Finder Button
                Button {
                    state.revealInFinder(url: app.url)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                        Text("在 Finder 檢視")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                // Reset App Button (CleanMyMac style)
                if !app.isSystemApp {
                    Button {
                        state.showResetConfirmSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("重置此應用")
                        }
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(AppTheme.amber)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.amber.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .help("保留主應用程式，僅清除其偏好設定、容器與快取至出廠狀態")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(AppTheme.cardSubtle)
    }

    // MARK: - Category Sections
    private var groupedCategories: [ResidualCategory] {
        var set = Set<ResidualCategory>()
        for item in state.residualItems {
            set.insert(item.category)
        }
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func categorySection(for category: ResidualCategory) -> some View {
        let items = state.residualItems
            .filter { $0.category == category }
            .sorted { $0.size > $1.size }
        let subtotal = items.reduce(0) { $0 + $1.size }
        let allSelected = items.allSatisfy { $0.isSelected }
        let anyProtected = items.contains { $0.isProtected }

        return Section {
            VStack(spacing: 2) {
                ForEach(items) { item in
                    ResidualItemRow(
                        item: item,
                        onToggle: { state.toggleItemSelection(id: item.id) },
                        onReveal: { state.revealInFinder(url: item.url) }
                    )
                }
            }
            .padding(6)
            .background(AppTheme.cardBg.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        } header: {
            HStack(spacing: 9) {
                // Category-wide toggle
                CustomCheckbox(
                    isChecked: allSelected,
                    isProtected: anyProtected,
                    onToggle: { state.toggleCategorySelection(category: category) }
                )

                Image(systemName: category.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.accent)

                Text(category.displayName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Text("(\(items.count))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                Text(FileSizeFormatter.format(subtotal))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(AppTheme.sidebarBg.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Bottom Action Toolbar
    private func bottomActionToolbar(app: AppInfo) -> some View {
        HStack(spacing: 14) {
            // Select All / Deselect All
            HStack(spacing: 8) {
                Button("全選") {
                    state.setAllSelected(true)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.accent)

                Text("|")
                    .foregroundColor(.secondary.opacity(0.4))

                Button("全不選") {
                    state.setAllSelected(false)
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            }

            Spacer()

            // Selected count & size
            VStack(alignment: .trailing, spacing: 2) {
                Text("已選擇 \(state.selectedResiduals.count) 個項目")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)

                HStack(spacing: 4) {
                    Text("預計釋放")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(state.formattedTotalSelectedSize)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }

            // Move to Trash Button
            Button {
                state.showConfirmSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 13))
                    Text("移至垃圾桶")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .foregroundColor(.white)
                .background(
                    app.isSystemApp || state.selectedResiduals.isEmpty ?
                        LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)], startPoint: .top, endPoint: .bottom) :
                        AppTheme.dangerGradient
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: app.isSystemApp || state.selectedResiduals.isEmpty ? .clear : Color.red.opacity(0.35), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(state.selectedResiduals.isEmpty || app.isSystemApp)
            .help(app.isSystemApp ? "系統核心保護，無法刪除" : "將所有勾選項安全移至 macOS 垃圾桶")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.sidebarBg)
    }
}
