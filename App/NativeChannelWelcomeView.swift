import SwiftUI

/// No member-side editor; destinations reopen the original channel host and its current authority.
@MainActor struct NativeChannelWelcomeEntry: View {
    @ObservedObject var session: AppSession
    let channels: NativeChannelManagementCoordinator
    var parentRouteIsActive: () -> Bool = { false }
    @State private var flow: NativeChannelWelcomeFlow?
    @StateObject private var selection = NativeChannelManagementSelectionState<NativeChannelManagementID>()
    @Environment(\.scenePhase) private var scene
    var body: some View {
        Group {
            if let flow {
                NativeChannelWelcomeView(flow: flow, selectChannel: { if parentRouteIsActive() { selection.selected = $0 } })
            } else {
                List {
                    ContentUnavailableView("d7.channelWelcome.unavailable", systemImage: "signpost.right")
                }
                .navigationTitle(Text("d7.channelWelcome.title"))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task { reopen() }
        .onDisappear { close() }
        .onChange(of: scene) { _, value in if value == .active { reopen() } else { close() } }
        .onChange(of: channels.isCurrent) { _, current in if !current { close() } }
        .onChange(of: parentRouteIsActive()) { _, current in if !current { selection.selected = nil; close() } }
        .navigationDestination(item: selection.binding) { id in
            let visit = selection.route(for: id, parentCurrent: parentRouteIsActive)
            NativeChannelMessageHostDestination(session: session, channels: channels.service, channelID: id, routeIsPresented: visit)
                .id(selection.visitID)
        }
    }
    private func close() { flow?.deactivate(); flow = nil }
    private func reopen() {
        close()
        let parent = parentRouteIsActive, owner = channels
        guard scene == .active, parent(), owner.isCurrent else { return }
        flow = session.makeNativeChannelWelcome(scope: owner.scope, sourceCurrent: { [weak owner] in parent() && owner?.isCurrent == true })
    }
}

@MainActor struct NativeChannelWelcomeView: View {
    let flow: NativeChannelWelcomeFlow
    let selectChannel: (NativeChannelManagementID) -> Void
    var body: some View {
        List {
            hero
            if flow.isCurrent {
                if let issue = flow.issue {
                    NativeChannelFlowNotice(title: Text(verbatim: issue), symbol: "exclamationmark.circle")
                        .accessibilityLabel(Text(verbatim: issue))
                }
                if flow.busy { NativeChannelWelcomeLoading() }
                if let value = flow.snapshot {
                    if !value.signposts.isEmpty {
                        Section {
                            ForEach(value.signposts) { item in
                                Button { select(item.id) } label: { signpostRow(item) }
                                    .disabled(flow.busy)
                                    .accessibilityLabel(Text(verbatim: item.label))
                            }
                        } header: {
                            Text("d7.channelWelcome.getStarted")
                        }
                    }
                    Section {
                        Button { select(value.entryChannelID) } label: { Text("d7.channelWelcome.enter") }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelWelcome.enter"))
                    }
                }
            } else {
                ContentUnavailableView("d7.channelWelcome.expired", systemImage: "lock.shield")
            }
        }
        .refreshable { await flow.refresh() }
        .navigationTitle(titleText)
        .nativeChannelFlowPage()
        .privacySensitive()
        .task { await flow.activate() }
        .onDisappear { flow.deactivate() }
        .cyAnimation(value: flow.snapshot?.version)
    }

    private var trimmedTitle: String {
        (flow.isCurrent ? flow.snapshot : nil)?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    /// The channel's welcome title is the navigation title; the generic title stands in while it is unknown.
    private var titleText: Text {
        trimmedTitle.isEmpty ? Text("d7.channelWelcome.title") : Text(verbatim: trimmedTitle)
    }

    /// One optional header image (the generated cover) and the description, in the first section.
    @ViewBuilder private var hero: some View {
        let snapshot = flow.isCurrent ? flow.snapshot : nil
        let trimmed = trimmedTitle
        let detail = snapshot?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmed.isEmpty || !detail.isEmpty {
            Section {
                if !trimmed.isEmpty {
                    NativeChannelCoverBanner(seed: trimmed, symbol: "signpost.right")
                        .listRowInsets(EdgeInsets())
                }
                if !detail.isEmpty {
                    Text(verbatim: detail)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func signpostRow(_ item: NativeChannelWelcomeSnapshot.Signpost) -> some View {
        HStack {
            Label {
                Text(verbatim: item.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : item.label)
                    .foregroundStyle(.primary)
            } icon: {
                Text(verbatim: item.emoji)
                    .accessibilityHidden(true)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
    }

    private func select(_ id: NativeChannelManagementID) {
        guard flow.permits(id) else { return }
        selectChannel(id)
    }
}

private struct NativeChannelWelcomeLoading: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.state.loading"))
    }
}
