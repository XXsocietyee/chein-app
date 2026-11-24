import SwiftUI

/// What the conversation is allowed to show before a lease is asked to issue.
enum IMRecipientPreviewPhase: Equatable {
    case loading
    case empty
    case error
    case refused
    case ready
}

/// Leases the conversation may ask. An empty list is a closed lease.
struct IMRecipientPreviewInput: Equatable {
    var phase: IMRecipientPreviewPhase
    var leases: [IMPreviewTemplateLease]
    var now: Date

    static let closed = IMRecipientPreviewInput(phase: .ready, leases: [], now: Date(timeIntervalSince1970: 0))
}

enum IMRecipientPreviewKind: Equatable {
    case loading
    case empty
    case error
    case refused
    case closed
    case issued
}

struct IMRecipientPreviewLine: Equatable, Identifiable {
    let slot: String
    let kind: IMRecipientPreviewKind
    /// Concrete path only after `issue` returns a route. A nil result stays an em dash.
    let value: String
    var id: String { slot }

    static let dash = "—"
}

/// Issues the six GET recipient-preview templates for one decoded message.
enum IMRecipientPreviewBoard {
    static func lines(message: MessagingMessage, input: IMRecipientPreviewInput) -> [IMRecipientPreviewLine] {
        IMPreviewRouteTemplates.all.map { template in
            Self.line(message: message, template: template, input: input)
        }
    }

    /// `messageConversationID` is the decoded message's conversation. The screen route,
    /// the lease cache, and any other message are not arguments here.
    static func issuedRoute(message: MessagingMessage, lease: IMPreviewTemplateLease, now: Date) -> BusinessRuntimeRoute? {
        let template = lease.template
        guard let path = template.concretePath(for: Int64(message.id)) else { return nil }
        return lease.issue(
            method: template.method,
            path: path,
            messageID: Int64(message.id),
            messageConversationID: Int64(message.conversationID),
            viewer: lease.viewer,
            now: now
        )
    }

    private static func line(message: MessagingMessage, template: BusinessRuntimeRouteTemplate, input: IMRecipientPreviewInput) -> IMRecipientPreviewLine {
        let feature = template.feature
        switch input.phase {
        case .loading:
            return make(feature, .loading, issuedPath: nil)
        case .empty:
            return make(feature, .empty, issuedPath: nil)
        case .error:
            return make(feature, .error, issuedPath: nil)
        case .refused:
            return make(feature, .refused, issuedPath: nil)
        case .ready:
            break
        }
        let matched = input.leases.first { $0.template == template }
        guard let matched else {
            return make(feature, .closed, issuedPath: nil)
        }
        let route = Self.issuedRoute(message: message, lease: matched, now: input.now)
        if matched.conversationID != Int64(message.conversationID) {
            return make(feature, .refused, issuedPath: nil)
        }
        if let issued = route {
            return make(feature, .issued, issuedPath: issued.path)
        }
        return make(feature, .closed, issuedPath: nil)
    }

    private static func make(_ feature: BusinessRuntimeFeature, _ kind: IMRecipientPreviewKind, issuedPath: String?) -> IMRecipientPreviewLine {
        let shown = displayValue(kind: kind, issuedPath: issuedPath)
        let resolved: IMRecipientPreviewKind = kind == .issued && shown == IMRecipientPreviewLine.dash ? .closed : kind
        return IMRecipientPreviewLine(slot: slot(feature), kind: resolved, value: shown)
    }

    private static func displayValue(kind: IMRecipientPreviewKind, issuedPath: String?) -> String {
        guard kind == .issued else { return IMRecipientPreviewLine.dash }
        guard let concrete = issuedPath else { return IMRecipientPreviewLine.dash }
        guard concrete.isEmpty == false else { return IMRecipientPreviewLine.dash }
        return concrete
    }

    private static func slot(_ feature: BusinessRuntimeFeature) -> String {
        switch feature {
        case .imFilePreviewStatus: return "file-authorization"
        case .imFilePreview: return "file-preview"
        case .imVideoPreviewStatus: return "video-authorization"
        case .imVideoPreview: return "video-preview"
        case .imVoicePlayback: return "voice-message"
        case .imVoicePlaybackStatus: return "voice-authorization"
        default: return "other"
        }
    }

}

private struct IMRecipientPreviewKey: EnvironmentKey {
    static let defaultValue = IMRecipientPreviewInput.closed
}

/// Leases for one server conversation id, one per template; nil when previews are not granted (fixtures, guests).
private struct IMRecipientPreviewLeasesKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int64) -> [IMPreviewTemplateLease])? = nil
}

extension EnvironmentValues {
    var imRecipientPreviewLeases: (@MainActor (Int64) -> [IMPreviewTemplateLease])? {
        get { self[IMRecipientPreviewLeasesKey.self] }
        set { self[IMRecipientPreviewLeasesKey.self] = newValue }
    }
}

extension AppSession {
    /// E2E-20261113b N1. One lease per GET template for the signed-in viewer and a server-provided conversation id.
    /// Nil unless the reviewed China player grant is on; the lease factory refuses other roles and ids.
    var imRecipientPreviewLeaseSource: (@MainActor (Int64) -> [IMPreviewTemplateLease])? {
        guard composition.reviewed?.playerWritesEnabled == true, composition.reviewed?.regional.market == .china else { return nil }
        return { [weak self] conversationID in
            guard let self, let context = self.currentRuntimeDependencyContext else { return [] }
            return ReviewedProductionGateLeases.imPreviewTemplates.compactMap {
                self.composition.productionGateLeases.imPreviewLease(context, conversationID: conversationID, template: $0)
            }
        }
    }
}

