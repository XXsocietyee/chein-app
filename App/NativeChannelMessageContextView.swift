import SwiftUI

struct NativeChannelContextSelection: Identifiable {let id:NativeChannelMessageID}

/// The sheet owns the current original source across child preview navigation.
/// A pushed media screen is not departure from this sheet's account/channel scope.
@MainActor struct NativeChannelMessageContextEntry: View {
    @State var model:NativeChannelMessageContext
    var expanded:((NativeChannelMessageContext)->IMExpandedNavigationContext?)?
    @Environment(\.scenePhase) private var phase
    var body:some View {
        NavigationStack {
            NativeChannelMessageContextView(model:model,expanded:expanded?(model))
        }
        .presentationDragIndicator(.visible)
        .task(id:phase) {
            guard phase == .active else {model.retire();return}
            await model.open()
            while !Task.isCancelled {
                do{try await Task.sleep(nanoseconds:8_000_000_000)}catch{return}
                guard model.isCurrent else {model.retire();return}
                if !model.loading {await model.refresh()}
            }
        }
        .onDisappear{model.retire()}
        .onChange(of:model.isCurrent){_,value in if !value{model.retire()}}
        .privacySensitive()
    }
}

@MainActor struct NativeChannelMessageContextView: View {
    @Bindable var model:NativeChannelMessageContext
    var expanded:IMExpandedNavigationContext?
    @State private var readTask:Task<Void,Never>?
    @Environment(\.scenePhase) private var phase
    @Environment(\.dismiss) private var dismiss
    var body:some View {
        List {
            Section {
                CYHeroHeader("d7.channelContext.title")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if !model.isCurrent {
                stateRow { CYEmptyState(systemImage: "lock", "d7.channelContext.unavailable") }
            }
            else if let page=model.page {
                if page.older.has_more,let cursor=page.older.next_cursor,let id=NativeChannelMessageID(rawValue:cursor) {
                    Section { CYPillButton("d7.channelContext.earlier", style: .tertiary, fullWidth: false) { open(id) }
                        .accessibilityLabel(Text("d7.channelContext.earlier"))
                        .listRowBackground(Color.clear) }
                }
                if !page.older.list.isEmpty {
                    Section { ForEach(page.older.list,id:\.id) { row in line(row) } } header: { CYSectionHeader("d7.channelContext.before").textCase(nil) }
                }
                Section { line(page.anchor) } header: { CYSectionHeader("d7.channelContext.anchor").textCase(nil) }
                if !page.newer.list.isEmpty {
                    Section { ForEach(page.newer.list,id:\.id) { row in line(row) } } header: { CYSectionHeader("d7.channelContext.after").textCase(nil) }
                }
                if page.newer.has_more,let cursor=page.newer.next_after,let id=NativeChannelMessageID(rawValue:cursor) {
                    Section { CYPillButton("d7.channelContext.later", style: .tertiary, fullWidth: false) { open(id) }
                        .accessibilityLabel(Text("d7.channelContext.later"))
                        .listRowBackground(Color.clear) }
                }
            } else if model.failed {
                stateRow {
                    CYEmptyState(systemImage: "exclamationmark.bubble", "d7.channelContext.failed",
                        actionTitle: "messaging.retry", actionStyle: .secondary) { open() }
                        .disabled(model.loading || phase != .active)
                }
            }
            if model.loading { stateRow { loading } }
        }
        .nativeChannelScreen()
        .listStyle(.insetGrouped)
        .cyHeroScreen()
        .privacySensitive()
        .refreshable { open(); await readTask?.value }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.done") { dismiss() } } }
        // The enclosing sheet continues its current-source reads while a preview is pushed.
        // Only this view's explicit read task ends here; sheet departure retires the model.
        .onDisappear{readTask?.cancel();readTask=nil}
        .onChange(of:phase){_,value in if value != .active {readTask?.cancel();readTask=nil}}
    }
    private var loading: some View {
        CYSkeleton()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.state.loading"))
    }
    private func stateRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    private func open(_ id:NativeChannelMessageID?=nil) {
        guard phase == .active,model.isCurrent else{return}
        readTask?.cancel()
        readTask=Task{await model.open(id)}
    }
    @ViewBuilder private func line(_ row:NativeChannelMessageSnapshot)->some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            CYCoverArt(seed: row.message.senderName ?? row.id.rawValue, symbol: "person.fill", showsDebugLabel: false)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: sender(row.message.senderName))
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(Text(verbatim: sender(row.message.senderName)))
                NativeChannelMessageBubbleView(snapshot:row,isCurrent:{model.containsCurrent(row)},
                    locateOriginal:{open($0)},
                    videoOwner:expanded?.videoCoordinator?(row.message.conversationID),
                    fileOwner:expanded?.fileCoordinator?(row.message.conversationID),
                    voiceOwner:expanded?.voiceCoordinator?(row.message.conversationID),
                    attachmentPreview:expanded?.attachmentPreview?(row.message),pollCoordinator:expanded?.pollCoordinator)
            }
        }
        .accessibilityElement(children: .contain)
    }
    /// A missing sender is unknown. A real name, including "0", stays as written.
    private func sender(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "—" : trimmed
    }
}
