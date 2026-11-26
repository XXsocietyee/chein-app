import SwiftUI

@MainActor struct MemberReportProgressDetailView: View {
    let selection: MemberReportProgressSelection
    @ObservedObject var session: AppSession
    /// Round 4 (MP report-detail goMine, index.js:165-170): opened from 我的举报, so 查看我的全部举报 goes back
    /// instead of stacking a second list.
    var returnsToList = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scene
    @Environment(\.locale) private var locale
    @State private var flow: MemberReportProgressCoordinator?
    @State private var owner: MemberReportProgressPresentation?
    @State private var visible = false
    /// Survives the detail reload that clears `flow.detail`. An unconfirmed appeal keeps the id written before the first send.
    @State private var appealRetention = ReportAppealRetention()
    private var gutter: EdgeInsets {
        EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal)
    }
    var body: some View {
        let rendered = readIntent()
        List {
            // PLY-29-5: the title is the bar's inline title; pull-to-refresh replaces the 刷新 pill.
            if let flow, let original = flow.detailRecord {
                if let record = flow.detail {
                    // Source report-detail head card: 「对象 · 原因」 with the stage on the right, then 编号 N · 提交于 time.
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYStatusChip(verbatim: copy("report.stage.\(record.stageKey)"), tone: stageTone(record.stage))
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                            Text(verbatim: copy("report.target.\(record.targetKey)"))
                            Text(verbatim: "·").accessibilityHidden(true)
                            if let label = flow.reasonLabel(for: record) { Text(verbatim: shown(label)) }
                            else { Text(verbatim: copy("report.reason.fallback")) }
                        }
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        // PLY-29-3: mini-program stage hint (report-common STAGES[].hint).
                        if ["SUBMITTED", "TRIAGED", "INVESTIGATING", "RESOLVED", "CLOSED", "APPEALED"].contains(record.stageKey) {
                            Text(verbatim: copy("report.stageHint.\(record.stageKey)"))
                                .cyText(.bodyCompact)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: CYSpacing.xs) {
                            Text("u9cde.report.submittedAt")
                            MemberReportProgressTimeView(value: record.createTime)
                        }.cyText(.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                        // Round 4: MP head-card ETA line 「预计 … 前给出结论」 (report-detail wxml:23), as on 我的举报.
                        if !record.isDecided, let eta = record.estimatedResolveAt?.display() {
                            Text("report.eta \(eta)", tableName: "MemberReportProgress")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    .padding(CYSpacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("report.detail.head")
                    .listRowInsets(gutter)
                    .listRowBackground(Color.clear)
                }
                if keepsAppeal(flow), let client = session.playerCapabilityClient() {
                    ReportAppealSection(reportID: Int(original.id), client: client,
                                        stageLabel: { CommunityTrustPlayerService.stageLabels[$0] },
                                        readBack: { load(readIntent()) },
                                        retention: $appealRetention)
                }
                if let record = flow.detail {
                    if record.stageKey == "APPEALED" {
                        memberReportProgressText("report.appealed.note")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowInsets(gutter)
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("report.detail.appealed")
                    }
                    if let summary = record.decisionSummary, !summary.isEmpty {
                        Section { Text(verbatim: shown(summary)).cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true).listRowInsets(gutter) } header: { Text("u9cde.report.decision") }
                    }
                    if let description = record.description, !description.isEmpty {
                        Section {
                            Text(verbatim: shown(description))
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .listRowInsets(gutter)
                                .listRowBackground(Color.clear)
                        } header: { Text("u9cde.report.yourNote") }
                    }
                    if record.anonymityPolicy == "SUBJECT_HIDDEN" {
                        memberReportProgressText("report.privacy.source")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowInsets(gutter)
                            .listRowBackground(Color.clear)
                    }
                    if let evidence = record.evidenceAssetIds {
                        fact(copy("report.evidence.count"), value: String(evidence.count), systemImage: "paperclip")
                    }
                    if let timeline = record.timeline, !timeline.isEmpty {
                        Section {
                            ForEach(Array(timeline.enumerated()), id: \.offset) { _, event in
                                timelineRow(event).listRowInsets(gutter).listRowBackground(Color.clear)
                            }
                        } header: { Text("u9cde.report.progress") }
                    } else {
                        Section {
                            Text("u9cde.report.progressEmpty").cyText(.body).foregroundStyle(CYColor.textSecondary)
                                .accessibilityIdentifier("report.timeline.empty")
                                .listRowInsets(gutter)
                                .listRowBackground(Color.clear)
                        } header: { Text("u9cde.report.progress") }
                    }
                }
                if flow.busy {
                    CYSkeleton().listRowInsets(gutter).listRowBackground(Color.clear)
                }
                if let failure = flow.failure {
                    CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(failureKey(failure)), tableName: "MemberReportProgress", actionTitle: "report.retry", action: { load(rendered) })
                        .listRowInsets(gutter)
                        .listRowBackground(Color.clear)
                }
            } else {
                CYEmptyState(systemImage: "exclamationmark.triangle", "report.error.disabled", tableName: "MemberReportProgress")
                    .listRowInsets(gutter)
                    .listRowBackground(Color.clear)
            }
            // PLY-29-2: the developer boundary footer (which contradicted the appeal button) is gone.
            // R7-MEM-29-1: MP report-detail 查看我的全部举报 (wxml:48-49) opens 我的举报.
            Section {
                Group {
                    if returnsToList {
                        Button { dismiss() } label: { allReportsLabel }
                    } else {
                        NavigationLink { SquareReportProgressView(session: session) } label: { allReportsLabel }
                    }
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .listRowInsets(gutter)
                .accessibilityIdentifier("report.progress.detail.allReports")
            }
        }
        .listStyle(.plain)
        .cyGroupedSurface()
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberReportProgressText("report.detail.title")).navigationBarTitleDisplayMode(.inline)
        .refreshable { if let (original, intent) = readIntent(), original.accepts(intent) { await original.loadDetail(intent: intent) } }
        .privacySensitive()
        .accessibilityIdentifier("report.progress.detail")
        .cyAnimation(value: flow?.busy == true)
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberReportProgressIdentity) { _, _ in retire() }
        .onChange(of: selection.reader.isCurrent) { _, valid in if !valid { retire() } }
        .cyDomainScreen(.player)
    }
    private func timelineRow(_ event: MemberReportProgressEvent) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYListRow(verbatim: copy(event.titleKey), meta: event.stageKey.map { copy("report.stage.\($0)") }, trailing: .none) {
                CYRowIcon(systemImage: "clock")
            }
            if let note = event.publicNote, !note.isEmpty {
                Text(verbatim: shown(note))
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MemberReportProgressTimeView(value: event.createTime)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
    }
    private func fact(_ title: String, value: String? = nil, systemImage: String) -> some View {
        let trailing: CYListRowTrailing = value.map { .value(shown($0)) } ?? .none
        return CYListRow(verbatim: title, trailing: trailing) {
            CYRowIcon(systemImage: systemImage)
        }
        .listRowInsets(gutter)
        .listRowBackground(Color.clear)
    }
    private var allReportsLabel: some View {
        Text(verbatim: CoreLoopCopy(locale: locale).t("查看我的全部举报", "View all my reports"))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Appeal stays mounted while a reload clears `detail`, so the id written before the send is not dropped.
    /// `APPEALED` on the following read is the case moving on; any other unread or still-open stage keeps the attempt.
    private func keepsAppeal(_ flow: MemberReportProgressCoordinator) -> Bool {
        if !appealRetention.requestID.isEmpty, appealRetention.result == nil {
            return flow.detail?.stage != "APPEALED"
        }
        guard let stage = flow.detail?.stage else { return false }
        return CommunityTrustPlayerService.appealableStages.contains(stage)
    }
    private func copy(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "MemberReportProgress", locale: locale))
    }
    private func failureKey(_ failure: MemberReportProgressFailure) -> String { "report.error.\(failure)" }
    private func stageTone(_ stage: String) -> CYStatusTone {
        switch stage {
        case "RESOLVED", "CLOSED": return .success
        case "APPEALED": return .warning
        case "INVESTIGATING", "TRIAGED": return .info
        default: return .neutral
        }
    }
    /// Blank server copy is unknown. Numeric ids, versions and evidence counts stay as written, including 0.
    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }
    private func start() {
        guard visible, scene == .active else { return }; retire()
        guard selection.reader.isCurrent else { return }
        let value = selection.reader.makeCoordinator(); flow = value; owner = value.beginDetail(selection.record); load(readIntent())
    }
    private func readIntent() -> (MemberReportProgressCoordinator, MemberReportProgressIntent)? {
        guard visible, scene == .active, let flow, let owner, let intent = flow.capture(owner) else { return nil }
        return (flow, intent)
    }
    private func load(_ read: (MemberReportProgressCoordinator, MemberReportProgressIntent)?) {
        guard let (original, intent) = read, original.accepts(intent) else { return }
        Task { await original.loadDetail(intent: intent) }
    }
    private func retire() { if let owner { flow?.end(owner) }; flow = nil; owner = nil }
}

