import SwiftUI
import UIKit

@MainActor struct CooperationInviteDetailView: View {
    let key: CooperationInviteKey
    let reader: any CooperationReading
    var peerReader: (any CoopFlowReading)? = nil
    private struct CopyHost: Hashable { let reader: ObjectIdentifier; let key: CooperationInviteKey }
    var body: some View {
        CooperationInviteDetailContent(key: key, reader: reader, peerReader: peerReader)
            .id(CopyHost(reader: ObjectIdentifier(reader), key: key))
            .environment(\.cooperationMissingInvite, true)
    }
}

@MainActor private struct CooperationInviteDetailContent: View {
    let key: CooperationInviteKey
    let reader: any CooperationReading
    var peerReader: (any CoopFlowReading)? = nil
    @Environment(\.cooperationProjectDestination) private var topicDestination
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var phoneCopy: CooperationPhoneCopyOwner
    @State private var openedTopic: Int?
    @State private var topicReturn: UInt64 = 0
    @State private var phoneToastKey: LocalizedStringKey?
    @State private var phoneToastTone: IslandTone = .success
    init(key: CooperationInviteKey, reader: any CooperationReading, peerReader: (any CoopFlowReading)? = nil) {
        self.key = key; self.reader = reader; self.peerReader = peerReader
        _phoneCopy = StateObject(wrappedValue: CooperationPhoneCopyOwner(reader: reader, key: key))
    }
    /// G-043 (design P1): the status is a tinted SF Symbol label (as Mail marks a flagged message), not a drawn chip.
    private func statusLabel(_ row: CooperationInvite) -> some View {
        let symbol: String, tint: Color
        switch row.status {
        case 0: symbol = "clock.fill"; tint = .orange
        case 1: symbol = "checkmark.circle.fill"; tint = .green
        default: symbol = "minus.circle.fill"; tint = .secondary
        }
        return Label { Text(LocalizedStringKey(row.statusKey)) } icon: {
            Image(systemName: symbol).foregroundStyle(tint).contentTransition(.symbolEffect(.replace))
        }
        .font(.subheadline.weight(.semibold))
        .accessibilityIdentifier("cooperation.detail.status")
    }
    private func partnerLine(_ row: CooperationInvite) -> some View {
        HStack(spacing: CYSpacing.xs) {
            Text(LocalizedStringKey(key.direction == .received ? "cooperation.detail.from" : "cooperation.detail.to"))
            if let name = row.partner?.name, !name.isEmpty { Text(verbatim: name) } else { Text("cooperation.detail.counterparty") }
        }.font(.subheadline).foregroundStyle(.secondary).accessibilityElement(children: .combine)
            .accessibilityIdentifier("cooperation.detail.partner")
    }
    var body: some View {
        CooperationReadScreen(reader: reader, resource: "invite.\(key.direction.rawValue).\(key.id).return.\(topicReturn)", operation: {
            guard key.id > 0 else { throw CooperationReadFailure.unavailable }
            return try await phoneCopy.load(reader: reader, key: key)
        }) { detail in
            let row = detail.row
            let view = CooperationInvitePresentation(invite: row, direction: key.direction)
            Section {
                // Mini `.hd`: status first, then the topic. The counterparty stays beside the status.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: CYSpacing.md) {
                        statusLabel(row)
                        Spacer(minLength: CYSpacing.sm)
                        partnerLine(row)
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        statusLabel(row)
                        partnerLine(row)
                    }
                }
                if let name = row.topicName {
                    // G-043: one optional Image header in the first section (the invite's real cover, MC7-32-2), then
                    // the topic name as a plain title row. No gradient scrim, no custom corner radius: the inset
                    // grouped section clips the row. No cover data → no image (MP invite-detail wxml:40-41).
                    if let cover = TemplateBrowserPort.coverURL(row.coverURL) {
                        CoopCloudCoverBanner(url: cover, seed: coopCoverSeed(name, fallback: "invite-\(row.id)"))
                            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                            .clipped()
                            .opacity((row.status ?? 0) >= 2 ? 0.6 : 1)
                            .listRowInsets(EdgeInsets())
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: name).font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                }
                // MC8-32-3 (invite-detail wxml:42-56): the pending invite's validity under the hero.
                if let countdown = CoopInviteCountdown.value(status: row.status, expire: row.expireTime) {
                    CoopInviteCountdownText(value: countdown).cyText(.meta)
                        .foregroundStyle(countdown == .expired ? AnyShapeStyle(Color.orange) : AnyShapeStyle(HierarchicalShapeStyle.secondary))
                        .accessibilityIdentifier("cooperation.detail.countdown")
                }
                if let topic = row.topicId {
                    CooperationTopicReference(id: topic)
                    CooperationProjectNavigationLink(topicID: topic, invite: key, destination: topicDestination, openedTopic: $openedTopic)
                }
                if let party = row.viewerPartyName {
                    LabeledContent { Text(verbatim: party) } label: { Text(LocalizedStringKey(key.direction == .received ? "cooperation.detail.receivingClub" : "cooperation.detail.sendingClub")) }
                        .accessibilityIdentifier("cooperation.detail.viewerParty")
                }
                CooperationField(key: "cooperation.inviteID", value: "#\(row.id)")
                CoopInviteReadReceiptRow(peerReader: peerReader, inviteID: row.id, direction: key.direction)
                CooperationTimeField(key: "cooperation.created", value: row.createTime)
                CooperationTimeField(key: "cooperation.expires", value: row.expireTime)
            }
            if let peerReader, let peer = CoopPeerMember(direction: key.direction, fromType: row.fromType, fromID: row.fromId, toType: row.toType, toID: row.toId) {
                Section { NavigationLink("context.coop.peerCredit") { CoopPeerCreditView(reader: peerReader, peer: peer) } }
            }
            Section("cooperation.detail.section.contact") {
                switch view.contact {
                case .visible(let text):
                    Text(verbatim: text).textSelection(.enabled).accessibilityIdentifier("cooperation.detail.contact")
                    if let intent = phoneCopy.intent(detail: detail, reader: reader, key: key) {
                        Button {
                            phoneCopy.copy(intent) { phone in
                                UIPasteboard.general.setItems([["public.utf8-plain-text": phone]],
                                    options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                            }
                        } label: { Label("cooperation.phone.copy", systemImage: "doc.on.doc") }
                        .accessibilityIdentifier("cooperation.phone.copy")
                    }
                    if let result = phoneCopy.resultKey {
                        Text(LocalizedStringKey(result)).accessibilityIdentifier("cooperation.phone.copy.result")
                    }
                case .afterAcceptReceived: Text("cooperation.detail.contact.afterAcceptReceived").foregroundStyle(.secondary)
                case .afterAcceptSent: Text("cooperation.detail.contact.afterAcceptSent").foregroundStyle(.secondary)
                case .acceptedWithoutContact: Text("cooperation.detail.contact.none").foregroundStyle(.secondary)
                case .ended: Text("cooperation.detail.contact.ended").foregroundStyle(.secondary)
                }
            }
            Section("cooperation.detail.section.terms") {
                // Mini-program invite detail lists the two parties first (utils/coop-invite-view.js typeText).
                LabeledContent { CooperationInvitePartyText(view: view) } label: { Text("cooperation.parties") }
                    .accessibilityElement(children: .combine).accessibilityIdentifier("cooperation.detail.parties")
                // MR-36 (`186:6119`): the terms read as a table; the split is the one bold row.
                LabeledContent { CooperationInviteTermsText(terms: view.terms) } label: { Text("cooperation.detail.share") }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("cooperation.detail.terms")
                let slotPage = CooperationInviteDetailPage.project(key: key, result: .success(detail))
                if case .text(let slotCount) = slotPage.slotCount, case .text(let slotCapacity) = slotPage.slotCapacity, let kind = detail.slotLine?.kind {
                    CooperationField(key: kind == .gamePending ? "cooperation.slot.game" : "cooperation.slot.topic", value: "\(slotCount) / \(slotCapacity)")
                }
                // MC7-32-3: MP invite-detail/index.wxml:85 核销据点 (supplyStationView): name, else 据点 #id, plus the lock note.
                if let stationID = row.supplyStationId {
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: CYSpacing.xxs) {
                            if let name = row.supplyStationName { Text(verbatim: name) }
                            else { Text("merchantCoop.station.fallback \(stationID)") }
                            Text(LocalizedStringKey(row.status == 1 ? "merchantCoop.station.note.accepted" : "merchantCoop.station.note.beforeAccept"))
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    } label: { Text("merchantCoop.station.label") }
                        .accessibilityElement(children: .combine).accessibilityIdentifier("cooperation.detail.supplyStation")
                }
                LabeledContent { CooperationInviteDepositText(deposit: view.deposit) } label: { Text("cooperation.detail.section.deposit") }
                    .accessibilityIdentifier("cooperation.detail.deposit")
                if row.termsFrozen { Label("cooperation.termsFrozen", systemImage: "lock") }
            }
            Section("cooperation.detail.messages") {
                if let message = row.message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    // Mini `.bubble`, as a plain grouped row (G-043): body text, then "我方/对方 · time" in the footnote style.
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: message).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: CYSpacing.xs) {
                            Text(LocalizedStringKey(view.messageIsOurs ? "cooperation.detail.us" : "cooperation.detail.them"))
                            CooperationTimeField(key: "cooperation.created", value: row.createTime)
                        }.font(.footnote).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("cooperation.detail.message")
                }
                if let reason = row.handleReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: reason).fixedSize(horizontal: false, vertical: true)
                        Text(LocalizedStringKey(view.handleReasonIsOurs ? "cooperation.detail.reason.us" : "cooperation.detail.reason.them"))
                            .font(.footnote).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("cooperation.detail.handleReason")
                }
                if (row.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (row.handleReason ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("cooperation.detail.noMessages", systemImage: "bubble.left")
                }
                if view.input == .hidden && row.status == 1 && !row.legacyReadonly { Text("cooperation.detail.contactHint").font(.footnote).foregroundStyle(.secondary) }
            }
            CooperationInviteActionSections(view: view, peerReader: peerReader)
            if !row.legacyReadonly && row.depositRefundPending {
                Section("cooperation.deposit") {
                    Label("cooperation.refundPending", systemImage: "clock")
                }
            }
            Section { CooperationReadOnlyNotice() }
        }
        .appNavigationTitle("cooperation.detail.title")
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainScreen(.merchant)
        .cyHideTabBar(true)
        .onAppear { phoneCopy.appear(active: scenePhase == .active) }
        .onDisappear { phoneCopy.disappear() }
        .onChange(of: scenePhase) { _, phase in phoneCopy.sceneChanged(active: phase == .active) }
        .onChange(of: reader.scope) { _, _ in phoneCopy.retire(); openedTopic = nil }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in phoneCopy.retire(); openedTopic = nil }
        .onChange(of: reader.isAuthenticated) { _, _ in openedTopic = nil }
        .onChange(of: key) { _, _ in phoneCopy.retire(); openedTopic = nil; phoneToastKey = nil }
        .onChange(of: phoneCopy.resultKey) { _, resultKey in
            guard let resultKey else { return }
            phoneToastTone = ClubIslandStatusTone.forResultKey(resultKey)
            phoneToastKey = LocalizedStringKey(resultKey)
        }
        .clubIslandStatus(message: $phoneToastKey, tone: phoneToastTone, surface: "coop-invite")
        .onChange(of: openedTopic) { previous, next in
            guard previous != nil, next == nil else { return }
            topicReturn &+= 1
        }
        .navigationDestination(item: $openedTopic) { topicID in
            CooperationProjectNavigationDestination(topicID: topicID, invite: key, destination: topicDestination)
        }
    }
}

