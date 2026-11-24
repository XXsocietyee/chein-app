import SwiftUI

@MainActor struct NativeChannelMessageBubbleView: View {
    @Environment(\.locale) private var locale
    let snapshot: NativeChannelMessageSnapshot
    let isCurrent: () -> Bool
    let locateOriginal: (NativeChannelMessageID) -> Void
    /// Existing owner consumes its own trusted poll/chain/card/attachment contracts.
    var videoOwner: IMVideoCoordinator? = nil
    var fileOwner: IMFileCoordinator? = nil
    var voiceOwner: IMVoiceCoordinator? = nil
    var attachmentPreview: NativeChannelAttachmentPreviewFlow? = nil
    var pollCoordinator: ((Int, GroupPollReference?) -> GroupPollCoordinator?)? = nil
    var chainCoordinator: ((Int, NativeChannelChainReference?) -> NativeChannelChainFlow?)? = nil
    var checkinCoordinator: ((Int) -> NativeChannelCheckinFlow?)? = nil
    var openExistingType: ((NativeChannelMessageSnapshot) -> Void)?
    @Environment(\.imRecipientPreview) private var recipientPreview
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if !isCurrent() { unavailable("message.unavailable") }
            else if snapshot.status == 1 { unavailable("message.recalled", symbol: "arrow.uturn.backward", tone: .warning) }
            else if snapshot.status != 0 { unavailable("message.unavailable") }
            else {
                if let quote = snapshot.reply { quoteRow(quote) }
                switch snapshot.kind {
                case .image:
                    imageBody
                    if let attachmentPreview {
                        openLink("attachment.open", identifier: nil) {
                            NativeChannelAttachmentPreviewEntry(flow: attachmentPreview, current: isCurrent)
                        }
                    } else { note("attachment.unavailable") }
                case .text, .poll:
                    MessagingMessageContent(message: snapshot.message)
                case .card:
                    if let day = NativeChannelCheckinReminder.day(in: snapshot) {
                        Label { Text("checkin.day \(day)", tableName: "NativeChannelMessage") } icon: { Image(systemName: "calendar.badge.checkmark").accessibilityHidden(true) }
                            .cyText(.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let checkinCoordinator {
                            openLink("checkin.open") {
                                NativeChannelCheckinLaunchView(makeFlow: { checkinCoordinator(snapshot.message.conversationID) },
                                    current: isCurrent, reminderDate: day)
                            }
                        } else { note("checkin.unavailable") }
                    } else { MessagingMessageContent(message: snapshot.message) }
                case .joined, .left, .renamed, .pinned, .pollResult:
                    systemLine
                case .location:
                    if let place = IMStaticLocation.read(snapshot.message) { IMStaticLocationCardView(place: place) }
                    else { note("location.unavailable") }
                case .voice:
                    if let voiceOwner, let ref = IMVoiceReference.read(snapshot.message) {
                        openCard(label: { IMVoiceCardLabel(reference: ref) }, destination: {
                            IMVoicePlaybackView(message: snapshot.message, owner: voiceOwner, current: isCurrent)
                        })
                    } else { note("voice.unavailable") }
                case .file:
                    if let fileOwner, let ref = IMFileReference.read(snapshot.message) {
                        openCard(label: { IMFileCardLabel(reference: ref) }, destination: {
                            IMFilePreviewView(message: snapshot.message, owner: fileOwner, current: isCurrent)
                        })
                    } else { note("file.unavailable") }
                case .video:
                    if let videoOwner, let ref = IMVideoReference.read(snapshot.message) {
                        openCard(label: { IMVideoCardLabel(reference: ref) }, destination: {
                            IMVideoPlaybackView(message: snapshot.message, owner: videoOwner, current: isCurrent)
                        })
                    } else { note("video.unavailable") }
                case .chain:
                    kindLine("type.14", symbol: "list.number")
                    verbatimBody
                    if let reference = NativeChannelChainReference(message: snapshot.message), let chainCoordinator {
                        openLink("chain.open", identifier: "ncm47.originalChain") {
                            NativeChannelChainLaunchView(makeFlow: { chainCoordinator(snapshot.message.conversationID, reference) }, current: isCurrent)
                        }
                    } else if let openExistingType {
                        openButton { if isCurrent() { openExistingType(snapshot) } }
                    } else { note("type.sourceRequired") }
                case .redPacket:
                    // Existing open path only. This restyle does not enable a payout or a new virtual-goods action.
                    kindLine("type.15", symbol: icon)
                    verbatimBody
                    if let openExistingType {
                        openButton { if isCurrent() { openExistingType(snapshot) } }
                    } else { note("type.sourceRequired") }
                case .unknown: note("type.unknown")
                }
                if let reference = snapshot.message.pollReference,
                   let owner = pollCoordinator?(snapshot.message.conversationID, reference),
                   owner.isCurrent, owner.reference == reference, owner.canRead {
                    openLink("poll.results", identifier: "ncm47.originalPollResult") {
                        GroupPollOriginalResultView(owner: owner, reference: reference, current: isCurrent)
                    }
                }
                if snapshot.editedAt != nil {
                    Label { Text("message.edited", tableName: "NativeChannelMessage") } icon: { Image(systemName: "pencil").accessibilityHidden(true) }
                        .cyText(.caption)
                        .foregroundStyle(CYColor.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            IMRecipientPreviewRow(message: snapshot.message, input: recipientPreview)
        }
        .cyText(.body)
        .privacySensitive()
        .accessibilityIdentifier("ncm47.message.\(snapshot.id.rawValue)")
    }

    private var imageBody: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            // Generated art only. No remote fetch: an image request can disclose the reader.
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay { CYCoverArt(seed: snapshot.id.rawValue, symbol: "photo") }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            MessagingMessageContent(message: snapshot.message)
        }
    }

