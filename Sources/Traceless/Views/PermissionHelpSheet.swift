import SwiftUI
import AppKit
import TracelessCore

public struct PermissionHelpSheet: View {
    @ObservedObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                TraceMark(size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("授權「完全取用磁碟」")
                        .font(.display(19))
                        .foregroundStyle(Palette.ink)
                    Text("macOS 會保護沙盒應用程式的容器資料夾（~/Library/Containers）。沒有這個權限，任何清理工具都無法移動它們。")
                        .foregroundStyle(Palette.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("1. 先把 Traceless 拖進「應用程式」資料夾（權限綁定在 App 所在位置）。")
                Text("2. 按「開啟系統設定」，在「隱私權與安全性 › 完全取用磁碟」按 + 加入 Traceless，並打開開關。")
                Text("3. 回到 Traceless，會自動重新檢查，不需要重新啟動。")
                Text("Traceless 只會把檔案移到垃圾桶，不會讀取或上傳你的資料；整個程式不連網。")
                    .foregroundStyle(Palette.muted)
                    .padding(.top, 2)
            }
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)

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
                    .buttonStyle(QuietButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button("開啟系統設定") {
                    PermissionManager.openFullDiskAccessSettings()
                    dismiss()
                }
                .buttonStyle(SolidButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 480)
        .background(Palette.surface)
    }
}