/// A local device action belongs to one successful detail read and one explicit gesture.
@MainActor final class CooperationPhoneCopyOwner: ObservableObject {
    struct Intent {
        fileprivate let id: UUID
        fileprivate let readID: UUID
        fileprivate let scope: UUID
        fileprivate let phone: String
    }
    private let reader: any CooperationReading
    private let key: CooperationInviteKey
    private var visible = false, active = false
    private var readID = UUID(), gestureID = UUID()
    private var loadedScope: UUID?
    private var detail: CooperationInviteDetail?
    @Published private var result: String?
    @Published private var revision = 0
    init(reader: any CooperationReading, key: CooperationInviteKey) { self.reader = reader; self.key = key }
    private var current: Bool {
        reader.isConfigured && reader.isAuthenticated && loadedScope == reader.scope
    }
    var resultKey: String? { visible && active && current ? result : nil }
    func appear(active: Bool) {
        visible = true; self.active = active
        if !active { retire() }
    }
    func disappear() { visible = false; active = false; retire() }
    func sceneChanged(active: Bool) {
        self.active = visible && active
        if !self.active { retire() }
    }
    func retire() {
        readID = UUID(); gestureID = UUID(); loadedScope = nil; detail = nil; result = nil; revision += 1
    }
    func load(reader supplied: any CooperationReading, key suppliedKey: CooperationInviteKey) async throws -> CooperationInviteDetail {
        // The original read remains authoritative even when local copying is unavailable.
        let observes = suppliedKey == key && ObjectIdentifier(supplied) == ObjectIdentifier(reader)
        if observes { retire() }
        let request = readID, scope = supplied.scope
        let value = try await supplied.detail(key: suppliedKey)
        if observes, !Task.isCancelled, request == readID, scope == reader.scope,
           reader.isConfigured, reader.isAuthenticated, value.row.id == key.id {
            detail = value; loadedScope = scope; revision += 1
        }
        return value
    }
    func intent(detail displayed: CooperationInviteDetail, reader supplied: any CooperationReading,
                key suppliedKey: CooperationInviteKey) -> Intent? {
        guard visible, active, current, suppliedKey == key,
              ObjectIdentifier(supplied) == ObjectIdentifier(reader), let detail, detail == displayed,
              let phone = detail.row.partner?.phone, !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let displayedPhone = displayed.row.partner?.phone, phone.utf8.elementsEqual(displayedPhone.utf8),
              let loadedScope else { return nil }
        return Intent(id: gestureID, readID: readID, scope: loadedScope, phone: phone)
    }
    @discardableResult func copy(_ intent: Intent, write: (String) throws -> Void) -> Bool {
        guard visible, active, current, intent.id == gestureID, intent.readID == readID,
              intent.scope == loadedScope, let phone = detail?.row.partner?.phone,
              phone.utf8.elementsEqual(intent.phone.utf8) else { return false }
        let completion = UUID(); gestureID = completion; result = nil
        do {
            try write(phone)
            guard visible, active, current, gestureID == completion, readID == intent.readID else { return true }
            result = "cooperation.phone.copied"
        } catch {
            guard visible, active, current, gestureID == completion, readID == intent.readID else { return false }
            result = "cooperation.phone.copyFailed"
            return false
        }
        return true
    }
}

