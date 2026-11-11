import SwiftUI
import AppKit
import AppSweepCore

public struct PermissionHelpSheet: View {
    @ObservedObject var state: AppState

    public var body: some View {
        VStack(spacing: 20) {
            // Header with Shield Icon
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.amber.opacity(0.18))
                        .frame(width: 52, height: 52)

                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 26))
                        .foregroundColor(AppTheme.amber)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("需要「完全取用磁碟」權限")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)

                    Text("macOS 系統防護阻止了沙盒容器的移除操作")
                        .font(.system(size: 12.5))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Reason & Solution Card
            VStack(alignment: .leading, spacing: 10) {
                Text("💡 為什麼 UTM 等沙盒容器需要此權限？")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)

                Text("Apple 從 macOS Catalina 起導入了嚴格的 TCC 隱私安全機制。應用程式的沙盒資料夾（如 `~/Library/Containers/com.utmapp.UTM`）受到系統內核保護，**所有卸載工具（包括 CleanMyMac 與 Pearcleaner）都必須取得此權限才能清理沙盒殘留**。")
                    .font(.system(size: 11.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(3)

                Divider()
                    .opacity(0.4)

                Text("三步快速開啟：")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("1. 點擊下方按鈕開啟「系統設定」。")
                    Text("2. 在「完全取用磁碟」清單中，將「AppSweep」切換為開啟。")
                    Text("3. 返回 AppSweep 重新點擊清理，即可順暢移除！")
                }
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
            }
            .padding(14)
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )

            // Failed items preview if available
            if let lastResult = state.lastResult, !lastResult.failedItems.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本次受限的項目：")
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.secondary)

                    ForEach(lastResult.failedItems.prefix(2)) { item in
                        HStack {
                            Image(systemName: "shippingbox")
                                .font(.system(size: 11))
                                .foregroundColor(AppTheme.amber)
                            Text(item.name)
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Button("在 Finder 中檢視") {
                                state.revealInFinder(url: item.url)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 10.5))
                            .foregroundColor(AppTheme.cyan)
                        }
                        .padding(8)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            Divider()
                .opacity(0.4)

            // Action Buttons
            HStack {
                Button("關閉") {
                    state.showPermissionSheet = false
                }
                .keyboardShortcut(.cancelAction)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .buttonStyle(.plain)

                Spacer()

                Button {
                    PermissionManager.openFullDiskAccessSettings()
                    state.showPermissionSheet = false
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                        Text("前往系統設定授權")
                    }
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(AppTheme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(AppTheme.canvasBg)
    }
}
