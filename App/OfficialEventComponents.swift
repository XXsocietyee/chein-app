import SwiftUI

enum OfficialScreenIssue {
    case unconfigured, unauthorized, noPublisherPermission, forbidden, unavailable, failed
    init(_ error: Error) {
        switch error {
        case APIError.notConfigured: self = .unconfigured
        case APIError.unauthorized: self = .unauthorized
        case OfficialReadFailure.noPublisherPermission: self = .noPublisherPermission
        case OfficialReadFailure.forbidden: self = .forbidden
        case OfficialReadFailure.unavailable: self = .unavailable
        default: self = .failed
        }
    }
    var key: LocalizedStringKey {
        switch self {
        case .unconfigured: return "official.notConfigured"
        case .unauthorized: return "official.signInRequired"
        case .noPublisherPermission: return "official.noPublisherPermission"
        case .forbidden: return "official.forbidden"
        case .unavailable: return "official.unavailable"
        case .failed: return "official.failed"
        }
    }
}
/// Page-specific failure wording above the shared issue label; nil keeps the label alone.
struct OfficialIssueCopy {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var identifier = ""
    var backTitle: LocalizedStringKey? = nil
    var backIdentifier = ""
}
struct OfficialIssueView: View {
    let issue: OfficialScreenIssue
    var onLogin: (() -> Void)?
    var retry: (() -> Void)?
    var copy: OfficialIssueCopy? = nil
    var onBack: (() -> Void)? = nil
    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            if let copy {
                VStack(alignment: .leading, spacing: 8) {
                    Text(copy.title).cyText(.cardTitle).accessibilityIdentifier(copy.identifier)
                    Text(copy.detail).foregroundStyle(.secondary)
                }.fixedSize(horizontal: false, vertical: true)
            }
            Label(issue.key, systemImage: symbol).font(copy == nil ? .headline : .footnote)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("official.issue")
            if case .unauthorized = issue, let onLogin {
                Button("official.signIn", action: onLogin).frame(minHeight: 44)
                    .accessibilityIdentifier("official.signIn")
            } else if case .failed = issue, let retry {
                Button("official.retry", action: retry).frame(minHeight: 44)
                    .accessibilityIdentifier("official.retry")
            } else if case .unavailable = issue, let onBack, let copy, let backTitle = copy.backTitle {
                // An unrecoverable read offers only the way back, never a retry.
                Button(backTitle, action: onBack).frame(minHeight: 44)
                    .accessibilityIdentifier(copy.backIdentifier)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
            .padding(20).modifier(OfficialFlowActions())
            .accessibilityElement(children: .contain)
        }
    }
    private var symbol: String {
        switch issue {
        case .unauthorized, .noPublisherPermission, .forbidden: return "lock.shield"
        case .failed: return "exclamationmark.triangle"
        case .unavailable: return "doc.questionmark"
        case .unconfigured: return "info.circle"
        }
    }
}