/// Received invites post `/api/coop/invite/read`. Opening a sent invite does not.
@MainActor private struct CoopInviteReadReceiptRow: View {
    let peerReader: (any CoopFlowReading)?
    let inviteID: Int
    let direction: CooperationDirection
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var phase = Phase.loading
    private enum Phase { case loading, done, failed }
    var body: some View {
        Group {
            if direction == .sent {
                Text(verbatim: locale.pick("发起方查看不算已读", "Opening your own invite does not mark it read"))
                    .font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("cooperation.detail.read.sent")
            } else {
                switch phase {
                case .loading:
                    Text(verbatim: locale.pick("正在标记已读", "Marking as read")).font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cooperation.detail.read.loading")
                case .done:
                    Label { Text(verbatim: locale.pick("已读", "Read")) } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("cooperation.detail.read.done")
                case .failed:
                    VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? CYSpacing.sm : CYSpacing.xs) {
                        Text(verbatim: locale.pick("已读没有记下，请重试", "The read receipt did not stick. Try again."))
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        Button { Task { await mark() } } label: { Text(verbatim: locale.pick("重试", "Try again")) }
                            .buttonStyle(.bordered)
                    }.accessibilityIdentifier("cooperation.detail.read.failed")
                }
            }
        }
        .task(id: "\(direction.rawValue).\(inviteID)") { await mark() }
    }
    private func mark() async {
        guard direction == .received, inviteID > 0, let peerReader else { phase = .failed; return }
        phase = .loading
        do { _ = try await peerReader.markInviteRead(inviteID: inviteID); phase = .done }
        catch { phase = .failed }
    }
}
