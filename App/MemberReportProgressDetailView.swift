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
    var body: some View {
        let rendered = readIntent()
        List {
            // PLY-29-5: the title is the bar's inline title; pull-to-refresh replaces the 刷新 pill.
            if let flow, let original = flow.detailRecord {
                if let record = flow.detail {
                    // Source report-detail head card: 「对象 · 原因」 with the stage on the right, then 编号 N · 提交于 time.
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Label {
                                Text(verbatim: copy("report.stage.\(record.stageKey)"))
                            } icon: {
                                Image(systemName: "circle.fill").foregroundStyle(stageTint(record.stage))
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(verbatim: copy("report.target.\(record.targetKey)"))
                                Text(verbatim: "·").accessibilityHidden(true)
                                if let label = flow.reasonLabel(for: record) { Text(verbatim: shown(label)) }
                                else { Text(verbatim: copy("report.reason.fallback")) }
                            }
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                            // PLY-29-3: mini-program stage hint (report-common STAGES[].hint); an unrecognised
                            // stage reads 状态暂时无法识别，请稍后刷新 as in MP normalizeReport.
                            Text(verbatim: copy(stageHintKey(record.stageKey)))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            // MP hides 提交于 when the time is missing (wxml:22).
                            if record.createTime != nil {
                                HStack(spacing: 4) {
                                    Text("u9cde.report.submittedAt")
                                    MemberReportProgressTimeView(value: record.createTime)
                                }.font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                            }
                            // Round 4: MP head-card ETA line 「预计 … 前给出结论」 (report-detail wxml:23), as on 我的举报.
                            if !record.isDecided, let eta = record.estimatedResolveAt?.display() {
                                Text("report.eta \(eta)", tableName: "MemberReportProgress")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            // MP head card ends with the privacy line (wxml:24), above 处理结论.
                            if record.anonymityPolicy == "SUBJECT_HIDDEN" {
                                memberReportProgressText("report.privacy.source")
                                    .font(.footnote).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("report.detail.head")
                    }
                }
                if let record = flow.detail {
                    if let summary = record.decisionSummary, !summary.isEmpty {
                        Section { Text(verbatim: shown(summary)).fixedSize(horizontal: false, vertical: true) } header: { Text("u9cde.report.decision") }
                    }
                    if let description = record.description, !description.isEmpty {
                        Section {
                            Text(verbatim: shown(description))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } header: { Text("u9cde.report.yourNote") }
                    }
                    if let timeline = record.timeline, !timeline.isEmpty {
                        Section {
                            ForEach(Array(timeline.enumerated()), id: \.offset) { _, event in
                                timelineRow(event)
                            }
                        } header: { Text("u9cde.report.progress") }
                    } else {
                        Section {
                            ContentUnavailableView("u9cde.report.progressEmpty", systemImage: "clock")
                                .accessibilityIdentifier("report.timeline.empty")
                        } header: { Text("u9cde.report.progress") }
                    }
                    // mp-mine r3: MP report-detail puts 提交申诉 / 申诉已受理 after the timeline (wxml:42-47).
                    if record.stageKey == "APPEALED" {
                        Section {} footer: {
                            memberReportProgressText("report.appealed.note")
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityIdentifier("report.detail.appealed")
                        }
                    }
                }
                if keepsAppeal(flow), let client = session.playerCapabilityClient() {
                    ReportAppealSection(reportID: Int(original.id), client: client,
                                        stageLabel: { CommunityTrustPlayerService.stageLabels[$0] },
                                        readBack: { load(readIntent()) },
                                        retention: $appealRetention)
                }
                if flow.busy {
                    Section { CYLoadingState() }
                }
                if let failure = flow.failure {
                    ContentUnavailableView {
                        Label {
                            Text(LocalizedStringKey(failureKey(failure)), tableName: "MemberReportProgress")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                        }
                    } description: {
                        EmptyView()
                    } actions: {
                        Button { load(rendered) } label: { Text("report.retry", tableName: "MemberReportProgress") }
                            .buttonStyle(.bordered)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label {
                        Text("report.error.disabled", tableName: "MemberReportProgress")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                    }
                }
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
                .accessibilityIdentifier("report.progress.detail.allReports")
            }
        }
        .listStyle(.insetGrouped)
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberReportProgressText("report.detail.title")).navigationBarTitleDisplayMode(.inline)
        .refreshable { if let (original, intent) = readIntent(), original.accepts(intent) { await original.loadDetail(intent: intent) } }
        .privacySensitive()
        .accessibilityIdentifier("report.progress.detail")
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberReportProgressIdentity) { _, _ in retire() }
        .onChange(of: selection.reader.isCurrent) { _, valid in if !valid { retire() } }
        .cyDomainScreen(.player)
    }
    private static let knownStages: Set<String> = ["SUBMITTED", "TRIAGED", "INVESTIGATING", "RESOLVED", "CLOSED", "APPEALED"]
    private func stageHintKey(_ stage: String) -> String {
        Self.knownStages.contains(stage) ? "report.stageHint.\(stage)" : "report.stageHint.UNKNOWN"
    }
    /// MP report-common `eventTitle`: 举报已提交 / 已提交申诉, else 进入「stage」, else 进度更新.
    private func timelineTitle(_ event: MemberReportProgressEvent) -> String {
        if event.eventType == "SUBMITTED" || event.eventType == "APPEALED" { return copy(event.titleKey) }
        guard let stage = event.stageKey else { return copy("report.timeline.event") }
        let label = Self.knownStages.contains(stage) ? copy("report.stage.\(stage)") : "—"
        return String(format: copy("report.timeline.entered"), label)
    }
    private func timelineRow(_ event: MemberReportProgressEvent) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: shown(timelineTitle(event)))
                if let note = event.publicNote, !note.isEmpty {
                    Text(verbatim: shown(note))
                        .fixedSize(horizontal: false, vertical: true)
                }
                MemberReportProgressTimeView(value: event.createTime)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "clock")
        }
        .accessibilityElement(children: .combine)
    }
    private func fact(_ title: String, value: String? = nil, systemImage: String) -> some View {
        LabeledContent {
            if let value { Text(verbatim: shown(value)).monospacedDigit() }
        } label: {
            Label(shown(title), systemImage: systemImage)
        }
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
    private func stageTint(_ stage: String) -> Color {
        switch stage {
        case "RESOLVED", "CLOSED": return .green
        case "APPEALED": return .orange
        case "INVESTIGATING", "TRIAGED": return .blue
        default: return .secondary
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
        .cySheet(isPresented: $showsSignIn, onDismiss: { Task { await resolve() } }) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
    }

    @ViewBuilder private var state: some View {
        switch phase {
        case .loading, .ready:
            ProgressView { Text("cy.state.loading") }
        case .signedOut:
            ContentUnavailableView {
                Label {
                    Text("report.signIn.title", tableName: "MemberReportProgress")
                } icon: {
                    Image(systemName: "person.crop.circle")
                }
            } description: {
                EmptyView()
            } actions: {
                Button { showsSignIn = true } label: { Text("report.signIn.action", tableName: "MemberReportProgress") }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("report.detail.signIn")
            }
        case .notFound:
            ContentUnavailableView {
                Label {
                    Text("report.detail.notFound", tableName: "MemberReportProgress")
                } icon: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
            }
        case .failed:
            ContentUnavailableView {
                Label {
                    Text("report.detail.failed", tableName: "MemberReportProgress")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
            } description: {
                EmptyView()
            } actions: {
                Button { Task { await resolve() } } label: { Text("report.retry", tableName: "MemberReportProgress") }
                    .buttonStyle(.bordered)
            }
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