extension EnvironmentValues {
    var imRecipientPreview: IMRecipientPreviewInput {
        get { self[IMRecipientPreviewKey.self] }
        set { self[IMRecipientPreviewKey.self] = newValue }
    }
}

/// One visible row per GET template, on the decoded message. A closed lease and a nil
/// `issue` result show an em dash and are not a successful preview.
struct IMRecipientPreviewRow: View {
    let message: MessagingMessage
    let input: IMRecipientPreviewInput
    @Environment(\.imPreviewInk) private var ink

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text("im.preview.section", tableName: "IMRecipientPreview")
                .cyText(.body)
                .foregroundStyle(ink.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint(Text("curA11y.imPreview.hint", tableName: "CurA11y"))
            ForEach(IMRecipientPreviewBoard.lines(message: message, input: input)) { line in
                IMRecipientPreviewLineView(line: line, messageID: message.id)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("im.preview.\(message.id)")
    }
}

private struct IMRecipientPreviewLineView: View {
    let line: IMRecipientPreviewLine
    let messageID: Int
    @Environment(\.imPreviewInk) private var ink

    var body: some View {
        CurA11yPair(leading: titleBlock, trailing: valueBlock)
            .frame(minHeight: CurA11y.hit, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("curA11y.imPreview.hint", tableName: "CurA11y"))
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("im.preview.line.\(messageID).\(line.slot)")
    }

    private var titleBlock: some View {
        title
            .cyText(.body)
            .foregroundStyle(ink.secondary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var valueBlock: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            stateLabel
                .cyText(.meta)
                .foregroundStyle(ink.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            if line.kind == .issued {
                issuedValueText
                    .cyText(.meta)
                    .foregroundStyle(ink.primary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                CurA11yDashText(shown: line.value, font: CYTypography.meta, color: ink.primary)
            }
        }
    }

    @ViewBuilder private var issuedValueText: some View {
        switch line.slot {
        case "file-authorization":
            Text("im.preview.issued.fileAuthorization", tableName: "IMRecipientPreview")
        case "file-preview":
            Text("im.preview.issued.file", tableName: "IMRecipientPreview")
        case "video-authorization":
            Text("im.preview.issued.videoAuthorization", tableName: "IMRecipientPreview")
        case "video-preview":
            Text("im.preview.issued.video", tableName: "IMRecipientPreview")
        case "voice-message":
            Text("im.preview.issued.voice", tableName: "IMRecipientPreview")
        case "voice-authorization":
            Text("im.preview.issued.voiceAuthorization", tableName: "IMRecipientPreview")
        default:
            Text("im.preview.ready", tableName: "IMRecipientPreview")
        }
    }

    @ViewBuilder private var title: some View {
        switch line.slot {
        case "file-authorization":
            Text("im.preview.fileAuthorization", tableName: "IMRecipientPreview")
        case "file-preview":
            Text("im.preview.file", tableName: "IMRecipientPreview")
        case "video-authorization":
            Text("im.preview.videoAuthorization", tableName: "IMRecipientPreview")
        case "video-preview":
            Text("im.preview.video", tableName: "IMRecipientPreview")
        case "voice-message":
            Text("im.preview.voice", tableName: "IMRecipientPreview")
        case "voice-authorization":
            Text("im.preview.voiceAuthorization", tableName: "IMRecipientPreview")
        default:
            Text("im.preview.other", tableName: "IMRecipientPreview")
        }
    }

    @ViewBuilder private var stateLabel: some View {
        switch line.kind {
        case .loading:
            Text("im.preview.loading", tableName: "IMRecipientPreview")
        case .empty:
            Text("im.preview.empty", tableName: "IMRecipientPreview")
        case .error:
            Text("im.preview.error", tableName: "IMRecipientPreview")
        case .refused:
            Text("im.preview.refused", tableName: "IMRecipientPreview")
        case .closed:
            Text("im.preview.notIssued", tableName: "IMRecipientPreview")
        case .issued:
            Text("im.preview.ready", tableName: "IMRecipientPreview")
        }
    }
}

/// The ink the preview row draws with. Inside a sent bubble (light fill on the dark player page) the page's text tokens
/// were light grey on near-white and the issued values white on near-white (combined-r4 verify), so the bubble hands
/// its own ink down (one ink: the lint keeps opacity off text, and there is no secondary-on-sent token).
struct IMPreviewInk {
    let primary: Color
    let secondary: Color
    static let page = IMPreviewInk(primary: CYColor.textPrimary, secondary: CYColor.textSecondary)
    static let sent = IMPreviewInk(primary: CYChat.onSent, secondary: CYChat.onSent)
}

private struct IMPreviewInkKey: EnvironmentKey { static let defaultValue = IMPreviewInk.page }

extension EnvironmentValues {
    var imPreviewInk: IMPreviewInk {
        get { self[IMPreviewInkKey.self] }
        set { self[IMPreviewInkKey.self] = newValue }
    }
}
