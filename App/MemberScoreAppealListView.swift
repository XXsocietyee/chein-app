import SwiftUI

func memberScoreText(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: "MemberScoreAppealList") }

/// Blank server text is unknown. A real value, including a real zero, is left as written.
func playerFactOrDash(_ raw: String?) -> String {
    let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return trimmed.isEmpty ? "—" : trimmed
}

@MainActor struct MemberScoreAppealSettingsEntry: View {
    @ObservedObject var session: AppSession
    var body: some View {
        Section {
            NavigationLink { MemberScoreAppealListView(session: session) } label: {
                HStack(spacing: CYSpacing.md) {
                    CYRowIcon(systemImage: "text.bubble")
                    memberScoreText("score.mine.title")
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: CYSpacing.sm)
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
            }.accessibilityIdentifier("settings.scoreAppeals")
        }
    }
}

@MainActor struct MemberScoreAppealListView: View {
    @ObservedObject var session: AppSession
    @Environment(\.scenePhase) private var scene
    @State private var flow: MemberScoreAppealReadCoordinator?
    @State private var owner: MemberScoreReadPresentation?
    @State private var filter: MemberScoreAppealFilter = .all
    @State private var visible = false
    @State private var selection: MemberScoreAppealSelection?
    var body: some View {
        let rendered = readIntent()
        List {
            Section {
                CYHeroHeader("score.mine.title", subtitle: "score.mine.boundary", tableName: "MemberScoreAppealList")
            }.e1HeroRow()
            Picker(selection: $filter) {
                ForEach(MemberScoreAppealFilter.allCases) { memberScoreText("score.filter.\($0.rawValue)").tag($0) }
            } label: { memberScoreText("score.filter.title") }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            if let flow, flow.isCurrent {
                if let reputation = flow.reputation {
                    MemberScoreChipChrome(tone: reputation == .normal ? .success : .warning, symbol: reputation == .normal ? "checkmark.seal" : "exclamationmark.triangle") {
                        memberScoreText("score.reputation.\(reputation.rawValue)")
                    }
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                } else if flow.reputationUnavailable {
                    MemberScoreChipChrome(tone: .neutral, symbol: "questionmark") {
                        memberScoreText("score.reputation.unavailable")
                    }
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                }
                ForEach(flow.rows) { row in
                    Button {
                        guard let (original, intent) = rendered,
                              let selected = original.select(row, intent: intent) else { return }
                        selection = selected
                    } label: {
                        MemberScoreAppealRowLabel(row: row, showsChevron: row.canReadSession && flow.client.allows(.sessionDetail))
                    }
                    .buttonStyle(.cyPressable)
                    .disabled(flow.busy || !row.canReadSession || !flow.client.allows(.sessionDetail))
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                }
                if flow.loaded && flow.rows.isEmpty {
                    CYEmptyState(systemImage: "text.bubble", "score.mine.empty", tableName: "MemberScoreAppealList")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
                }
                if flow.hasMore {
                    CYPillButton("score.mine.more", style: .secondary, tableName: "MemberScoreAppealList") { load(rendered, more: true) }
                        .disabled(flow.busy)
                        .e1ActionRow()
                }
                if flow.busy {
                    CYSkeleton()
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("score.mine.loading", tableName: "MemberScoreAppealList"))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
                }
                if let failure = flow.failure {
                    Label {
                        memberScoreText("score.error.\(failure)")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle").accessibilityHidden(true)
                    }
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("score.mine.status")
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
                }
                memberScoreText("score.time.source")
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            } else {
                CYEmptyState(systemImage: "exclamationmark.triangle", "score.error.disabled", tableName: "MemberScoreAppealList", kind: .failure)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
            }
            CYPillButton("score.mine.refresh", style: .tertiary, tableName: "MemberScoreAppealList") { load(rendered) }
                .disabled(rendered == nil || flow?.busy == true)
                .e1ActionRow()
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface().cyHeroScreen().privacySensitive()
        .accessibilityIdentifier("score.mine.list")
        .navigationDestination(item: $selection) { MemberScoreAppealDetailView(selection: $0, session: session) }
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: filter) { _, _ in start() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberScoreReadIdentity) { _, _ in selection = nil; retire(); start() }
        .refreshable { guard let (original, intent) = rendered else { return }; await original.loadList(intent: intent) }
        .cyDomainScreen(.player)
    }
    private func start() {
        guard visible, scene == .active else { return }; retire()
        guard let client = session.makeMemberScoreAppealListClient() else { return }
        let value = client.makeCoordinator(); flow = value; owner = value.beginList(filter: filter)
        load(readIntent())
    }
    private func readIntent() -> (MemberScoreAppealReadCoordinator, MemberScoreReadIntent)? {
        guard visible, scene == .active, let flow, let owner, let intent = flow.capture(owner) else { return nil }
        return (flow, intent)
    }
    private func load(_ read: (MemberScoreAppealReadCoordinator, MemberScoreReadIntent)?, more: Bool = false) {
        guard let (original, intent) = read, original.accepts(intent) else { return }
        Task { await original.loadList(more: more, intent: intent) }
    }
    private func retire() { if let owner { flow?.end(owner) }; flow = nil; owner = nil }
}

private struct MemberScoreAppealRowLabel: View {
    let row: MemberScoreAppealRow
    let showsChevron: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let symbol = row.kind == .appeal ? "text.bubble" : "flag"
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        CYRowIcon(systemImage: symbol)
                        copy
                    }
                    MemberScoreStatusChip(status: row.status)
                }
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    CYRowIcon(systemImage: symbol)
                    copy
                    Spacer(minLength: CYSpacing.sm)
                    MemberScoreStatusChip(status: row.status)
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(CYColor.textTertiary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            memberScoreText("score.kind.\(row.kind.rawValue)")
                .font(CYTypography.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: playerFactOrDash(row.title))
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: playerFactOrDash(row.createTime))
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textTertiary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if !row.canReadSession {
                memberScoreText("score.detail.missingContext")
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MemberScoreStatusChip: View {
    let status: MemberScoreAppealStatus
    private var tone: CYStatusTone {
        switch status {
        case .open: return .warning
        case .accepted: return .success
        case .rejected: return .danger
        }
    }
    private var symbol: String {
        switch status {
        case .open: return "clock"
        case .accepted: return "checkmark"
        case .rejected: return "xmark"
        }
    }
    var body: some View {
        MemberScoreChipChrome(tone: tone, symbol: symbol) {
            memberScoreText("score.status.\(status.rawValue)")
        }
    }
}

struct MemberScoreChipChrome<Label: View>: View {
    let tone: CYStatusTone
    let symbol: String
    @ViewBuilder var label: () -> Label
    @Environment(\.cyPalette) private var palette

    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            Image(systemName: symbol).font(.caption2.weight(.bold)).accessibilityHidden(true)
            label().font(CYTypography.caption)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, CYSpacing.xs + 1)
        .background(Capsule(style: .continuous).fill(background))
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return palette.textSecondary
        case .success: return palette.success
        case .warning: return palette.warning
        case .danger: return palette.danger
        case .info: return palette.info
        }
    }
    private var background: Color {
        switch tone {
        case .neutral: return palette.actionSecondaryBg
        case .success: return palette.successSoft
        case .warning: return palette.warningSoft
        case .danger: return palette.dangerSoft
        case .info: return palette.infoSoft
        }
    }
}
