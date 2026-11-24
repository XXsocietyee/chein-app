import SwiftUI

func memberReportProgressText(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "MemberReportProgress") }
struct MemberReportProgressTimeView: View {
    let value: MemberReportProgressTime?
    var body: some View {
        if let text = value?.display() { Text(verbatim: text) }
        else { memberReportProgressText("report.time.unknown") }
    }
}
@MainActor struct SquareReportProgressView: View {
    @ObservedObject var session: AppSession
    @Environment(\.scenePhase) private var scene
    @State private var flow: MemberReportProgressCoordinator?
    @State private var owner: MemberReportProgressPresentation?
    @State private var visible = false
    @State private var selection: MemberReportProgressSelection?
    @State private var showsSignIn = false
    var body: some View {
        let rendered = readIntent()
        List {
            // PLY-28-1/2: inline bar title; no developer boundary line and no 刷新 pill next to pull-to-refresh.
            if let flow, flow.isCurrent {
                Picker(selection: Binding(get: { flow.filter }, set: { value in
                    guard let (original, intent) = rendered else { return }; original.changeFilter(value, intent: intent)
                })) {
                    ForEach(MemberReportProgressFilter.allCases) { memberReportProgressText("report.filter.\($0.rawValue)").tag($0) }
                } label: { memberReportProgressText("report.filter.title") }.pickerStyle(.segmented).disabled(flow.busy)
                ForEach(flow.records) { record in
                    Button {
                        guard let (original, intent) = rendered, let selected = original.select(record, intent: intent) else { return }
                        selection = selected
                    } label: {
                        // Source report-mine row: 「对象 · 原因」 over 「编号 N · 时间」, stage and chevron on the right.
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            memberReportProgressText("report.stage.\(record.stageKey)")
                                .cyText(.micro)
                                .foregroundStyle(CYColor.textSecondary)
                                .padding(.horizontal, CYSpacing.sm)
                                .frame(minHeight: 20)
                                .background(Capsule(style: .continuous).fill(CYColor.bgSurfaceSubtle))
                            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                                memberReportProgressText("report.target.\(record.targetKey)")
                                Text(verbatim: "·").accessibilityHidden(true)
                                if let label = flow.reasonLabel(for: record) { Text(verbatim: label) }
                                else { memberReportProgressText("report.reason.fallback") }
                            }
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            MemberReportProgressTimeView(value: record.createTime)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                            // PLY-28-3: mini-program ETA line 「预计 … 前给出结论」 while the report is still open.
                            if !["RESOLVED", "CLOSED"].contains(record.stageKey), let eta = record.estimatedResolveAt?.display() {
                                Text("report.eta \(eta)", tableName: "MemberReportProgress")
                                    .cyText(.meta)
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                            Text("u9cde.report.number \(String(record.id))")
                                .cyText(.meta)
                                .monospacedDigit()
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }.disabled(flow.busy || !flow.reader.allows(.detail))
                    .accessibilityIdentifier("report.progress.row.\(record.id)")
                }
                if flow.loaded && flow.records.isEmpty {
                    // PLY-28-3: one empty line per filter, as the mini-program.
                    CYEmptyState(systemImage: "doc.text.magnifyingglass", LocalizedStringKey("report.history.empty." + flow.filter.rawValue), tableName: "MemberReportProgress")
                }
                if flow.hasMore {
                    Button {
                        guard let (original, intent) = rendered else { return }; original.showMore(intent: intent)
                    } label: { memberReportProgressText("report.history.more") }.disabled(flow.busy)
                }
                if flow.loaded && !flow.records.isEmpty && !flow.hasMore && !flow.busy {
                    // Source list footer: 已经到底了.
                    Text("u9cde.report.end").cyText(.bodyCompact).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        .accessibilityIdentifier("report.progress.end")
                }
                if flow.busy { CYSkeleton() }
                if let failure = flow.failure {
                    let message = LocalizedStringKey("report.error." + String(describing: failure))
                    CYEmptyState(systemImage: "exclamationmark.triangle", message, tableName: "MemberReportProgress", messageIdentifier: "report.progress.error", actionTitle: "report.retry", action: { load(rendered) })
                }
            } else if session.account == nil {
                // PLY-28-4: signed out → mini-program login gate with a way to sign in.
                CYEmptyState(systemImage: "person.crop.circle", "report.signIn.title", tableName: "MemberReportProgress",
                             messageIdentifier: "report.progress.signIn", actionTitle: "report.signIn.action",
                             actionIdentifier: "report.progress.signIn.action", actionStyle: .primary) { showsSignIn = true }
            } else { memberReportProgressText("report.error.disabled") }
        }
        .cyGroupedSurface()
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberReportProgressText("report.history.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .sheet(isPresented: $showsSignIn, onDismiss: { retire(); start() }) { Group { LoginView(intent: .player).environmentObject(session) }.cySheet(detents: [.large]) }
        .accessibilityIdentifier("report.progress.history")
        .navigationDestination(item: $selection) { MemberReportProgressDetailView(selection: $0, session: session) }
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberReportProgressIdentity) { _, _ in selection = nil; retire(); start() }
        .refreshable { guard let (original, intent) = rendered else { return }; await original.loadHistory(intent: intent) }
        .cyDomainScreen(.player)
    }
    private func start() {
        guard visible, scene == .active else { return }; retire()
        guard let reader = session.makeMemberReportProgressReader() else { return }
        let value = reader.makeCoordinator(); flow = value; owner = value.beginHistory(); load(readIntent())
    }
    private func readIntent() -> (MemberReportProgressCoordinator, MemberReportProgressIntent)? {
        guard visible, scene == .active, let flow, let owner, let intent = flow.capture(owner) else { return nil }
        return (flow, intent)
    }
    private func load(_ read: (MemberReportProgressCoordinator, MemberReportProgressIntent)?) {
        guard let (original, intent) = read, original.accepts(intent) else { return }
        Task { await original.loadHistory(intent: intent) }
    }
    private func retire() { if let owner { flow?.end(owner) }; flow = nil; owner = nil }
}
