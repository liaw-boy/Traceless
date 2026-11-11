import SwiftUI
import AppKit
import AppSweepCore

public struct MainView: View {
    @StateObject private var state = AppState()

    private var searchText: Binding<String> {
        state.activeTab == .leftovers ? $state.leftoverSearchText : $state.searchText
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail
                .overlay(alignment: .bottom) { toast }
        }
        .searchable(text: searchText, placement: .toolbar, prompt: state.activeTab == .leftovers ? "搜尋殘留" : "搜尋應用程式")
        .toolbar {
            ToolbarItem {
                Button {
                    Task {
                        if state.activeTab == .leftovers { await state.scanLeftovers() } else { await state.loadApps() }
                    }
                } label: {
                    Label("重新掃描", systemImage: "arrow.clockwise")
                }
                .help("重新掃描（⌘R）")
                .keyboardShortcut("r", modifiers: .command)
                .disabled(state.isLoadingApps || state.isLoadingLeftovers)
            }
        }
        .background {
            // ⌘1…⌘3 switch sections, like Finder/Mail sidebars.
            ForEach(Array(NavigationTab.allCases.enumerated()), id: \.element) { index, tab in
                Button("") { state.activeTab = tab }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    .hidden()
            }
        }
        .sheet(isPresented: $state.showPermissionSheet) {
            PermissionHelpSheet(state: state)
        }
        .task {
            await state.loadApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.refreshPermissions()
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch state.activeTab {
        case .apps:
            HSplitView {
                AppListView(state: state)
                    .frame(minWidth: 300, idealWidth: 340, maxWidth: 460)
                AppDetailView(state: state)
                    .frame(minWidth: 480)
            }
            .navigationTitle("應用程式")
        case .dragDrop:
            DragDropView(state: state)
                .navigationTitle("拖曳移除")
        case .leftovers:
            LeftoverView(state: state)
                .navigationTitle("殘留檔案")
        }
    }

    private var sidebar: some View {
        List(selection: Binding(get: { state.activeTab }, set: { if let tab = $0 { state.activeTab = tab } })) {
            Section {
                ForEach(NavigationTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .badge(badge(for: tab))
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 10) {
                if !state.hasFullDiskAccess {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("權限受限", systemImage: "exclamationmark.triangle.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text("沒有「完全取用磁碟」權限時，沙盒容器無法移除。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("授權…") { state.showPermissionSheet = true }
                            .controlSize(.small)
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                HStack {
                    Button {
                        state.openTrash()
                    } label: {
                        Label("垃圾桶", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                    Spacer()
                    Text(AppVersion.display)
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
            }
            .padding(12)
        }
    }

    private func badge(for tab: NavigationTab) -> Int {
        switch tab {
        case .apps: return state.installedApps.count
        case .leftovers: return state.leftoverGroups.count
        case .dragDrop: return 0
        }
    }

    @ViewBuilder
    private var toast: some View {
        if state.showToast {
            HStack(spacing: 10) {
                Image(systemName: state.toastIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(state.toastIsError ? .orange : .green)
                Text(state.toastMessage)
                    .lineLimit(2)
                if !state.toastIsError {
                    Button("打開垃圾桶") { state.openTrash() }
                        .buttonStyle(.link)
                }
            }
            .font(.callout)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
            .padding(.bottom, 70)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}
