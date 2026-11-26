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

/// A row tap lands on the play scoring screen only when the topic id is a positive integer.
private struct MemberScorePlayLayer: Hashable, Identifiable {
    let topicID: Int
    let sessionID: Int?
    var id: String { "\(topicID):\(sessionID.map(String.init) ?? "")" }
}

@MainActor struct MemberScoreAppealListView: View {
    @ObservedObject var session: AppSession
    @Environment(\.scenePhase) private var scene
    @Environment(\.locale) private var locale
    @State private var flow: MemberScoreAppealReadCoordinator?
    @State private var owner: MemberScoreReadPresentation?
    @State private var filter: MemberScoreAppealFilter = .all
    @State private var visible = false
    @State private var playLayer: MemberScorePlayLayer?
    @State private var showsSignIn = false
    @State private var showsReputation = false
    var body: some View {
        let rendered = readIntent()
        List {
            if let flow, flow.isCurrent {
                if let reputation = flow.reputation, flow.loaded, flow.failure == nil {
                    Button { showsReputation = true } label: {
                        MemberScoreReputationRow(reputation: reputation)
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("score.mine.reputation")
                    .listRowInsets(rowInsets)
                }
                if flow.failure != nil {
                    // The read did not return rows. Do not keep or invent any.
                    failedState { load(rendered) }
                } else if !flow.loaded {
                    listSkeleton
                } else if flow.rows.isEmpty {
                    emptyState("score.mine.empty.all")
                } else {
                    // Chips narrow the rows this read already returned. They do not ask again.
                    CYTabs(items: [
                        CYTabItem(id: MemberScoreAppealFilter.all, title: String(localized: LocalizedStringResource("score.filter.all", table: "MemberScoreAppealList", locale: locale))),
                        CYTabItem(id: MemberScoreAppealFilter.active, title: String(localized: LocalizedStringResource("score.filter.active", table: "MemberScoreAppealList", locale: locale))),
                        CYTabItem(id: MemberScoreAppealFilter.decided, title: String(localized: LocalizedStringResource("score.filter.decided", table: "MemberScoreAppealList", locale: locale))),
                    ], selection: $filter, variant: .chip)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .accessibilityIdentifier("score.mine.filter")
                    let shown = visibleRows(flow.rows)
                    if shown.isEmpty {
                        emptyState(filter == .decided ? "score.mine.empty.decided" : "score.mine.empty.active")
                    } else {
                        ForEach(shown) { row in
                            if let layer = MemberScorePlayLayer.opening(row) {
                                Button { playLayer = layer } label: {
                                    MemberScoreAppealMineRow(row: row, showsChevron: true)
                                }
                                .buttonStyle(.cyPressable)
                                .accessibilityIdentifier("score.mine.row.\(row.id)")
                                .listRowInsets(rowInsets)
                            } else {
                                MemberScoreAppealMineRow(row: row, showsChevron: false)
                                    .accessibilityIdentifier("score.mine.row.\(row.id)")
                                    .listRowInsets(rowInsets)
                            }
                        }
                        if !flow.busy {
                            Text("u9cde.report.end").cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                                .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                                .accessibilityIdentifier("score.mine.end")
                        }
                    }
                }
            } else if session.account == nil {
                // Signed out: 登录后查看申诉, primary 微信登录, through the existing sign-in.
                CYEmptyState(systemImage: "person.crop.circle", "score.mine.signIn", tableName: "MemberScoreAppealList",
                             messageIdentifier: "score.mine.signIn",
                             actionTitle: "auth.wechat.signIn", actionIdentifier: "score.mine.signIn", actionStyle: .primary) { showsSignIn = true }
                    .listRowBackground(Color.clear)
                    .listRowInsets(emptyInsets)
            } else {
                failedState { start() }
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberScoreText("score.mine.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .sheet(isPresented: $showsSignIn, onDismiss: { retire(); start() }) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .sheet(isPresented: $showsReputation) { MemberScoreReputationSheet() }
        .accessibilityIdentifier("score.mine.list")
        .navigationDestination(item: $playLayer) { layer in
            OrientScoreDeepLinkScreen(session: session, topicID: layer.topicID, sessionID: layer.sessionID)
        }
        .onAppear { visible = true; start() }
        .onDisappear { visible = false; retire() }
        .onChange(of: scene) { _, phase in retire(); if phase == .active { start() } }
        .onChange(of: session.memberScoreReadIdentity) { _, _ in playLayer = nil; retire(); start() }
        .refreshable { guard let (original, intent) = rendered else { return }; await original.loadList(intent: intent) }
        .cyDomainScreen(.player)
    }

    private var rowInsets: EdgeInsets {
        EdgeInsets(top: CYSpacing.sm, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal)
    }
    private var emptyInsets: EdgeInsets {
        EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.md, trailing: CYSpacing.pageHorizontal)
    }

    private var listSkeleton: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            ForEach(0..<3, id: \.self) { _ in CYSkeleton(variant: .row) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("score.mine.loading", tableName: "MemberScoreAppealList"))
        .listRowBackground(Color.clear)
        .listRowInsets(emptyInsets)
    }

    private func emptyState(_ key: String) -> some View {
        CYEmptyState(systemImage: "tray", LocalizedStringKey(key), tableName: "MemberScoreAppealList")
            .listRowBackground(Color.clear)
            .listRowInsets(emptyInsets)
    }

    private func failedState(_ retry: @escaping () -> Void) -> some View {
        CYEmptyState(systemImage: "exclamationmark.triangle", "score.mine.failed", tableName: "MemberScoreAppealList",
                     messageIdentifier: "score.mine.status",
                     actionTitle: "score.mine.retry", actionIdentifier: "score.mine.retry", kind: .failure, action: retry)
            .listRowBackground(Color.clear)
            .listRowInsets(emptyInsets)
    }

    /// Same split as the mini program: open stays in 处理中, accepted and rejected are 已有结论.
    private func visibleRows(_ rows: [MemberScoreAppealRow]) -> [MemberScoreAppealRow] {
        switch filter {
        case .all: return rows
        case .active: return rows.filter { $0.status == .open }
        case .decided: return rows.filter { $0.status != .open }
        }
    }

    private func start() {
        guard visible, scene == .active else { return }
        retire()
        guard let client = session.makeMemberScoreAppealListClient() else { return }
        let value = client.makeCoordinator()
        flow = value
        owner = value.beginList(filter: .all)
        load(readIntent())
    }
    private func readIntent() -> (MemberScoreAppealReadCoordinator, MemberScoreReadIntent)? {
        guard visible, scene == .active, let flow, let owner, let intent = flow.capture(owner) else { return nil }
        return (flow, intent)
    }
    private func load(_ read: (MemberScoreAppealReadCoordinator, MemberScoreReadIntent)?) {
        guard let (original, intent) = read, original.accepts(intent) else { return }
        Task { await original.loadList(intent: intent) }
    }
    private func retire() { if let owner { flow?.end(owner) }; flow = nil; owner = nil }
}

/// Mini-program appeal-mine 账号信誉 sheet: 正常 and 受限, with the sentence under each.
private struct MemberScoreReputationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYSheetHeader(title: memberScoreText("score.reputation.sheet.title"), style: .player, onClose: { dismiss() })
            ForEach([MemberScoreReputation.normal, .restricted], id: \.rawValue) { value in
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    memberScoreText("score.reputation.sheet.\(value.rawValue)")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                    memberScoreText("score.reputation.sheet.\(value.rawValue).detail")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                .padding(.horizontal, CYSpacing.pageHorizontal)
            }
            Spacer(minLength: 0)
        }
        .cyDomainSheet(detents: [.half])
    }
}

