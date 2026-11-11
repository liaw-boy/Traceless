import SwiftUI
import AppKit
import TracelessCore

public struct MainView: View {
    @ObservedObject var state: AppState

    private var searchText: Binding<String> {
        state.activeTab == .leftovers ? $state.leftoverSearchText : $state.searchText
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 216, max: 260)
        } detail: {
            detail
                .overlay(alignment: .bottom) { toast }
        }
        .tint(Palette.pine)
        // Toolbar shares the canvas colour and drops the duplicate title; each page has its own heading.
        .toolbarBackground(Palette.canvas, for: .windowToolbar)
        .toolbarBackground(.visible, for: .windowToolbar)
        .modifier(HideToolbarTitle())
        .searchable(text: searchText, placement: .toolbar, prompt: state.activeTab == .leftovers ? "搜尋殘留" : "搜尋 App")
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
            // HStack (not HSplitView) so both panes respect the toolbar's safe area.
            HStack(spacing: 0) {
                AppListView(state: state)
                    .frame(width: 330)
                Rectangle().fill(Palette.hairline).frame(width: 0.5)
                AppDetailView(state: state)
                    .frame(minWidth: 520)
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

    // MARK: Sidebar

    /// A List hosts the sidebar: with plain stacks, NavigationSplitView laid every column out under
    /// the toolbar (frames started at y = 0 despite a 52 pt top safe area).
    private var sidebar: some View {
        List {
            HStack(spacing: 10) {
                TraceMark(size: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Traceless")
                        .font(.display(15, .bold))
                        .foregroundStyle(Palette.ink)
                    Text("無痕移除")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.muted)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(NavigationTab.allCases) { tab in
                navRow(tab)
                    .listRowInsets(EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Palette.sidebar)
        .safeAreaInset(edge: .bottom) { sidebarFooter }
    }

    private var sidebarFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !state.hasFullDiskAccess {
                Button { state.showPermissionSheet = true } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 15))
                            .foregroundStyle(Palette.ochre)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("開啟完整權限")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.ink)
                            Text("才能移除沙盒 App 的資料")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.muted)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.muted)
                            .padding(.top, 3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Palette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 0.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("了解如何授權「完全取用磁碟」")
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            HStack {
                Button { state.openTrash() } label: {
                    Label("垃圾桶", systemImage: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.muted)
                Spacer()
                Text(AppVersion.display)
                    .foregroundStyle(Palette.muted.opacity(0.7))
            }
            .font(.system(size: 11))
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    private func navRow(_ tab: NavigationTab) -> some View {
        let isOn = state.activeTab == tab
        let count = badge(for: tab)
        return Button {
            state.activeTab = tab
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(tab.rawValue)
                    .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.display(11, .medium))
                        .monospacedDigit()
                        .foregroundStyle(isOn ? Color.white.opacity(0.85) : Palette.muted)
                }
            }
            .foregroundStyle(isOn ? Color.white : Palette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isOn ? Palette.pineFill : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }

    private func badge(for tab: NavigationTab) -> Int {
        switch tab {
        case .apps: return state.installedApps.count
        case .leftovers: return state.leftoverGroups.count
        case .dragDrop: return 0
        }
    }

    // MARK: Toast

    @ViewBuilder
    private var toast: some View {
        if state.showToast {
            HStack(spacing: 10) {
                Image(systemName: state.toastIsError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(state.toastIsError ? Palette.ochre : Color.white)
                Text(state.toastMessage)
                    .lineLimit(2)
                if !state.toastIsError {
                    Button("打開垃圾桶") { state.openTrash() }
                        .buttonStyle(.plain)
                        .fontWeight(.semibold)
                        .underline()
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(state.toastIsError ? Palette.ink : Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(state.toastIsError ? Palette.surface : Palette.pineFill, in: Capsule())
            .overlay(Capsule().strokeBorder(state.toastIsError ? Palette.hairline : .clear))
            .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
            .padding(.bottom, 76)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
        }
    }
}

/// Pages carry their own headings; drop the duplicate toolbar title where the API exists (macOS 15+).
private struct HideToolbarTitle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbar(removing: .title)
        } else {
            content
        }
    }
}
