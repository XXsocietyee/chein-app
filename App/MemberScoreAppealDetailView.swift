import SwiftUI

@MainActor struct MemberScoreAppealDetailView: View {
    let selection: MemberScoreAppealSelection
    @ObservedObject var session: AppSession
    @Environment(\.scenePhase) private var scene
    @Environment(\.locale) private var locale
    @State private var flow: MemberScoreAppealReadCoordinator?
    @State private var owner: MemberScoreReadPresentation?
    @State private var visible = false
    var body: some View {
        let rendered = readIntent()
        List {
            if let flow, let row = flow.detailRow {
                Label {
                    Text(verbatim: playerFactOrDash(row.title))
                } icon: {
                    Image(systemName: row.kind == .appeal ? "text.bubble" : "flag")
                }
                memberScoreText("score.kind.\(row.kind.rawValue)")
                    .foregroundStyle(.secondary)
                Text(verbatim: sessionLine(row))
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                if let value = flow.detail {
                    MemberScoreStatusChip(status: value.status)
                    if let note = value.resolutionNote, !note.isEmpty {
                        Text(verbatim: note)
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                    LabeledContent {
                        Text(verbatim: String(value.totalCenti))
                            .font(.title2.bold())
                            .monospacedDigit()
                    } label: {
                        memberScoreText("score.detail.centi")
                    }
                    .accessibilityElement(children: .combine)
                }
                if flow.busy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("score.detail.loading", tableName: "MemberScoreAppealList"))
                }
                if let failure = flow.failure {
                    Label {
                        memberScoreText("score.error.\(failure)")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
                    }
                    .foregroundStyle(.primary)
                }
            } else {
                ContentUnavailableView {
                    Label {
                        Text("score.error.disabled", tableName: "MemberScoreAppealList")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
                .listRowBackground(Color.clear)
            }
            // PLY-30-5: MP appeal-mine openAppeal lands on that round's scoring; the app opens 本局计分 for the session.
            if let row = flow?.detailRow, let topicID = row.topicID, topicID > 0, let topic = Int(exactly: topicID) {
                Section {
                    NavigationLink {
                        OrientScoreDeepLinkScreen(session: session, topicID: topic, sessionID: row.sessionID.flatMap { Int(exactly: $0) })
                    } label: {
                        Label { Text(verbatim: CoreLoopCopy(locale: locale).t("打开本局计分", "Open this round’s score")) }
                            icon: { Image(systemName: "list.number").accessibilityHidden(true) }
                    }
                    .accessibilityIdentifier("score.detail.openOrientScore")
                }
            }
            // R7-MEM-30-2: no developer boundary copy and no 刷新 pill; pull to refresh re-reads.
        }
        .refreshable { load(readIntent()) }
        .listStyle(.insetGrouped)
        .cyGroupedSurface().navigationTitle(Text("score.detail.title", tableName: "MemberScoreAppealList")).navigationBarTitleDisplayMode(.inline).privacySensitive()
        .accessibilityIdentifier("score.mine.detail")
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberScoreReadIdentity) { _, _ in retire() }
        .onChange(of: selection.client.isCurrent) { _, valid in if !valid { retire() } }
        .cyDomainScreen(.player)
    }
    private func sessionLine(_ row: MemberScoreAppealRow) -> String {
        let session = row.sessionID.map { "#\($0)" } ?? "—"
        return "\(session) · #\(row.recordID)"
    }
    private func start() {
        guard visible, scene == .active else { return }; retire()
        guard selection.client.isCurrent else { return }
        let value = selection.client.makeCoordinator(); flow = value; owner = value.beginDetail(selection.row)
        load(readIntent())
    }
    private func readIntent() -> (MemberScoreAppealReadCoordinator, MemberScoreReadIntent)? {
        guard visible, scene == .active, let flow, let owner, let intent = flow.capture(owner) else { return nil }
        return (flow, intent)
    }
    private func load(_ read: (MemberScoreAppealReadCoordinator, MemberScoreReadIntent)?) {
        guard let (original, intent) = read, original.accepts(intent) else { return }
        Task { await original.loadDetail(intent: intent) }
    }
    private func retire() { if let owner { flow?.end(owner) }; flow = nil; owner = nil }
}
