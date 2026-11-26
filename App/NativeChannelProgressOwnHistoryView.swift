import SwiftUI

@MainActor struct NativeChannelProgressOwnHistoryView: View {
    @Bindable var model: NativeChannelProgressCoordinator
    @StateObject private var actions = NativeChannelProgressActionLifetime()
    var body: some View {
        List {
            if !model.isCurrent {
                Text(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.closed"))
                    .nativeChannelNotice(systemImage: "lock")
                    .accessibilityLabel(Text("d7.channelProgress.closed", tableName: "NativeChannelProgress"))
            }
            if model.busy { NativeChannelProgressHistoryLoading() }
            Section {
                if let best = model.best { NativeChannelProgressMeCard(row: best) }
                else if !model.busy && model.issue("best") == nil {
                    Text(verbatim: "—")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel(Text(verbatim: "—"))
                }
                NativeChannelProgressIssueView(model: model, part: "best")
            } header: { NativeChannelSectionTitle(key: "best") }
            Section {
                if let page = model.recent.page {
                    if !page.visible {
                        ContentUnavailableView {
                            Label { Text("d7.channelProgress.hidden", tableName: "NativeChannelProgress") } icon: { Image(systemName: "eye.slash") }
                        }
                    } else {
                        if model.recent.rows.isEmpty {
                            ContentUnavailableView {
                                Label { Text("d7.channelProgress.emptyHistory", tableName: "NativeChannelProgress") } icon: { Image(systemName: "clock") }
                            }
                        }
                        ForEach(Array(model.recent.rows.enumerated()), id: \.offset) { _, row in NativeChannelProgressRowView(row: row) }
                        if page.nextCursor != nil {
                            Button {
                                actions.run { await model.loadMore(history: true) }
                            } label: {
                                Text("more", tableName: "NativeChannelProgress")
                            }
                            .disabled(model.busy)
                            .accessibilityLabel(Text("more", tableName: "NativeChannelProgress"))
                        }
                    }
                }
                NativeChannelProgressIssueView(model: model, part: "recent")
            } header: { NativeChannelSectionTitle(key: "d7.channelProgress.recent") }
        }
        .nativeChannelScreen()
        .navigationTitle(Text("d7.channelProgress.historyTitle", tableName: "NativeChannelProgress"))
        .privacySensitive()
        .onAppear { actions.activate() }
        .onDisappear { actions.retire() }
        .onChange(of: model.isCurrent) { _, current in if !current { actions.retire() } }
        .task { await model.refreshOwnHistory() }
        .refreshable { await model.refreshOwnHistory() }
        .accessibilityIdentifier("channelProgress.ownHistory")
    }
}

private struct NativeChannelProgressHistoryLoading: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.state.loading"))
    }
}
