import SwiftUI
import AppKit
import AppSweepCore

public struct MainView: View {
    @StateObject private var state = AppState()

    public var body: some View {
        NavigationSplitView {
            sidebarContent
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            ZStack {
                switch state.activeTab {
                case .apps:
                    HSplitView {
                        AppListView(state: state)
                            .frame(minWidth: 360, idealWidth: 400, maxWidth: 500)

                        AppDetailView(state: state)
                            .frame(minWidth: 520)
                    }
                case .dragDrop:
                    DragDropView(state: state)
                case .leftovers:
                    LeftoverView(state: state)
                }

                // Toast Notification Overlay
                if state.showToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(AppTheme.emerald)
                            Text(state.toastMessage)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Button("開啟垃圾桶") {
                                state.openTrash()
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(AppTheme.cyan)
                            .padding(.leading, 4)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.15, green: 0.17, blue: 0.24).opacity(0.95))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppTheme.cardBorder, lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 5)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 24)
                    }
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.showToast)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if state.activeTab == .apps {
                    Button {
                        Task {
                            await state.loadApps()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("重新整理")
                        }
                        .font(.system(size: 12))
                    }
                    .help("重新掃描已安裝應用程式與磁碟佔用 (Cmd + R)")
                    .keyboardShortcut("r", modifiers: .command)
                }
            }
        }
        .sheet(isPresented: $state.showConfirmSheet) {
            ConfirmDeleteSheet(state: state)
        }
        .sheet(isPresented: $state.showResetConfirmSheet) {
            ResetConfirmSheet(state: state)
        }
        .sheet(isPresented: $state.showPermissionSheet) {
            PermissionHelpSheet(state: state)
        }
        .task {
            await state.loadApps()
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Window Traffic Lights Margin (for borderless window)
            Color.clear
                .frame(height: 26)

            // App Branding Header
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AppSweep")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("應用程式深度清理工具")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.sidebarBg)

            Divider()
                .opacity(0.4)

            // Custom Navigation List
            VStack(spacing: 4) {
                ForEach(NavigationTab.allCases) { tab in
                    let isSelected = state.activeTab == tab

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            state.activeTab = tab
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? AppTheme.cyan : .secondary)
                                .frame(width: 20)

                            Text(tab.rawValue)
                                .font(.system(size: 12.5, weight: isSelected ? .bold : .medium))
                                .foregroundColor(isSelected ? .white : .secondary)

                            Spacer()

                            if tab == .apps && !state.installedApps.isEmpty {
                                Text("\(state.installedApps.count)")
                                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(isSelected ? .white : .secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(isSelected ? 0.2 : 0.06))
                                    .clipShape(Capsule())
                            } else if tab == .leftovers && !state.leftoverGroups.isEmpty {
                                Text("\(state.leftoverGroups.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.amber)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            ZStack(alignment: .leading) {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppTheme.accent.opacity(0.18))
                                    Rectangle()
                                        .fill(AppTheme.cyan)
                                        .frame(width: 3)
                                        .clipShape(RoundedRectangle(cornerRadius: 1.5))
                                }
                            }
                        )
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)

            Spacer()

            // Permission Warning Card in Sidebar Footer (if Full Disk Access not granted)
            if !state.hasFullDiskAccess {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.amber)
                            .font(.system(size: 11))
                        Text("權限受限")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            state.showPermissionSheet = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("了解權限說明")
                    }

                    Text("清理 UTM 等沙盒容器需授予「完全取用磁碟」權限。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineSpacing(2)

                    Button {
                        PermissionManager.openFullDiskAccessSettings()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.open")
                            Text("前往系統設定授權")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(AppTheme.cyan)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4.5)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(AppTheme.amber.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.amber.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }

            Divider()
                .opacity(0.4)

            // Bottom Utilities
            HStack {
                Button {
                    state.openTrash()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("開啟系統垃圾桶")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(6)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(10)
        }
        .background(AppTheme.sidebarBg)
    }
}
