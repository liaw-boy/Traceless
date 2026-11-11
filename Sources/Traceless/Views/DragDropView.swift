import SwiftUI
import UniformTypeIdentifiers
import AppKit
import TracelessCore

public struct DragDropView: View {
    @ObservedObject var state: AppState
    @State private var isTargeted = false

    public var body: some View {
        VStack(spacing: 22) {
            // The mark dissolves at rest and becomes a whole tile while an app is held over it.
            TraceMark(size: 96, color: isTargeted ? Palette.pine : Palette.muted.opacity(0.5), dissolving: !isTargeted)

            VStack(spacing: 6) {
                Text(isTargeted ? "放開以分析" : "把 App 拖到這裡")
                    .font(.display(24))
                    .foregroundStyle(Palette.ink)
                Text("Traceless 會找出它的偏好設定、快取、容器與背景項目，讓你一次清乾淨。")
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button("選擇 App…", action: openFilePicker)
                .buttonStyle(SolidButtonStyle())
        }
        .padding(48)
        .frame(maxWidth: 560, maxHeight: 400)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isTargeted ? Palette.pineWash : Palette.surface)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isTargeted ? Palette.pine : Palette.hairline,
                              style: StrokeStyle(lineWidth: 1.5, dash: isTargeted ? [] : [7, 5]))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
        .background(Palette.canvas)
        .animation(.easeOut(duration: 0.2), value: isTargeted)
        .contentShape(Rectangle())
        .onDrop(of: [.fileURL], isTargeted: $isTargeted, perform: handleDrop)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            Task { @MainActor in
                guard let url, url.pathExtension == "app" else {
                    state.reportNotAnApp()
                    return
                }
                await state.loadAppFromURL(url)
            }
        }
        return true
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url {
            Task { await state.loadAppFromURL(url) }
        }
    }
}
