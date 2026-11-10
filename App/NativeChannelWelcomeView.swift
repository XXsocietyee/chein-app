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
                    Section {
                        CYHeroHeader("d7.channelWelcome.title")
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    CYEmptyState(systemImage: "signpost.right", "d7.channelWelcome.unavailable")
                }
                .listStyle(.insetGrouped)
                .contentMargins(.horizontal, CYSpacing.pageHorizontal, for: .scrollContent)
                .cyGroupedSurface()
                .cyHeroScreen()
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
            Section { hero.listRowBackground(Color.clear).listRowInsets(EdgeInsets()) }
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
                                    .buttonStyle(.cyPressable)
                                    .disabled(flow.busy)
                                    .accessibilityLabel(Text(verbatim: item.label))
                            }
                        } header: {
                            CYSectionHeader("d7.channelWelcome.getStarted")
                                .textCase(nil)
                        }
                    }
                    Section {
                        CYPillButton("d7.channelWelcome.enter") { select(value.entryChannelID) }
                            .disabled(flow.busy)
                            .accessibilityLabel(Text("d7.channelWelcome.enter"))
                    }
                }
            } else {
                CYEmptyState(systemImage: "lock.shield", "d7.channelWelcome.expired")
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.horizontal, CYSpacing.pageHorizontal, for: .scrollContent)
        .listSectionSpacing(CYSpacing.xxl)
        .refreshable { await flow.refresh() }
        .nativeChannelFlowPage()
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .task { await flow.activate() }
        .onDisappear { flow.deactivate() }
        .cyAnimation(value: flow.snapshot?.version)
    }

    @ViewBuilder private var hero: some View {
        let snapshot = flow.isCurrent ? flow.snapshot : nil
        let trimmed = snapshot?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let detail = snapshot?.description.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            CYHeroHeader("d7.channelWelcome.title")
            if !detail.isEmpty {
                Text(verbatim: detail)
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            CYHeroHeader(verbatim: trimmed, subtitle: detail.isEmpty ? nil : detail) {
                NativeChannelCoverBanner(seed: trimmed, symbol: "signpost.right")
            }
        }
    }

    private func signpostRow(_ item: NativeChannelWelcomeSnapshot.Signpost) -> some View {
        CYListRow(verbatim: item.label, trailing: .chevron) {
            Text(verbatim: item.emoji)
                .font(CYTypography.sectionTitle)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
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
        CYSkeleton()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.state.loading"))
            .listRowBackground(Color.clear)
    }
}