    private var systemLine: some View {
        let raw = snapshot.content ?? copy("message.system")
        let shown = raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : raw
        return Text(verbatim: shown)
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var verbatimBody: some View {
        if let content = snapshot.content {
            let shown = content.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(verbatim: shown.isEmpty ? "—" : shown)
                .cyText(.body)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func kindLine(_ key: String, symbol: String) -> some View {
        Label { Text(LocalizedStringKey(key), tableName: "NativeChannelMessage") } icon: { Image(systemName: symbol).accessibilityHidden(true) }
            .cyText(.cardTitle)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(Text(LocalizedStringKey(key), tableName: "NativeChannelMessage"))
    }

    private func unavailable(_ key: String, symbol: String = "eye.slash", tone: CYStatusTone = .neutral) -> some View {
        CYStatusChip(verbatim: copy(key), tone: tone, systemImage: symbol)
            .accessibilityLabel(Text(verbatim: copy(key)))
    }

    private func note(_ key: String) -> some View {
        Text(LocalizedStringKey(key), tableName: "NativeChannelMessage")
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func quoteRow(_ quote: NativeChannelMessageQuote) -> some View {
        let shown = quote.summary ?? placeholder(quote.state)
        return Button { if isCurrent(), quote.state == "VISIBLE" { locateOriginal(quote.id) } } label: {
            Text(verbatim: shown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : shown)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, CYSpacing.md)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1, style: .continuous)
                        .fill(CYColor.borderStrong)
                        .frame(width: 2)
                        .accessibilityHidden(true)
                }
        }
        .buttonStyle(.plain)
        .disabled(quote.state != "VISIBLE")
        .accessibilityLabel(Text(verbatim: shown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : shown))
        .accessibilityIdentifier("ncm47.quote")
    }

    private func openButton(_ action: @escaping () -> Void) -> some View {
        CYPillButton("type.open", style: .secondary, fullWidth: false, tableName: "NativeChannelMessage", action: action)
            .accessibilityLabel(Text("type.open", tableName: "NativeChannelMessage"))
    }

    private func openLink<Destination: View>(_ key: String, identifier: String? = nil, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination) {
            Text(LocalizedStringKey(key), tableName: "NativeChannelMessage")
        }
        .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false))
        .accessibilityLabel(Text(LocalizedStringKey(key), tableName: "NativeChannelMessage"))
        .modifier(NativeChannelBubbleIdentifier(identifier: identifier))
    }

    /// Rich cards keep their own layout. The destination stays lazy. Press feedback respects Reduce Motion.
    private func openCard<Label: View, Destination: View>(@ViewBuilder label: () -> Label, @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink(destination: destination, label: label)
            .buttonStyle(.cyPressable)
    }

    private var icon: String {
        switch snapshot.kind { case .voice: return "waveform"; case .video: return "video"; case .file: return "doc"; case .location: return "mappin"; case .chain: return "list.number"; case .redPacket: return "gift"; default: return "bubble.left" }
    }
    private func copy(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(key), table: "NativeChannelMessage", locale: locale))
    }
    private func placeholder(_ state: String) -> String {
        switch state {
        case "BLOCKED": return copy("quote.blocked")
        case "RECALLED": return copy("message.recalled")
        default: return copy("message.unavailable")
        }
    }
}

private struct NativeChannelBubbleIdentifier: ViewModifier {
    let identifier: String?
    func body(content: Content) -> some View {
        if let identifier, !identifier.isEmpty { content.accessibilityIdentifier(identifier) }
        else { content }
    }
}
