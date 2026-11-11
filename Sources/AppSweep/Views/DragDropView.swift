import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AppSweepCore

public struct DragDropView: View {
    @ObservedObject var state: AppState
    @State private var isTargeted: Bool = false

    public var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 20) {
                // Drop Icon
                ZStack {
                    Circle()
                        .fill(isTargeted ? AppTheme.accent.opacity(0.2) : Color.white.opacity(0.04))
                        .frame(width: 120, height: 120)

                    Image(systemName: isTargeted ? "arrow.down.app.fill" : "arrow.down.doc")
                        .font(.system(size: 52))
                        .foregroundColor(isTargeted ? AppTheme.cyan : AppTheme.accent)
                }

                VStack(spacing: 8) {
                    Text("拖曳任何 .app 應用程式至此處")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("AppSweep 將立即全面深度掃描其偏好設定、快取、容器與關聯殘留項目")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 420)
                }

                // Or choose via file dialog
                Button {
                    openFilePicker()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("手動瀏覽選取 .app 檔案...")
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.buttonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: AppTheme.accent.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 540, minHeight: 320)
            .padding(36)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        isTargeted ? AppTheme.cyan : AppTheme.cardBorder,
                        style: StrokeStyle(lineWidth: 2, dash: [8])
                    )
                    .background(isTargeted ? AppTheme.accent.opacity(0.06) : AppTheme.cardBg.opacity(0.4))
            )
            .onDrop(of: [.fileURL, .application], isTargeted: $isTargeted) { providers in
                handleDrop(providers: providers)
            }

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.canvasBg)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }

        // 1. Try loading URL directly
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, url.pathExtension == "app" {
                    Task { @MainActor in
                        await state.loadAppFromURL(url)
                    }
                }
            }
            return true
        }

        // 2. Fallback for fileURL type identifier
        let fileType = UTType.fileURL.identifier
        if provider.hasItemConformingToTypeIdentifier(fileType) {
            provider.loadItem(forTypeIdentifier: fileType, options: nil) { item, _ in
                var targetURL: URL?
                if let url = item as? URL {
                    targetURL = url
                } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    targetURL = url
                } else if let str = item as? String, let url = URL(string: str) {
                    targetURL = url
                }

                if let targetURL = targetURL, targetURL.pathExtension == "app" {
                    Task { @MainActor in
                        await state.loadAppFromURL(targetURL)
                    }
                }
            }
            return true
        }

        return false
    }

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        if panel.runModal() == .OK, let selectedURL = panel.url {
            Task {
                await state.loadAppFromURL(selectedURL)
            }
        }
    }
}
