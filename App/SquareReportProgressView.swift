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
    var body: some View {
        let rendered = readIntent()
        List {
            CYHeroHeader("report.history.title", tableName: "MemberReportProgress")
                .listRowBackground(Color.clear).listRowInsets(EdgeInsets())
            memberReportProgressText("report.read.boundary").font(.footnote)
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
                        HStack(alignment: .center, spacing: CYSpacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    memberReportProgressText("report.target.\(record.targetKey)")
                                    Text(verbatim: "·").accessibilityHidden(true)
                                    if let label = flow.reasonLabel(for: record) { Text(verbatim: label) }
                                    else { memberReportProgressText("report.reason.fallback") }
                                }.foregroundStyle(CYColor.textPrimary)
                                HStack(spacing: 4) {
                                    Text("u9cde.report.number \(String(record.id))")
                                    Text(verbatim: "·").accessibilityHidden(true)
                                    MemberReportProgressTimeView(value: record.createTime)
                                }.font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            }
                            Spacer(minLength: CYSpacing.sm)
                            memberReportProgressText("report.stage.\(record.stageKey)").font(.subheadline.weight(.semibold)).foregroundStyle(CYColor.textPrimary)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.secondary).accessibilityHidden(true)
                        }
                    }.disabled(flow.busy || !flow.reader.allows(.detail))
                    .accessibilityIdentifier("report.progress.row.\(record.id)")
                }
                if flow.loaded && flow.records.isEmpty { CYEmptyState(systemImage: "doc.text.magnifyingglass", "report.history.empty", tableName: "MemberReportProgress") }
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
                if flow.busy { CYSkeleton() }
                if let failure = flow.failure {
                    let message = LocalizedStringKey("report.error." + String(describing: failure))
                    CYEmptyState(systemImage: "exclamationmark.triangle", message, tableName: "MemberReportProgress", messageIdentifier: "report.progress.error", actionTitle: "report.refresh", action: { load(rendered) })
                }
            } else { memberReportProgressText("report.error.disabled") }
            CYPillButton("report.refresh", style: .secondary, tableName: "MemberReportProgress") { load(rendered) }
                .listRowBackground(Color.clear).disabled(rendered == nil || flow?.busy == true)
        }
        .cyGroupedSurface()
        .cyHeroScreen().privacySensitive()
        .accessibilityIdentifier("report.progress.history")
        .navigationDestination(item: $selection) { MemberReportProgressDetailView(selection: $0, session: session) }
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberReportProgressIdentity) { _, _ in selection = nil; retire(); start() }
        .refreshable { guard let (original, intent) = rendered else { return }; await original.loadHistory(intent: intent) }
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
