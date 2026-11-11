import SwiftUI
import AppKit
import UprootCore

public struct AppListView: View {
    @ObservedObject var state: AppState

    private var selection: Binding<AppInfo.ID?> {
        Binding(
            get: { state.selectedApp?.id },
            set: { id in
                guard let id, id != state.selectedApp?.id,
                      let app = state.filteredApps.first(where: { $0.id == id }) else { return }
                Task { await state.selectApp(app) }
            }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("篩選", selection: $state.filterMode) {
                    ForEach(AppFilterMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Menu {
                    Picker("排序方式", selection: $state.sortOption) {
                        ForEach(AppSortOption.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("排序：\(state.sortOption.rawValue)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if state.isLoadingApps && state.installedApps.isEmpty {
                ProgressView("正在讀取應用程式…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredApps.isEmpty {
                ContentUnavailableView {
                    Label("沒有符合的應用程式", systemImage: "magnifyingglass")
                } description: {
                    Text(state.filterMode == .unused ? "最近三個月內都有開啟過。" : "試試其他關鍵字或篩選條件。")
                }
            } else {
                let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
                List(state.filteredApps, selection: selection) { app in
                    AppRow(app: app, isRunning: running.contains(app.bundleIdentifier))
                        .tag(app.id)
                }
                .listStyle(.inset)
            }

            Divider()
            Text("\(state.filteredApps.count) 個應用程式 · 共 \(FileSizeFormatter.format(state.filteredApps.reduce(0) { $0 + $1.size }))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
    }
}

private struct AppRow: View {
    let app: AppInfo
    let isRunning: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon())
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(app.name).lineLimit(1)
                    if isRunning {
                        Circle().fill(.green).frame(width: 6, height: 6).help("執行中")
                    }
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(app.isUnusedOver3Months && !app.isSystemApp ? AnyShapeStyle(.orange) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Text(app.formattedSize)
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = [app.lastUsedDescription]
        if app.architecture == "Intel" { parts.append("Intel") }
        if !app.version.isEmpty { parts.append(app.version) }
        return parts.joined(separator: " · ")
    }
}
