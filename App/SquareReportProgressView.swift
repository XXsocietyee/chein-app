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
    @State private var refreshToast: LocalizedStringKey?
    @Environment(\.locale) private var locale
    var body: some View {
        let rendered = readIntent()
        List {
            // PLY-28-1/2: inline bar title; no developer boundary line and no 刷新 pill next to pull-to-refresh.
            if let flow, flow.isCurrent {
                // mp-mine r3: MP report-mine shows the chips only once there are records; loading, error and
                // 「还没有举报记录」 (全部) stand alone. A filtered-empty list keeps the chips so the filter can change back.
                if flow.filter != .all || !flow.records.isEmpty {
                Picker(selection: Binding(get: { flow.filter }, set: { value in
                    guard let (original, intent) = rendered else { return }; original.changeFilter(value, intent: intent)
                })) {
                    ForEach(MemberReportProgressFilter.allCases) { memberReportProgressText("report.filter.\($0.rawValue)").tag($0) }
                } label: { memberReportProgressText("report.filter.title") }.cyAdaptiveSegmented().disabled(flow.busy)
                }
                ForEach(flow.records) { record in
                    Button {
                        guard let (original, intent) = rendered, let selected = original.select(record, intent: intent) else { return }
                        selection = selected
                    } label: {
                        // Source report-mine row: 「对象 · 原因」 over 「编号 N · 时间」 and the stage, as a system list row.
                        HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            // mp-mine r3: MP `rp-row__head` — 「对象 · 原因」 with the stage tag at the end of the same line.
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    memberReportProgressText("report.target.\(record.targetKey)")
                                    Text(verbatim: "·").accessibilityHidden(true)
                                    if let label = flow.reasonLabel(for: record) { Text(verbatim: label) }
                                    else { memberReportProgressText("report.reason.fallback") }
                                }
                                .font(.body)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                                memberReportProgressText("report.stage.\(record.stageKey)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            MemberReportProgressTimeView(value: record.createTime)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            // PLY-28-3: mini-program ETA line 「预计 … 前给出结论」 while the report is still open.
                            if !["RESOLVED", "CLOSED"].contains(record.stageKey), let eta = record.estimatedResolveAt?.display() {
                                Text("report.eta \(eta)", tableName: "MemberReportProgress")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // PLY-28-6: disclosure chevron, as the MP row.
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary).accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    // PLY-28-6: one VoiceOver element: 对象，原因，阶段 … then the 查看进度 hint.
                    .accessibilityElement(children: .combine)
                    .accessibilityHint(Text(verbatim: CoreLoopCopy(locale: locale).t("查看进度", "View progress")))
                    .disabled(flow.busy || !flow.reader.allows(.detail))
                    .accessibilityIdentifier("report.progress.row.\(record.id)")
                }
                if flow.loaded && flow.records.isEmpty {
                    // PLY-28-3: one empty line per filter, as the mini-program.
                    ContentUnavailableView {
                        Label { Text(LocalizedStringKey("report.history.empty." + flow.filter.rawValue), tableName: "MemberReportProgress") } icon: { Image(systemName: "tray") }
                    }
                }
                if flow.hasMore {
                    Button {
                        guard let (original, intent) = rendered else { return }; original.showMore(intent: intent)
                    } label: { memberReportProgressText("report.history.more") }.disabled(flow.busy)
                }
                if flow.loaded && !flow.records.isEmpty && !flow.hasMore && !flow.busy {
                    // Source list footer: 已经到底了.
                    Text("u9cde.report.end").font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        .accessibilityIdentifier("report.progress.end")
                }
                // R7-MEM-28-1: the skeleton is for the first load only; a refresh over kept rows stays quiet.
                if flow.busy && flow.records.isEmpty { ProgressView().frame(maxWidth: .infinity) }
                if let failure = flow.failure, flow.records.isEmpty {
                    let message = LocalizedStringKey("report.error." + String(describing: failure))
                    ContentUnavailableView {
                        Label { Text(message, tableName: "MemberReportProgress").accessibilityIdentifier("report.progress.error") } icon: { Image(systemName: "exclamationmark.triangle") }
                    } actions: {
                        Button { load(rendered) } label: { memberReportProgressText("report.retry") }
                            .buttonStyle(.bordered)
                    }
                }
            } else if session.account == nil {
                // PLY-28-4: signed out → mini-program login gate with a way to sign in.
                ContentUnavailableView {
                    Label { memberReportProgressText("report.signIn.title").accessibilityIdentifier("report.progress.signIn") } icon: { Image(systemName: "person.crop.circle") }
                } actions: {
                    Button { showsSignIn = true } label: { memberReportProgressText("report.signIn.action") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("report.progress.signIn.action")
                }
            } else { memberReportProgressText("report.error.disabled") }
        }
        .listStyle(.insetGrouped)
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberReportProgressText("report.history.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .cySheet(isPresented: $showsSignIn, onDismiss: { retire(); start() }) { Group { LoginView(intent: .player).environmentObject(session) }.cySheet(detents: [.large]) }
        .accessibilityIdentifier("report.progress.history")
        .navigationDestination(item: $selection) { MemberReportProgressDetailView(selection: $0, session: session, returnsToList: true) }
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberReportProgressIdentity) { _, _ in selection = nil; retire(); start() }
        .refreshable { guard let (original, intent) = rendered else { return }; await original.loadHistory(intent: intent) }
        // R7-MEM-28-1: MP report-mine keeps the rows on a failed refresh and only toasts.
        .onChange(of: flow?.failure.map { String(describing: $0) }) { _, failure in
            if failure != nil, flow?.records.isEmpty == false { refreshToast = "profile.refreshFailed" }
        }
        .cyToast(message: $refreshToast, tone: .warning)
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
