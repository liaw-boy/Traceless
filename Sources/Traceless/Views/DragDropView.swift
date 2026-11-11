import SwiftUI
import UniformTypeIdentifiers
import AppKit
import TracelessCore

public struct DragDropView: View {
    @ObservedObject var state: AppState
    @State private var isTargeted = false

    public var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(isTargeted ? Color.accentColor : .secondary)

            Text("把應用程式拖到這裡")
                .font(.title2.weight(.semibold))

            Text("Traceless 會找出它的偏好設定、快取、容器與背景項目，讓你一次移除乾淨。")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button("選擇應用程式…", action: openFilePicker)
                .controlSize(.large)
                .padding(.top, 4)
        }
        .padding(40)
        .frame(maxWidth: 520, maxHeight: 340)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isTargeted ? Color.accentColor : Color.secondary.opacity(0.35),
                              style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .background(isTargeted ? Color.accentColor.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 14))
                .frame(maxWidth: 520, maxHeight: 340)
        }
        .padding(32)
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
