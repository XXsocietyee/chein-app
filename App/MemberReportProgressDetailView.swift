import SwiftUI

@MainActor struct MemberReportProgressDetailView: View {
    let selection: MemberReportProgressSelection
    @ObservedObject var session: AppSession
    @Environment(\.scenePhase) private var scene
    @Environment(\.locale) private var locale
    @State private var flow: MemberReportProgressCoordinator?
    @State private var owner: MemberReportProgressPresentation?
    @State private var visible = false
    private var gutter: EdgeInsets {
        EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal)
    }
    var body: some View {
        let rendered = readIntent()
        List {
            CYHeroHeader("report.detail.title", tableName: "MemberReportProgress")
                .listRowBackground(Color.clear)
                .listRowInsets(gutter)
            if let flow, let original = flow.detailRecord {
                Text(verbatim: "#\(original.id)")
                    .font(CYTypography.numericBody)
                    .foregroundStyle(CYColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(gutter)
                    .listRowBackground(Color.clear)
                if let record = flow.detail {
                    fact(copy("report.target.\(record.targetKey)"), systemImage: "flag")
                    fact(copy("report.target.id"), value: String(record.targetId), systemImage: "number")
                    CYStatusChip(verbatim: copy("report.stage.\(record.stageKey)"), tone: stageTone(record.stage), systemImage: "flag")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(gutter)
                        .listRowBackground(Color.clear)
                    if let label = flow.reasonLabel(for: record) { fact(shown(label), systemImage: "text.quote") }
                    else { fact(copy("report.reason.fallback"), systemImage: "text.quote") }
                    if let version = record.policyVersion { fact(copy("report.policy"), value: shown(version), systemImage: "doc.text") }
                    fact(copy("report.version"), value: String(record.version), systemImage: "number")
                    if let description = record.description, !description.isEmpty {
                        Text(verbatim: shown(description))
                            .font(CYTypography.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .listRowInsets(gutter)
                            .listRowBackground(Color.clear)
                    }
                    labeledTime("report.created", value: record.createTime, systemImage: "clock")
                    if !record.isDecided, record.estimatedResolveAt != nil {
                        labeledTime("report.estimated", value: record.estimatedResolveAt, systemImage: "hourglass")
                    }
                    if record.anonymityPolicy == "SUBJECT_HIDDEN" {
                        memberReportProgressText("report.privacy.source")
                            .font(CYTypography.meta)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .listRowInsets(gutter)
                            .listRowBackground(Color.clear)
                    }
                    if let evidence = record.evidenceAssetIds {
                        fact(copy("report.evidence.count"), value: String(evidence.count), systemImage: "paperclip")
                    }
                    if let summary = record.decisionSummary, !summary.isEmpty {
                        Section { Text(verbatim: shown(summary)).font(CYTypography.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true).listRowInsets(gutter) } header: { memberReportProgressText("report.decision") }
                    }
                    if let timeline = record.timeline, !timeline.isEmpty {
                        Section {
                            ForEach(Array(timeline.enumerated()), id: \.offset) { _, event in
                                timelineRow(event).listRowInsets(gutter).listRowBackground(Color.clear)
                            }
                        } header: { memberReportProgressText("report.timeline.title") }
                    } else {
                        Section {
                            CYEmptyState(systemImage: "clock", "report.timeline.empty", tableName: "MemberReportProgress")
                                .listRowInsets(gutter)
                                .listRowBackground(Color.clear)
                        } header: { memberReportProgressText("report.timeline.title") }
                    }
                }
                if flow.busy {
                    CYSkeleton().listRowInsets(gutter).listRowBackground(Color.clear)
                }
                if let failure = flow.failure {
                    CYEmptyState(systemImage: "exclamationmark.triangle", LocalizedStringKey(failureKey(failure)), tableName: "MemberReportProgress")
                        .listRowInsets(gutter)
                        .listRowBackground(Color.clear)
                }
            } else {
                CYEmptyState(systemImage: "exclamationmark.triangle", "report.error.disabled", tableName: "MemberReportProgress")
                    .listRowInsets(gutter)
                    .listRowBackground(Color.clear)
            }
            memberReportProgressText("report.detail.boundary")
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .listRowInsets(gutter)
                .listRowBackground(Color.clear)
            CYPillButton("report.refresh", tableName: "MemberReportProgress") { load(rendered) }
                .disabled(rendered == nil || flow?.busy == true)
                .listRowInsets(gutter)
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
        .accessibilityIdentifier("report.progress.detail")
        .cyAnimation(value: flow?.busy == true)
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberReportProgressIdentity) { _, _ in retire() }
        .onChange(of: selection.reader.isCurrent) { _, valid in if !valid { retire() } }
    }
    private func timelineRow(_ event: MemberReportProgressEvent) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            CYListRow(verbatim: copy(event.titleKey), meta: event.stageKey.map { copy("report.stage.\($0)") }, trailing: .none) {
                CYRowIcon(systemImage: "clock")
            }
            if let note = event.publicNote, !note.isEmpty {
                Text(verbatim: shown(note))
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MemberReportProgressTimeView(value: event.createTime)
                .font(CYTypography.meta)
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
    private func labeledTime(_ key: String, value: MemberReportProgressTime?, systemImage: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            CYRowIcon(systemImage: systemImage)
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                memberReportProgressText(key).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                MemberReportProgressTimeView(value: value).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            }
            Spacer(minLength: CYSpacing.sm)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
        .listRowInsets(gutter)
        .listRowBackground(Color.clear)
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
