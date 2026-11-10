import SwiftUI

@MainActor struct NativeChannelMessageBubbleView: View {
    @Environment(\.locale) private var locale
    @Environment(\.themeDomain) private var domain
    @Environment(\.dynamicTypeSize) private var typeSize
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
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s1_5) {
            if !isCurrent() { CYStatusChip(verbatim: String(localized: "message.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "lock") }
            else if snapshot.status == 1 { CYStatusChip(verbatim: String(localized: "message.recalled", table: "NativeChannelMessage"), tone: .neutral, systemImage: "arrow.uturn.backward") }
            else if snapshot.status != 0 { CYStatusChip(verbatim: String(localized: "message.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "lock") }
            else {
                if let quote = snapshot.reply {
                    Button { if isCurrent(), quote.state == "VISIBLE" { locateOriginal(quote.id) } } label: {
                        Text(quote.summary ?? placeholder(quote.state))
                            .font(Theme.Font.label)
                            .foregroundStyle(.secondary)
                            .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.leading, Theme.Space.s3)
                            .frame(minHeight: 44, alignment: .leading)
                            .overlay(alignment: .leading) { Rectangle().fill(Theme.Color.borderSubtle(in: domain)).frame(width: 2).accessibilityHidden(true) }
                    }.disabled(quote.state != "VISIBLE")
                    .accessibilityIdentifier("ncm47.quote")
                }
                switch snapshot.kind {
                case .image:
                    MessagingMessageContent(message: snapshot.message)
                    if let attachmentPreview {
                        NavigationLink { NativeChannelAttachmentPreviewEntry(flow:attachmentPreview,current:isCurrent) } label: { Text("attachment.open", tableName: "NativeChannelMessage") }
                    } else { CYStatusChip(verbatim: String(localized: "attachment.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "photo") }
                case .text, .poll:
                    MessagingMessageContent(message: snapshot.message)
                case .card:
                    if let day = NativeChannelCheckinReminder.day(in: snapshot) {
                        Label { Text("checkin.day \(day)", tableName: "NativeChannelMessage") } icon: { Image(systemName: "calendar.badge.checkmark") }
                        if let checkinCoordinator {
                            NavigationLink {
                                NativeChannelCheckinLaunchView(makeFlow: { checkinCoordinator(snapshot.message.conversationID) },
                                    current: isCurrent, reminderDate: day)
                            } label: { Text("checkin.open", tableName: "NativeChannelMessage") }
                        } else { CYStatusChip(verbatim: String(localized: "checkin.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "calendar") }
                    } else { MessagingMessageContent(message: snapshot.message) }
                case .joined, .left, .renamed, .pinned, .pollResult:
                    Text(snapshot.content ?? String(localized: LocalizedStringResource("message.system", table: "NativeChannelMessage", locale: locale)))
                        .font(Theme.Font.label).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                case .location:
                    if let place=IMStaticLocation.read(snapshot.message) { IMStaticLocationCardView(place:place) }
                    else { CYStatusChip(verbatim: String(localized: "location.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "mappin.slash") }
                case .voice:
                    if let voiceOwner, IMVoiceReference.read(snapshot.message) != nil {
                        if let ref = IMVoiceReference.read(snapshot.message) {
                            NavigationLink { IMVoicePlaybackView(message: snapshot.message, owner: voiceOwner, current: isCurrent) } label: { IMVoiceCardLabel(reference: ref) }.buttonStyle(E3PressStyle())
                        }
                    } else { CYStatusChip(verbatim: String(localized: "voice.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "waveform.slash") }
                case .file:
                    if let fileOwner, IMFileReference.read(snapshot.message) != nil {
                        if let ref = IMFileReference.read(snapshot.message) {
                            NavigationLink { IMFilePreviewView(message: snapshot.message, owner: fileOwner, current: isCurrent) } label: { IMFileCardLabel(reference: ref) }.buttonStyle(E3PressStyle())
                        }
                    } else { CYStatusChip(verbatim: String(localized: "file.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "doc") }
                case .video:
                    if let videoOwner, IMVideoReference.read(snapshot.message) != nil {
                        if let ref = IMVideoReference.read(snapshot.message) {
                            NavigationLink { IMVideoPlaybackView(message: snapshot.message, owner: videoOwner, current: isCurrent) } label: { IMVideoCardLabel(reference: ref) }.buttonStyle(E3PressStyle())
                        }
                    } else { CYStatusChip(verbatim: String(localized: "video.unavailable", table: "NativeChannelMessage"), tone: .neutral, systemImage: "video.slash") }
                case .chain:
                    Label { Text("type.14", tableName: "NativeChannelMessage") } icon: { Image(systemName: "list.number") }
                    if let content = snapshot.content { Text(verbatim: content).lineLimit(typeSize.isAccessibilitySize ? nil : 3) }
                    if let reference = NativeChannelChainReference(message: snapshot.message), let chainCoordinator {
                        NavigationLink {
                            NativeChannelChainLaunchView(makeFlow: { chainCoordinator(snapshot.message.conversationID, reference) }, current: isCurrent)
                        } label: { Text("chain.open", tableName: "NativeChannelMessage") }.accessibilityIdentifier("ncm47.originalChain")
                    } else if let openExistingType {
                        Button { if isCurrent() { openExistingType(snapshot) } } label: { Text("type.open", tableName: "NativeChannelMessage") }
                    } else { Text("type.sourceRequired", tableName: "NativeChannelMessage").font(Theme.Font.label).foregroundStyle(.secondary) }
                case .redPacket:
                    Label { Text("type.15", tableName: "NativeChannelMessage") } icon: { Image(systemName: icon) }
                    if let content = snapshot.content { Text(verbatim: content).lineLimit(typeSize.isAccessibilitySize ? nil : 3) }
                    if let openExistingType {
                        Button { if isCurrent() { openExistingType(snapshot) } } label: { Text("type.open", tableName: "NativeChannelMessage") }
                    } else { Text("type.sourceRequired", tableName: "NativeChannelMessage").font(Theme.Font.label).foregroundStyle(.secondary) }
                case .unknown: CYStatusChip(verbatim: String(localized: "type.unknown", table: "NativeChannelMessage"), tone: .neutral, systemImage: "questionmark.circle")
                }
                if let reference = snapshot.message.pollReference,
                   let owner = pollCoordinator?(snapshot.message.conversationID, reference),
                   owner.isCurrent, owner.reference == reference, owner.canRead {
                    NavigationLink {
                        GroupPollOriginalResultView(owner: owner, reference: reference, current: isCurrent)
                    } label: { Text("poll.results", tableName: "NativeChannelMessage") }.accessibilityIdentifier("ncm47.originalPollResult")
                }
                if snapshot.editedAt != nil { CYStatusChip(verbatim: String(localized: "message.edited", table: "NativeChannelMessage"), tone: .neutral, systemImage: "pencil") }
            }
        }
        .font(Theme.Font.body)
        .fixedSize(horizontal: false, vertical: true)
        .privacySensitive().accessibilityIdentifier("ncm47.message.\(snapshot.id.rawValue)")
    }
    private var icon: String {
        switch snapshot.kind { case .voice: return "waveform"; case .video: return "video"; case .file: return "doc"; case .location: return "mappin"; case .chain: return "list.number"; case .redPacket: return "gift"; default: return "bubble.left" }
    }
    private func placeholder(_ state: String) -> String {
        switch state {
        case "BLOCKED": return String(localized: LocalizedStringResource("quote.blocked", table: "NativeChannelMessage", locale: locale))
        case "RECALLED": return String(localized: LocalizedStringResource("message.recalled", table: "NativeChannelMessage", locale: locale))
        default: return String(localized: LocalizedStringResource("message.unavailable", table: "NativeChannelMessage", locale: locale))
        }
    }
}
