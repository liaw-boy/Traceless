import SwiftUI
import AppKit
import AppSweepCore

public struct PermissionHelpSheet: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 30))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("需要「完全取用磁碟」權限")
                        .font(.title3.weight(.semibold))
                    Text("macOS 會保護沙盒應用程式的容器資料夾（~/Library/Containers）。沒有這個權限，任何清理工具都無法移動它們。")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("1. 按「開啟系統設定」。")
                Text("2. 在「隱私權與安全性 › 完全取用磁碟」中打開 AppSweep。")
                Text("3. 回到 AppSweep 再試一次。")
            }
            .font(.callout)

            if let failed = state.lastResult?.failedItems, !failed.isEmpty {
                GroupBox("這次沒能移除的項目") {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(failed.prefix(5)) { item in
                            HStack {
                                Text(item.path)
                                    .font(.caption.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button("顯示") { state.revealInFinder(url: item.url) }
                                    .buttonStyle(.link)
                                    .font(.caption)
                            }
                        }
                        if failed.count > 5 {
                            Text("以及其他 \(failed.count - 5) 項")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            HStack {
                Spacer()
                Button("稍後") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("開啟系統設定") {
                    PermissionManager.openFullDiskAccessSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
