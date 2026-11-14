import SwiftUI

@MainActor struct CityPlayerRulesPresentation: Identifiable {
    let id = UUID()
    let readID: UUID
    let read: CityReadSnapshot
    let flow: CityPlayerRulesFlow
}

/// Full published public rule text and allowlisted policies, never a server-plan dump.
@MainActor struct CityPlayerRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State var flow: CityPlayerRulesFlow
    @State private var visible = false
    let selectionIsCurrent: () -> Bool
    private let table = "CityPlayerRules"
    var body: some View {
        NavigationStack {
            CityPlayerRulesContent(phase: flow.phase, snapshot: flow.snapshot,
                                   canRefresh: !(flow.phase == .loading || !visible || scenePhase != .active || !flow.current),
                                   refresh: { Task { await flow.load() } })
            .navigationTitle(Text("cityRules.title", tableName: "CityPlayerRules"))
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("cityRules.screen")
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button { flow.cancel(); dismiss() } label: { Text("cityRules.back", tableName: table) }
                    .accessibilityIdentifier("cityRules.back")
            } }
            .task {
                visible = true
                flow.bindSelection { visible && scenePhase == .active && selectionIsCurrent() }
                guard scenePhase == .active else { return }
                await flow.load()
            }
            .onChange(of: scenePhase) { _, phase in
                flow.cancel()
                if visible && phase == .active { Task { await flow.load() } }
            }
            .onDisappear { visible = false; flow.cancel() }
        }
        .cyDomainScreen(.player)
    }
}

/// Value-driven body of the rules page so a DEBUG fixture can feed a decoded snapshot into the same layout.
struct CityPlayerRulesContent: View {
    let phase: CityPlayerRulesFlow.Phase
    let snapshot: CityPlayerRulesSnapshot?
    let canRefresh: Bool
    let refresh: () -> Void
    private let table = "CityPlayerRules"
    private static let icons = ["rules": "text.book.closed.fill", "protection": "shield.lefthalf.filled", "safety": "cross.case.fill", "dice": "dice.fill",
                                "pointCost": "circle.hexagongrid.fill", "serviceFee": "yensign.circle.fill", "participation": "person.3.fill",
                                "actionBudget": "bolt.fill", "acquisition": "flag.fill", "season": "calendar", "effectiveInterval": "clock.fill",
                                "settlement": "banknote.fill", "taskDetails": "checklist", "locationDetails": "mappin.and.ellipse"]
    private static let technical: Set<String> = ["rulesId", "challengeId", "diceId", "roundId", "seasonId"]
    /// Rule sections the player has opened; the first section starts open so the page never loads as a wall of closed cards.
    @State private var opened: Set<String> = []
    @State private var seeded = false
    var body: some View {
        CYCardPage {
            CYArtCoverHeader(title: Text("cityRules.title", tableName: table), subtitle: Text("cityRules.boundary", tableName: table),
                             symbol: "list.bullet.rectangle.portrait.fill", seed: "rules") { EmptyView() }
        } content: {
            if phase == .loading { ProgressView { Text("cityRules.loading", tableName: table) }.frame(maxWidth: .infinity).padding(CYSpacing.lg) }
            else if phase != .ready {
                CYNoteBanner(text: Text(LocalizedStringKey("cityRules.phase." + phase.rawValue), tableName: table), symbol: "exclamationmark.circle", tone: .warning)
                    .accessibilityIdentifier("cityRules.state")
            }
            if let snapshot {
                eligibility(snapshot)
                ForEach(snapshot.sections) { section in sectionCard(section) }
                CYInfoCard {
                    CYDetailsDisclosure(title: Text("cityRules.identity", tableName: table)) {
                        CYFactRow(label: Text("cityRules.field.boardId", tableName: table), value: snapshot.board.boardId)
                        CYFactRow(label: Text("cityRules.field.seasonId", tableName: table), value: snapshot.board.seasonId)
                        CYFactRow(label: Text("cityRules.field.rulesReleaseId", tableName: table), value: snapshot.board.rulesReleaseId)
                        CYFactRow(label: Text("cityRules.field.revision", tableName: table), value: String(snapshot.board.revision))
                        CYFactRow(label: Text("cityRules.field.rulesHash", tableName: table), value: snapshot.board.rulesHash)
                    }
                }
                Text("cityRules.excluded", tableName: table).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            CYPillButton(LocalizedStringKey("cityRules.refresh"), style: .secondary, systemImage: "arrow.clockwise", tableName: table, action: refresh)
                .disabled(!canRefresh).accessibilityIdentifier("cityRules.refresh")
        }
    }
    private func eligibility(_ snapshot: CityPlayerRulesSnapshot) -> some View {
        let e = snapshot.eligibility
        return CYInfoCard(title: Text("cityRules.eligibility.title", tableName: table), symbol: "person.badge.shield.checkmark.fill") {
            Text(LocalizedStringKey("cityRules.eligibility." + e.status), tableName: table)
                .font(CYTypography.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("cityRules.eligibility")
            if e.memberCount != nil || e.presentCount != nil || e.confirmedCount != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CYSpacing.sm) { counts(e) }
                    VStack(spacing: CYSpacing.sm) { counts(e) }
                }
            }
            Text("cityRules.noActionGrant", tableName: table).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
        }
    }
    @ViewBuilder private func counts(_ e: CityPlayerRulesEligibility) -> some View {
        if let n = e.memberCount { stat(n, "cityRules.field.memberCount") }
        if let n = e.presentCount { stat(n, "cityRules.field.presentCount") }
        if let n = e.confirmedCount { stat(n, "cityRules.field.confirmedCount") }
    }
    private func stat(_ n: Int, _ key: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: String(n)).font(CYTypography.dataXL).foregroundStyle(CYColor.textPrimary)
            Text(LocalizedStringKey(key), tableName: table).font(CYTypography.caption).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 64).padding(CYSpacing.sm)
        .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private func sectionCard(_ section: CityPlayerRulesSection) -> some View {
        let shown = section.rows.filter { !Self.technical.contains($0.key) }
        let hidden = section.rows.filter { Self.technical.contains($0.key) }
        let isOpen = Binding(get: { opened.contains(section.id) || (!seeded && section.id == (snapshot?.sections.first?.id ?? "")) },
                             set: { seeded = true; if $0 { opened.insert(section.id) } else { opened.remove(section.id) } })
        return CYCollapsibleCard(title: Text(LocalizedStringKey("cityRules.section." + section.id), tableName: table), symbol: Self.icons[section.id] ?? "doc.text", expanded: isOpen) {
            if section.status != "PUBLISHED" {
                Text(LocalizedStringKey("cityRules.disclosure." + section.status), tableName: table)
                    .font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(shown) { item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey("cityRules.field." + item.key), tableName: table).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    value(item, sectionID: section.id).font(CYTypography.body).foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("cityRules.field.\(section.id).\(item.key)")
            }
            if !hidden.isEmpty {
                CYDetailsDisclosure(title: Text("cityRules.identity", tableName: table)) {
                    ForEach(hidden) { item in CYFactRow(label: Text(LocalizedStringKey("cityRules.field." + item.key), tableName: table), value: item.value) }
                }
            }
        }
    }
    private func value(_ row: CityPlayerRulesRow, sectionID: String) -> Text {
        if let key = row.localizationKey(sectionID: sectionID) {
            return Text(LocalizedStringKey(key), tableName: table)
        }
        return Text(verbatim: row.value)
    }
}