/// `subpackageMember/report-detail/index?reportId=` for the page router (PLY-29-1). Finds the report in the owner's
/// own `reports/mine` read, then shows the same detail screen. Signed out, not this account's report, or a failed read
/// each show one state with a way out.
@MainActor struct MemberReportProgressDeepLinkScreen: View {
    let reportID: Int64
    @ObservedObject var session: AppSession
    @State private var selection: MemberReportProgressSelection?
    @State private var phase: Phase = .loading
    @State private var showsSignIn = false
    private enum Phase: Equatable { case loading, ready, notFound, failed, signedOut }

    var body: some View {
        Group {
            if phase == .ready, let selection {
                MemberReportProgressDetailView(selection: selection, session: session)
            } else {
                state
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cyPushedChrome(domain: .player)
                    .navigationTitle(memberReportProgressText("report.detail.title")).navigationBarTitleDisplayMode(.inline)
                    .cyDomainScreen(.player)
            }
        }
        .task(id: session.memberReportProgressIdentity) { await resolve() }
        .sheet(isPresented: $showsSignIn, onDismiss: { Task { await resolve() } }) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
    }

    @ViewBuilder private var state: some View {
        switch phase {
        case .loading, .ready:
            CYSkeleton().padding(CYSpacing.pageHorizontal)
        case .signedOut:
            CYEmptyState(systemImage: "person.crop.circle", "report.signIn.title", tableName: "MemberReportProgress",
                         actionTitle: "report.signIn.action", actionIdentifier: "report.detail.signIn", actionStyle: .primary) { showsSignIn = true }
        case .notFound:
            CYEmptyState(systemImage: "doc.text.magnifyingglass", "report.detail.notFound", tableName: "MemberReportProgress")
        case .failed:
            CYEmptyState(systemImage: "exclamationmark.triangle", "report.detail.failed", tableName: "MemberReportProgress",
                         actionTitle: "report.retry", kind: .failure) { Task { await resolve() } }
        }
    }

    private func resolve() async {
        selection = nil
        guard session.account != nil else { phase = .signedOut; return }
        guard let reader = session.makeMemberReportProgressReader() else { phase = .notFound; return }
        phase = .loading
        do {
            let found = try await MemberReportProgressSelection.owned(reportID: reportID, reader: reader)
            selection = found
            phase = found == nil ? .notFound : .ready
        } catch is CancellationError {
            return
        } catch {
            phase = .failed
        }
    }
}