private struct MemberScoreReputationRow: View {
    let reputation: MemberScoreReputation

    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            memberScoreText("score.reputation.sheet.title")
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
            CYStatusChip(LocalizedStringKey(reputation == .normal ? "score.reputation.sheet.normal" : "score.reputation.sheet.restricted"),
                         tone: reputation == .normal ? .success : .neutral, tableName: "MemberScoreAppealList")
            Image(systemName: "chevron.right")
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// List row from appeal-mine view.js: kind title, status tag, and topic · day when either exists.
private struct MemberScoreAppealMineRow: View {
    let row: MemberScoreAppealRow
    var showsChevron: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                if typeSize.isAccessibilitySize {
                    title
                    tag
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                        title
                        Spacer(minLength: CYSpacing.sm)
                        tag
                    }
                }
                if let sub = memberScoreAppealSub(topicName: row.title, createTime: row.createTime, chinese: AppLanguage.interfaceIsChinese(locale)) {
                    Text(verbatim: sub)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if showsChevron {
                Image(systemName: "chevron.right")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        memberScoreText("score.kind.\(row.kind.rawValue)")
            .cyText(.body)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tag: some View {
        let tone: CYStatusTone
        let key: LocalizedStringKey
        switch row.status {
        case .open:
            tone = .info
            key = "score.status.open"
        case .accepted:
            tone = .success
            key = "score.status.accepted"
        case .rejected:
            tone = .neutral
            key = "score.status.rejected"
        }
        return CYStatusChip(key, tone: tone, tableName: "MemberScoreAppealList")
    }
}

extension MemberScorePlayLayer {
    /// topicId must be > 0. sessionId is passed only when it is also > 0.
    static func opening(_ row: MemberScoreAppealRow) -> MemberScorePlayLayer? {
        guard let topic = row.topicID, topic > 0, let topicID = Int(exactly: topic) else { return nil }
        let sessionID = row.sessionID.flatMap { value -> Int? in
            guard value > 0 else { return nil }
            return Int(exactly: value)
        }
        return MemberScorePlayLayer(topicID: topicID, sessionID: sessionID)
    }
}

/// `view.js` `dateText(timeText(createTime))`: month and day, or nothing when the value is not a date.
private func memberScoreAppealSub(topicName: String?, createTime: String?, chinese: Bool) -> String? {
    let topic = topicName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    let day = memberScoreAppealDay(createTime, chinese: chinese)
    let parts = [topic, day].filter { !$0.isEmpty }
    guard !parts.isEmpty else { return nil }
    return parts.joined(separator: " · ")
}

private func memberScoreAppealDay(_ raw: String?, chinese: Bool) -> String {
    guard let clock = memberScoreAppealClock(raw) else { return "" }
    guard let match = clock.range(of: #"^(\d{4})-(\d{2})-(\d{2})"#, options: .regularExpression) else { return "" }
    let head = String(clock[match])
    let pieces = head.split(separator: "-")
    guard pieces.count == 3, let month = Int(pieces[1]), let day = Int(pieces[2]),
          (1...12).contains(month), (1...31).contains(day) else { return "" }
    if chinese { return "\(month)月\(day)日" }
    return "\(memberScoreAppealEnglishMonth(month)) \(day)"
}

private func memberScoreAppealEnglishMonth(_ month: Int) -> String {
    let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    guard names.indices.contains(month - 1) else { return "" }
    return names[month - 1]
}

/// `report-common/view.js` `timeText`, enough to recover the calendar day the list prints.
private func memberScoreAppealClock(_ raw: String?) -> String? {
    guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
    if trimmed.range(of: #"[zZ]$|[+-]\d{2}:?\d{2}$"#, options: .regularExpression) != nil {
        return memberScoreAppealZonedClock(trimmed)
    }
    if let range = trimmed.range(of: #"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}"#, options: .regularExpression) {
        let matched = String(trimmed[range])
        return String(matched.prefix(10)) + " " + String(matched.suffix(5))
    }
    return trimmed
}

private func memberScoreAppealZonedClock(_ raw: String) -> String? {
    var normalized = raw
    if let range = raw.range(of: #"([+-])(\d{2})(\d{2})$"#, options: .regularExpression) {
        let piece = String(raw[range])
        if !piece.contains(":") {
            normalized.replaceSubrange(range, with: "\(piece.prefix(3)):\(piece.suffix(2))")
        }
    }
    let withFraction = ISO8601DateFormatter()
    withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    plain.formatOptions = [.withInternetDateTime]
    guard let date = withFraction.date(from: normalized) ?? plain.date(from: normalized) else { return nil }
    let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day, let hour = parts.hour, let minute = parts.minute else { return nil }
    return String(format: "%04d-%02d-%02d %02d:%02d", year, month, day, hour, minute)
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
