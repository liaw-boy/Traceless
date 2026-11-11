import SwiftUI
import AppKit
import AppSweepCore

public struct ConfirmDeleteSheet: View {
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 20) {
            if let app = state.selectedApp {
                // Header
                HStack(spacing: 16) {
                    Image(nsImage: app.icon(size: 128))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 54, height: 54)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("確認移除 \(app.name)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("即將把 \(state.selectedResiduals.count) 個項目移至系統垃圾桶")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Space freed stat
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("預計釋放磁碟空間")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(state.formattedTotalSelectedSize)
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.accent)
                    }
                    Spacer()
                }
                .padding(14)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )

                // Running App Warning
                if app.isRunning {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.amber)
                            .font(.system(size: 16))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("應用程式正在執行中")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                            Text("點選確認後，系統將先安全終止該程序再清理其資料。")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.amber.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppTheme.amber.opacity(0.3), lineWidth: 1)
                    )
                }

                // Trash explanation
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text("所有檔案將移至 macOS「垃圾桶」，並非永久刪除，可隨時復原。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Divider()
                    .opacity(0.4)

                // Action Buttons
                HStack {
                    Button("取消") {
                        state.showConfirmSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        Task {
                            await state.executeUninstall()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("確認移至垃圾桶")
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(AppTheme.dangerGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(AppTheme.canvasBg)
    }
}

public struct ResetConfirmSheet: View {
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 20) {
            if let app = state.selectedApp {
                HStack(spacing: 16) {
                    Image(nsImage: app.icon(size: 128))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 54, height: 54)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("重置 \(app.name)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text("保留主應用程式，清除所有快取、偏好設定與暫存")
                            .font(.system(size: 12.5))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("重置後：")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Text("• 應用程式本體（\(app.name).app）將被完整保留。\n• 偏好設定、暫存快取、登入資訊等將被清除至初始狀態。\n• 下次開啟時該應用程式將如同全新安裝。")
                        .font(.system(size: 11.5))
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.cardBg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )

                Divider()
                    .opacity(0.4)

                HStack {
                    Button("取消") {
                        state.showResetConfirmSheet = false
                    }
                    .keyboardShortcut(.cancelAction)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        Task {
                            await state.executeResetApp()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("確認重置")
                        }
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(AppTheme.resetGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(24)
        .frame(width: 450)
        .background(AppTheme.canvasBg)
    }
}