/// A fresh key hides old data before the next task starts. Generation guards also reject
/// overlapping refreshes and completions after navigation dismissal. The host must redraw
/// its subtree for any session epoch/token/account change, including guest transitions.
@MainActor struct OfficialReadScreen<Value, Content: View>: View {
    let reader: any OfficialEventReading
    var isPrivate = false
    var requestID = ""
    var onLogin: (() -> Void)? = nil
    var issueCopy: ((Error) -> OfficialIssueCopy?)? = nil
    var onBack: (() -> Void)? = nil
    let load: () async throws -> Value
    @ViewBuilder let content: (Value) -> Content
    @StateObject private var sourceObservation = OfficialReadInvalidationObserver()
    @State private var value: Value?
    @State private var issue: OfficialScreenIssue?
    @State private var copy: OfficialIssueCopy?
    @State private var loadedKey: Key?
    @State private var generation: UInt64 = 0
    @State private var loading = false
    /// PC-C-3-2: a pull on loaded content keeps the cards (MP 正在更新活动列表…) instead of blanking them.
    @State private var refreshing = false
    @State private var refreshFailed = false
    private struct Key: Hashable {
        let scope: UUID
        let configured: Bool
        let authenticated: Bool
        let requestID: String
        let isPrivate: Bool
    }
    private var key: Key {
        Key(scope: reader.scope, configured: reader.isConfigured, authenticated: reader.isAuthenticated,
            requestID: requestID, isPrivate: isPrivate)
    }
    private var isShowingLoad: Bool {
        if isPrivate && !reader.isAuthenticated { return false }
        return reader.isConfigured && (loadedKey != key || loading)
    }
    var body: some View {
        // Own loading/cancellation on a stable container, not Group's changing
        // branches, which can restart the initial read when an error appears.
        CYLoadSlot(isLoading: isShowingLoad, label: "official.loading", announces: true) {
            ZStack(alignment: .topLeading) {
                if isPrivate && !reader.isAuthenticated { OfficialIssueView(issue: .unauthorized, onLogin: onLogin) }
                else if !reader.isConfigured { OfficialIssueView(issue: .unconfigured) }
                else if loadedKey != key || loading { Color.clear }
                else if let issue { OfficialIssueView(issue: issue, onLogin: onLogin, retry: { Task { await refresh() } }, copy: copy, onBack: onBack) }
                else if let value {
                    VStack(alignment: .leading, spacing: 0) {
                        if refreshing || refreshFailed {
                            Text(refreshing ? "official.refreshing" : "official.refreshFailed")
                                .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                .padding(.horizontal).padding(.vertical, CYSpacing.xs)
                                .accessibilityIdentifier(refreshing ? "official.refreshing" : "official.refreshFailed")
                        }
                        content(value)
                    }
                }
            }
        }
        .task(id: key) { await refresh() }
        .refreshable { await refresh() }
        .onDisappear { generation &+= 1; loading = false }
        .onDisappear { refreshing = false }
        .onAppear { sourceObservation.bind(reader) }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in sourceObservation.bind(reader) }
        .onChange(of: sourceObservation.revision) { _, _ in
            guard sourceObservation.isBound(to: reader) else { return }
            // A new-key task may already own loading. Retire only the previous
            // content; the existing keyed task owns cancellation and refetch.
            guard loadedKey != key else { return }
            value = nil; issue = nil; copy = nil; loadedKey = nil
        }
        .onDisappear { sourceObservation.stop() }
    }
    private func refresh() async {
        generation &+= 1
        let operation = generation, captured = key
        // PC-C-3-2: same key with cards on screen → keep them and show one 正在更新… line; any other case starts blank.
        let keeps = loadedKey == captured && value != nil && issue == nil
        refreshFailed = false; refreshing = false
        if !keeps {
            value = nil; issue = nil; loadedKey = nil; loading = false
            copy = nil
        }
        guard reader.isConfigured, !isPrivate || reader.isAuthenticated else { return }
        if keeps { refreshing = true } else { loading = true }
        defer { if generation == operation { loading = false; refreshing = false } }
        do {
            let result = try await load()
            guard !Task.isCancelled, generation == operation, key == captured else { return }
            value = result; loadedKey = captured
        } catch {
            guard !Task.isCancelled, !(error is CancellationError), generation == operation, key == captured else { return }
            // A failed pull keeps the cards (MP toast 刷新失败，稍后再试); a failed first load shows the issue.
            if keeps { refreshFailed = true; return }
            copy = issueCopy?(error)
            issue = OfficialScreenIssue(error); loadedKey = captured
        }
    }
}
struct OfficialReadOnlyNotice: View {
    let offline: Bool
    var body: some View {
        // Unavailable actions are simply absent; only the example-content marker remains.
        if offline {
            Label("official.offlineExample", systemImage: "info.circle")
                .cyText(.bodyCompact).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
struct OfficialEventCard: View {
    let event: OfficialEvent
    var body: some View {
        QuestifyImageEntityCard(imageSource: event.coverImage, title: event.title, subtitle: event.subtitle,
                                fallbackTitle: "official.untitled", fallbackSymbol: "sparkles") {
            // R7-PC-C3-2 (MP list/index.wxml:57 `cy-badge type="status"`): tone follows the status, `play` when live.
            CYStatusChip(LocalizedStringKey(event.statusKey), tone: OfficialEventStatusStyle.tone(event.status),
                         systemImage: OfficialEventStatusStyle.symbol(event.status))
            if event.paused { Label("official.status.paused", systemImage: "pause.circle").foregroundStyle(CYColor.warningText) }
            if event.recruitmentBlocked == true {
                VStack(alignment: .leading, spacing: 4) {
                    Label("official.informationIncomplete", systemImage: "exclamationmark.triangle")
                        .fontWeight(.semibold)
                    if let reason = event.recruitmentWarningReason { Text(verbatim: reason) }
                    else { Text("official.informationReasonUnknown") }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
            if let city = event.city, !city.isEmpty {
                QuestifyImageEntityMetadata(label: "official.city", value: city, systemImage: "mappin")
            }
            // Source card meta: countdown · city · "N 人参与", then "全城已点亮 N%".
            if let countdown = event.countdown(now: Date()) { OfficialCountdownText(value: countdown) }
            // Source: "{{participants != null ? n + ' 人' : '—'}}参与"; a missing count is an em dash, never 0.
            if let participants = event.participants { Text("official.card.participants \(participants)") }
            else { Text("official.card.participantsUnknown") }
            if event.collectivePercentShown {
                if let percent = event.collective?.percent {
                    ProgressView(value: Double(min(100, max(0, percent))), total: 100).tint(CYColor.brand).accessibilityHidden(true)
                    Text("official.card.collective \(min(100, max(0, percent)))")
                }
                else { Text("official.card.collectiveUnknown") }
            }
        }
    }
}

/// Local O01 styling. It reads the existing caller domain and changes no access or action state.
struct OfficialFlowSurface: ViewModifier {
    @Environment(\.themeDomain) private var domain
    func body(content: Content) -> some View {
        content.cyText(.body).listStyle(.insetGrouped).formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(Theme.Generated.color("--cy-color-bg-page", in: domain) ?? Color(uiColor: .systemGroupedBackground))
            .tint(Theme.Generated.color("--cy-color-brand", in: domain) ?? Color.accentColor)
            .preferredColorScheme(domain.colorScheme)
    }
}

struct OfficialFlowNotice: View {
    let text: String
    var symbol = "info.circle"
    var body: some View {
        Label { Text(verbatim: text).fixedSize(horizontal: false, vertical: true) }
            icon: { Image(systemName: symbol).accessibilityHidden(true) }
            .font(.footnote).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12).background(.quaternary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

struct OfficialFlowActions: ViewModifier {
    func body(content: Content) -> some View {
        content.buttonStyle(.bordered).controlSize(.large)
            .multilineTextAlignment(.leading)
    }
}
struct OfficialCountdownText: View {
    let value: OfficialEventCountdown
    var body: some View {
        switch value {
        case .startsIn(let span): Label { prefix("official.countdown.start", span) } icon: { Image(systemName: "clock").accessibilityHidden(true) }
        case .endsIn(let span): Label { prefix("official.countdown.end", span) } icon: { Image(systemName: "clock").accessibilityHidden(true) }
        case .startingSoon: Label("official.countdown.startingSoon", systemImage: "clock")
        case .endingSoon: Label("official.countdown.endingSoon", systemImage: "clock")
        }
    }
    private func prefix(_ key: LocalizedStringKey, _ span: OfficialCountdownSpan) -> Text {
        switch span {
        case .days(let n): return Text(key) + Text(verbatim: " ") + Text("official.countdown.days \(n)")
        case .hours(let n): return Text(key) + Text(verbatim: " ") + Text("official.countdown.hours \(n)")
        case .minutes(let n): return Text(key) + Text(verbatim: " ") + Text("official.countdown.minutes \(n)")
        case .unknown: return Text("official.notAnnounced")
        }
    }
}
struct OfficialEventTimeValue: View {
    let value: OfficialEventTime?
    var body: some View {
        switch value {
        case .text(let text): Text(verbatim: text)
        case .milliseconds:
            if let date = value?.displayDate {
                Text(date, format: .dateTime.year().month().day().hour().minute())
            } else { Text("official.notAnnounced") }
        case nil: Text("official.notAnnounced")
        }
    }
}

/// Functional footer only; system safe-area insets reserve space above the home indicator.
struct OfficialFlowActionBar<Content: View>: View {
    @Environment(\.themeDomain) private var domain
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { content }
            .frame(maxWidth: .infinity).padding(.horizontal, 16).padding(.vertical, 12)
            .controlSize(.large).background(.bar)
            .tint(Theme.Generated.color("--cy-color-brand", in: domain) ?? Color.accentColor)
            .preferredColorScheme(domain.colorScheme)
    }
}

/// Original identifiers remain selectable and fully readable, including long hashes.
struct OfficialRecordValue: View {
    let title: LocalizedStringKey
    let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).cyText(.meta).foregroundStyle(.secondary)
            Text(verbatim: value).font(.footnote.monospaced()).lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
    }
}

/// MP `utils/activity-status.js` STATUS table (variant + live) for `official_event.status`.
enum OfficialEventStatusStyle {
    static func tone(_ status: Int?) -> CYStatusTone {
        switch status {
        case 2: return .info
        case 3: return .success
        default: return .neutral
        }
    }
    /// MP `icon="{{item._live ? 'play' : ''}}"`: 报名中 / 进行中 carry the play glyph; other states have none.
    static func symbol(_ status: Int?) -> String? { status == 2 || status == 3 ? "play.fill" : nil }
}
