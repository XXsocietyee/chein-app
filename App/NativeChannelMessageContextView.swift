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
            if !model.isCurrent {
                stateRow { ContentUnavailableView("d7.channelContext.unavailable", systemImage: "lock") }
            }
            else if let page=model.page {
                if page.older.has_more,let cursor=page.older.next_cursor,let id=NativeChannelMessageID(rawValue:cursor) {
                    Section { Button { open(id) } label: { Label("d7.channelContext.earlier", systemImage: "arrow.up") }
                        .accessibilityLabel(Text("d7.channelContext.earlier")) }
                }
                if !page.older.list.isEmpty {
                    Section { ForEach(page.older.list,id:\.id) { row in line(row) } } header: { Text("d7.channelContext.before") }
                }
                Section { line(page.anchor) } header: { Text("d7.channelContext.anchor") }
                if !page.newer.list.isEmpty {
                    Section { ForEach(page.newer.list,id:\.id) { row in line(row) } } header: { Text("d7.channelContext.after") }
                }
                if page.newer.has_more,let cursor=page.newer.next_after,let id=NativeChannelMessageID(rawValue:cursor) {
                    Section { Button { open(id) } label: { Label("d7.channelContext.later", systemImage: "arrow.down") }
                        .accessibilityLabel(Text("d7.channelContext.later")) }
                }
            } else if model.failed {
                stateRow {
                    ContentUnavailableView {
                        Label("d7.channelContext.failed", systemImage: "exclamationmark.bubble")
                    } actions: {
                        Button("messaging.retry") { open() }
                            .buttonStyle(.bordered)
                            .disabled(model.loading || phase != .active)
                    }
                }
            }
            if model.loading { stateRow { loading } }
        }
        .navigationTitle(Text("d7.channelContext.title"))
        .navigationBarTitleDisplayMode(.inline)
        .nativeChannelScreen()
        .privacySensitive()
        .refreshable { open(); await readTask?.value }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("action.done") { dismiss() } } }
        // The enclosing sheet continues its current-source reads while a preview is pushed.
        // Only this view's explicit read task ends here; sheet departure retires the model.
        .onDisappear{readTask?.cancel();readTask=nil}
        .onChange(of:phase){_,value in if value != .active {readTask?.cancel();readTask=nil}}
    }
    private var loading: some View {
        ProgressView { Text("cy.state.loading") }
            .frame(maxWidth: .infinity)
    }
    private func stateRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
    }
    private func open(_ id:NativeChannelMessageID?=nil) {
        guard phase == .active,model.isCurrent else{return}
        readTask?.cancel()
        readTask=Task{await model.open(id)}
    }
    @ViewBuilder private func line(_ row:NativeChannelMessageSnapshot)->some View {
        HStack(alignment: .top, spacing: 12) {
            CYCoverArt(seed: row.message.senderName ?? row.id.rawValue, symbol: "person.fill", showsDebugLabel: false)
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: sender(row.message.senderName))
                    .font(.headline)
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
