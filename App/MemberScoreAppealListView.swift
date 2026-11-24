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
                    // MP shezhi 我的申诉 = icon_privacy (same tile as CYRowIcon).
                    AccountPublishMPRowIcon(MPAsset.FeatureIcon.iconPrivacy)
                    memberScoreText("score.mine.title")
                        .cyText(.cardTitle)
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
    @State private var showsSignIn = false
    @State private var showsReputation = false
    var body: some View {
        let rendered = readIntent()
        List {
            // PLY-30-2/4: inline bar title 我的申诉; no boundary subtitle.
            Picker(selection: $filter) {
                ForEach(MemberScoreAppealFilter.allCases) { memberScoreText("score.filter.\($0.rawValue)").tag($0) }
            } label: { memberScoreText("score.filter.title") }
            .pickerStyle(.segmented)
            .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            if let flow, flow.isCurrent {
                // PLY-30-1: the reputation row opens the mini-program 账号信誉 explanation; an unknown reputation is hidden.
                if let reputation = flow.reputation {
                    Button { showsReputation = true } label: {
                        HStack(spacing: CYSpacing.sm) {
                            MemberScoreChipChrome(tone: reputation == .normal ? .success : .warning, symbol: reputation == .normal ? "checkmark.seal" : "exclamationmark.triangle") {
                                memberScoreText("score.reputation.\(reputation.rawValue)")
                            }
                            Spacer(minLength: CYSpacing.sm)
                            Image(systemName: "info.circle").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                        }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityHint(Text("score.reputation.hint", tableName: "MemberScoreAppealList"))
                    .accessibilityIdentifier("score.mine.reputation")
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
                    CYEmptyState(systemImage: "text.bubble", LocalizedStringKey("score.mine.empty." + filter.rawValue), tableName: "MemberScoreAppealList")
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
                }
                if flow.loaded && !flow.rows.isEmpty && !flow.hasMore && !flow.busy {
                    // R7-MEM-30-1: MP appeal-mine footer 已经到底了.
                    Text("u9cde.report.end").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                        .accessibilityIdentifier("score.mine.end")
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
                    // PLY-30-3: mini-program 申诉记录加载失败 + 重试 in place.
                    CYEmptyState(systemImage: "exclamationmark.triangle", "score.mine.failed", tableName: "MemberScoreAppealList",
                                 detail: LocalizedStringKey("score.error." + String(describing: failure)), messageIdentifier: "score.mine.status",
                                 actionTitle: "score.mine.retry", actionIdentifier: "score.mine.retry", kind: .failure) { load(rendered) }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
                }
            } else if session.account == nil {
                // PLY-30-3: signed out → 登录后查看申诉 with a way to sign in.
                CYEmptyState(systemImage: "person.crop.circle", "score.mine.signIn", tableName: "MemberScoreAppealList",
                             actionTitle: "score.mine.signIn.action", actionIdentifier: "score.mine.signIn", actionStyle: .primary) { showsSignIn = true }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
            } else {
                CYEmptyState(systemImage: "exclamationmark.triangle", "score.mine.failed", tableName: "MemberScoreAppealList", kind: .failure)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal))
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberScoreText("score.mine.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .sheet(isPresented: $showsSignIn, onDismiss: { retire(); start() }) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showsReputation) { MemberScoreReputationSheet(current: flow?.reputation) }
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

/// Mini-program appeal-mine 账号信誉 sheet: what 正常 and 受限 mean for the player (PLY-30-1).
private struct MemberScoreReputationSheet: View {
    let current: MemberScoreReputation?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYSheetHeader(title: memberScoreText("score.reputation.sheet.title"), style: .player, onClose: { dismiss() })
            ForEach([MemberScoreReputation.normal, .restricted], id: \.rawValue) { value in
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    HStack(spacing: CYSpacing.sm) {
                        memberScoreText("score.reputation.sheet.\(value.rawValue)").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                        if value == current {
                            CYStatusChip("score.reputation.sheet.current", tone: value == .normal ? .success : .warning, tableName: "MemberScoreAppealList")
                        }
                    }
                    memberScoreText("score.reputation.sheet.\(value.rawValue).detail")
                        .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .padding(.horizontal, CYSpacing.pageHorizontal)
            }
            Spacer(minLength: 0)
        }
        .cyDomainSheet(detents: [.half])
    }
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
                // PLY-30-6: MP rp-row__head puts the title first and the status tag trailing.
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    CYRowIcon(systemImage: symbol)
                    copy
                    Spacer(minLength: CYSpacing.sm)
                    MemberScoreStatusChip(status: row.status)
                    if showsChevron {
                        Image(systemName: "chevron.right")
                            .cyText(.meta, weight: .semibold)
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
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: playerFactOrDash(row.title))
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: playerFactOrDash(row.createTime))
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
                .monospacedDigit()
                .fixedSize(horizontal: false, vertical: true)
            if !row.canReadSession {
                memberScoreText("score.detail.missingContext")
                    .cyText(.meta)
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
            Image(systemName: symbol).font(.caption.weight(.bold)).accessibilityHidden(true)
            label().cyText(.caption)
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
        case .rare: return palette.rare
        }
    }
    private var background: Color {
        switch tone {
        case .neutral: return palette.actionSecondaryBg
        case .success: return palette.successSoft
        case .warning: return palette.warningSoft
        case .danger: return palette.dangerSoft
        case .info: return palette.infoSoft
        case .rare: return palette.rareSoft
        }
    }
}
