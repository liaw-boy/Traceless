import SwiftUI
import AppKit
import TracelessCore

public struct LeftoverView: View {
    @ObservedObject var state: AppState
    @State private var collapsed: Set<String> = []

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("篩選", selection: $state.leftoverFilterMode) {
                    ForEach(LeftoverFilterMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()

                Spacer()

                Menu {
                    Picker("排序方式", selection: $state.leftoverSortOption) {
                        ForEach(LeftoverSortOption.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("排序：\(state.leftoverSortOption.rawValue)")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            Divider()

            if state.isLoadingLeftovers {
                ProgressView("正在比對已移除應用程式留下的檔案…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if state.filteredLeftoverGroups.isEmpty {
                ContentUnavailableView {
                    Label(state.leftoverGroups.isEmpty ? "沒有找到殘留檔案" : "沒有符合的項目", systemImage: "checkmark.circle")
                } description: {
                    Text("仍安裝中或正在執行的應用程式資料不會出現在這裡。")
                } actions: {
                    Button("重新掃描") { Task { await state.scanLeftovers() } }
                }
            } else {
                List {
                    Text("以下資料夾找不到對應的已安裝應用程式。預設不勾選，請確認後再清理。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .listRowSeparator(.hidden)
                    ForEach(state.filteredLeftoverGroups) { group in
                        groupSection(group)
                    }
                }
                .listStyle(.inset)
            }

            Divider()
            footer
        }
        .confirmationDialog(
            "要將 \(state.totalSelectedLeftoverCount) 個殘留項目移至垃圾桶嗎？",
            isPresented: $state.showLeftoverConfirm,
            titleVisibility: .visible
        ) {
            Button("移至垃圾桶", role: .destructive) {
                Task { await state.executeAllSelectedLeftoversUninstall() }
            }
        } message: {
            Text("將釋放 \(state.formattedTotalSelectedLeftoverSize)。清空垃圾桶前都能復原。")
        }
        .task {
            if state.leftoverGroups.isEmpty {
                await state.scanLeftovers()
            }
        }
    }

    private func groupSection(_ group: LeftoverAppGroup) -> some View {
        let selected = group.items.filter(\.isSelected).count
        let checkState: Bool? = selected == 0 ? false : (selected == group.items.count ? true : nil)
        let isExpanded = !collapsed.contains(group.id)

        return Section {
            if isExpanded {
                ForEach(group.items) { item in
                    ResidualItemRow(
                        item: item,
                        onToggle: { state.toggleLeftoverItem(groupId: group.id, itemId: item.id) },
                        onReveal: { state.revealInFinder(url: item.url) }
                    )
                }
            }
        } header: {
            HStack(spacing: 8) {
                Button {
                    if isExpanded { collapsed.insert(group.id) } else { collapsed.remove(group.id) }
                } label: {
                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .frame(width: 12)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isExpanded ? "收合" : "展開")

                Toggle(isOn: Binding(get: { checkState ?? false },
                                     set: { _ in state.toggleLeftoverGroupSelection(groupId: group.id, select: checkState != true) })) {
                    Text(group.name).fontWeight(.semibold)
                }
                .toggleStyle(.checkbox)
                .modifier(MixedState(isMixed: checkState == nil))

                if group.id != group.name {
                    Text(group.id)
                        .font(.caption.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text("\(group.items.count) 項 · \(group.formattedTotalSize)")
                    .monospacedDigit()
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Button("全選") { state.selectAllLeftovers(true) }
                .disabled(state.filteredLeftoverGroups.isEmpty)
            Button("全不選") { state.selectAllLeftovers(false) }
                .disabled(state.totalSelectedLeftoverCount == 0)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text("已選 \(state.totalSelectedLeftoverCount) 項")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(state.formattedTotalSelectedLeftoverSize)
                    .font(.headline)
                    .monospacedDigit()
            }

            Button(role: .destructive) {
                state.showLeftoverConfirm = true
            } label: {
                if state.isUninstalling {
                    ProgressView().controlSize(.small)
                } else {
                    Text("移至垃圾桶…")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
            .disabled(state.totalSelectedLeftoverCount == 0 || state.isUninstalling)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
