import SwiftUI
import AppKit

/// Replaces the stock About panel so it carries the brand.
struct AboutView: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            VStack(spacing: 3) {
                Text("Traceless")
                    .font(.display(24, .bold))
                    .foregroundStyle(Palette.ink)
                Text("無痕移除 Mac App")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
            }
            Text("版本 \(AppVersion.display)")
                .font(.system(size: 12))
                .foregroundStyle(Palette.muted)
            Text("找出 App 留在系統裡的偏好設定、快取與背景項目，全部移到垃圾桶，清空前都能復原。不連網、不收集任何資料。")
                .font(.system(size: 12))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 28)
        .frame(width: 340)
        .background(Palette.surface)
    }
}
