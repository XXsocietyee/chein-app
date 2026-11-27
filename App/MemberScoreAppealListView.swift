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
                // MP shezhi 我的申诉 = icon_privacy.
                Label { memberScoreText("score.mine.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconPrivacy) }
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
                // mp-mine r3: MP appeal-mine keeps 账号信誉 above every list state (loading, error, empty) with an arrow.
                if let reputation = flow.reputation {
                    Button { showsReputation = true } label: {
                        HStack {
                            MemberScoreReputationRow(reputation: reputation)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary).accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("score.mine.reputation")
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
                    Picker(selection: $filter) {
                        memberScoreText("score.filter.all").tag(MemberScoreAppealFilter.all)
                        memberScoreText("score.filter.active").tag(MemberScoreAppealFilter.active)
                        memberScoreText("score.filter.decided").tag(MemberScoreAppealFilter.decided)
                    } label: {
                        memberScoreText("score.mine.title")
                    }
                    .cyAdaptiveSegmented()
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
                                .accessibilityIdentifier("score.mine.row.\(row.id)")
                            } else {
                                MemberScoreAppealMineRow(row: row, showsChevron: false)
                                    .accessibilityIdentifier("score.mine.row.\(row.id)")
                            }
                        }
                        if !flow.busy {
                            Text("u9cde.report.end").font(.footnote).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("score.mine.end")
                        }
                    }
                }
            } else if session.account == nil {
                // Signed out: 登录后查看申诉, primary 微信登录, through the existing sign-in.
                ContentUnavailableView {
                    Label { memberScoreText("score.mine.signIn") } icon: { Image(systemName: "person.crop.circle") }
                } actions: {
                    Button { showsSignIn = true } label: { Text("auth.wechat.signIn") }
                        .buttonStyle(.borderedProminent).controlSize(.large)
                        .accessibilityIdentifier("score.mine.signIn")
                }
            } else {
                failedState { start() }
            }
        }
        .listStyle(.insetGrouped)
        .cyPushedChrome(domain: .player)
        .navigationTitle(memberScoreText("score.mine.title")).navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
        .cySheet(isPresented: $showsSignIn, onDismiss: { retire(); start() }) { Group { LoginView(intent: .player).environmentObject(session) }.presentationDetents([.large]).presentationDragIndicator(.visible) }
        .cySheet(isPresented: $showsReputation) { MemberScoreReputationSheet() }
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

    private var listSkeleton: some View {
        ProgressView()
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("score.mine.loading", tableName: "MemberScoreAppealList"))
    }

    private func emptyState(_ key: String) -> some View {
        ContentUnavailableView {
            Label { memberScoreText(key) } icon: { Image(systemName: "tray") }
        }
    }

    private func failedState(_ retry: @escaping () -> Void) -> some View {
        ContentUnavailableView {
            Label {
                memberScoreText("score.mine.failed").accessibilityIdentifier("score.mine.status")
            } icon: { Image(systemName: "exclamationmark.triangle") }
        } actions: {
            Button(action: retry) { memberScoreText("score.mine.retry") }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("score.mine.retry")
        }
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
        NavigationStack {
            List {
                ForEach([MemberScoreReputation.normal, .restricted], id: \.rawValue) { value in
                    VStack(alignment: .leading, spacing: 2) {
                        memberScoreText("score.reputation.sheet.\(value.rawValue)")
                        memberScoreText("score.reputation.sheet.\(value.rawValue).detail")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(memberScoreText("score.reputation.sheet.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct MemberScoreReputationRow: View {
    let reputation: MemberScoreReputation

    var body: some View {
        LabeledContent {
            memberScoreText(reputation == .normal ? "score.reputation.sheet.normal" : "score.reputation.sheet.restricted")
                .foregroundStyle(reputation == .normal ? Color.green : Color.secondary)
        } label: {
            memberScoreText("score.reputation.sheet.title")
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if typeSize.isAccessibilitySize {
                    title
                    tag
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        title
                        Spacer(minLength: 8)
                        tag
                    }
                }
                if let sub = memberScoreAppealSub(topicName: row.title, createTime: row.createTime, chinese: AppLanguage.interfaceIsChinese(locale)) {
                    Text(verbatim: sub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if showsChevron {
                // The row opens a pushed screen from a Button, so it draws the system-style disclosure glyph itself.
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var title: some View {
        memberScoreText("score.kind.\(row.kind.rawValue)")
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var tag: some View {
        let tone: Color
        let key: LocalizedStringKey
        switch row.status {
        case .open:
            tone = .blue
            key = "score.status.open"
        case .accepted:
            tone = .green
            key = "score.status.accepted"
        case .rejected:
            tone = .secondary
            key = "score.status.rejected"
        }
        return Text(key, tableName: "MemberScoreAppealList").font(.footnote).foregroundStyle(tone)
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
        HStack(spacing: 4) {
            Image(systemName: symbol).accessibilityHidden(true)
            label()
        }
        .font(.footnote)
        .foregroundStyle(foreground)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }

    private var foreground: Color {
        switch tone {
        case .neutral: return .secondary
        case .success: return .green
        case .warning: return .orange
        case .danger: return .red
        case .info: return .blue
        case .rare: return .indigo
        }
    }
}
