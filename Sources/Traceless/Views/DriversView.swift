import SwiftUI
import AppKit
import TracelessCore

/// Third-party drivers, extensions and background services, explained in plain words and grouped
/// by vendor, with the app that still uses them — or a clear "app removed" flag.
public struct DriversView: View {
    @ObservedObject var state: AppState

    private var groups: [(vendor: String, items: [DriverItem])] {
        Dictionary(grouping: state.visibleDriverItems, by: \.vendor)
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                let lo = lhs.items.contains(where: \.isOrphaned), ro = rhs.items.contains(where: \.isOrphaned)
                return lo != ro ? lo : lhs.vendor.localizedStandardCompare(rhs.vendor) == .orderedAscending
            }
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Palette.hairline).frame(height: 0.5)

            if state.isLoadingDrivers && state.driverItems.isEmpty {
                VStack(spacing: 12) {
                    ProgressView().controlSize(.small)
                    Text("正在檢查系統裡的驅動與背景項目")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if groups.isEmpty {
                EmptyStateView(
                    title: state.showOnlyOrphanDrivers ? "沒有殘留的驅動或背景項目" : "沒有第三方驅動",
                    message: state.showOnlyOrphanDrivers ? "每個驅動與背景服務都屬於目前安裝中的 App。" : "這台 Mac 沒有安裝第三方系統元件。"
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(groups, id: \.vendor) { group in
                            vendorBlock(group.vendor, group.items)
                        }
                    }
                    .padding(14)
                }
            }
            actionBar
        }
        .background(Palette.surface)
        .confirmationDialog("將 \(state.selectedDriverItems.count) 個項目移至垃圾桶？",
                            isPresented: $state.showDriverConfirm, titleVisibility: .visible) {
            Button("移至垃圾桶", role: .destructive) { Task { await state.trashSelectedDrivers() } }
        } message: {
            Text("這些檔案在系統資料夾，會要求一次管理者密碼。硬體驅動要重新開機後才會完全卸載。清空垃圾桶前都能復原。")
        }
        .task { if state.driverItems.isEmpty { await state.scanDrivers() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("驅動與背景項目")
                        .font(.display(22))
                        .foregroundStyle(Palette.ink)
                    Text("刪除 App 時，它安裝到系統裡的驅動、背景服務常會留下來，造成聲音選單多出裝置、狀態列殘留圖示或週邊衝突。")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 16)
                if state.orphanDriverCount > 0 {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(state.orphanDriverCount)")
                            .font(.display(22))
                            .foregroundStyle(Palette.ochre)
                        Text("項屬於已移除的 App")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.muted)
                    }
                }
            }
            HStack {
                FilterChips(options: DriverScope.allCases, selection: Binding(
                    get: { state.showOnlyOrphanDrivers ? .orphaned : .all },
                    set: { state.showOnlyOrphanDrivers = ($0 == .orphaned) }
                ))
                Spacer()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 14)
    }

    private func vendorBlock(_ vendor: String, _ items: [DriverItem]) -> some View {
        let owner = items.compactMap(\.ownerApp).first
        let removable = items.filter { $0.trashItem != nil }
        let selected = removable.filter(\.isSelected).count
        let value: Checkbox.Value = selected == 0 ? .off : (selected == removable.count ? .on : .mixed)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Checkbox(value: value, isEnabled: !removable.isEmpty, label: vendor) {
                    state.setVendorSelection(vendor, select: value != .on)
                }
                Text(vendor)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                if let owner {
                    StatusBadge(text: "使用中：\(owner)", color: Palette.muted)
                } else {
                    StatusBadge(text: "App 已移除", icon: "exclamationmark.triangle.fill", color: Palette.ochre)
                }
                Spacer()
                Text("\(items.count) 項")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.muted)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            ForEach(items) { item in
                driverRow(item)
            }
            .padding(.bottom, 4)
        }
        .background(Palette.canvas.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func driverRow(_ item: DriverItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if item.trashItem != nil {
                    Checkbox(value: item.isSelected ? .on : .off, label: item.name) { state.toggleDriver(item.id) }
                } else {
                    Color.clear.frame(width: 16, height: 16)
                }
            }
            .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.kind.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(item.name)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                Text(item.kind.symptom)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted)
                if case .settings(let where_) = item.removal {
                    Text("macOS 只允許在「\(where_)」中關閉")
                        .font(.system(size: 11))
                        .foregroundStyle(item.isOrphaned ? Palette.ochre : Palette.muted)
                }
                Text(item.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.muted.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                switch item.removal {
                case .settings:
                    Button("開啟設定") { PermissionManager.openLoginItemsSettings() }
                        .buttonStyle(QuietButtonStyle())
                case .quit:
                    Button("結束") { Task { await state.quitDriverProcess(item) } }
                        .buttonStyle(QuietButtonStyle())
                case .trash(let url):
                    if item.size > 0 {
                        Text(FileSizeFormatter.format(item.size))
                            .font(.display(12, .medium))
                            .monospacedDigit()
                            .foregroundStyle(Palette.muted)
                    }
                    Button { state.revealInFinder(url: url) } label: {
                        Image(systemName: "arrow.up.forward.app").foregroundStyle(Palette.muted)
                    }
                    .buttonStyle(.plain)
                    .help("在 Finder 中顯示")
                    .accessibilityLabel("在 Finder 中顯示")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { state.toggleDriver(item.id) }
    }

    private var actionBar: some View {
        HStack(spacing: 14) {
            // One line only: a wrapping label in a squeezed HStack grows tall and pushes the window content off-screen.
            Button("登入項目與延伸功能…") { PermissionManager.openLoginItemsSettings() }
                .buttonStyle(QuietButtonStyle())
                .help("開機登記的背景項目無法由其他 App 讀取，只能在這裡檢查與關閉")
            Spacer()
            Text(state.selectedDriverItems.isEmpty ? "尚未勾選項目" : "已勾選 \(state.selectedDriverItems.count) 項")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
                .lineLimit(1)
            Button {
                state.showDriverConfirm = true
            } label: {
                HStack(spacing: 6) {
                    if state.isUninstalling { ProgressView().controlSize(.small).tint(.white) }
                    Text("移至垃圾桶")
                }
            }
            .buttonStyle(SolidButtonStyle(color: Palette.brickFill, textColor: .white))
            .disabled(state.selectedDriverItems.isEmpty || state.isUninstalling)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(Palette.canvas)
        .overlay(alignment: .top) { Rectangle().fill(Palette.hairline).frame(height: 0.5) }
    }
}

enum DriverScope: String, CaseIterable, Identifiable {
    case orphaned = "App 已移除"
    case all = "全部"
    var id: String { rawValue }
}
