import SwiftUI

/// MC8-33-1 / MC8-33-2 / MC8-33-3 / MC8-33-5 (pages/coop/nearby/index.js:300-515): 找商家 opened for a topic.
/// - The page reads `chapter-application/invitable` for the topic once the consented nearby search is ready and
///   merges it by `memberId` (MP `merge`): matching nearby cards show 可承接 · 章节, and invitable merchants that are
///   not in the nearby radius are appended after them (no distance, so last, as in the MP sort).
/// - A merchant with replacement candidates (`replacementOfOfferId`) offers 邀请补位, which opens the existing C9
///   replacement-invitation flow for the topic (`ChapterReplacementInvitationEntry`). That flow posts
///   `chapter-application/invite {chapterId, merchantMemberId, replacementOfOfferId}` only through its own reviewed,
///   default-closed write gate, so nothing is sent from this page.
struct NearbyMerchantInvitableRow: Identifiable, Equatable {
    /// One station this merchant can take: chapter name plus its terms tier (MP `chapterName + stationTermsText`).
    struct Chapter: Equatable {
        let name: String
        let terms: CoopNearbyStationTerms?
        func label(chinese: Bool) -> String { CoopNearbyStationTerms.label(chapter: name, terms: terms, chinese: chinese) }
    }
    let memberID: Int
    let name: String
    let address: String?
    /// One entry per chapter + terms this merchant can take (MP `chapterNames`, de-duplicated by label, server order).
    let chapters: [Chapter]
    /// At least one row carries a replacement candidate (MP `replacementInvites` non-empty).
    let hasReplacement: Bool
    var id: Int { memberID }
    func chapterText(chinese: Bool) -> String? {
        chapters.isEmpty ? nil : chapters.map { $0.label(chinese: chinese) }.joined(separator: chinese ? "、" : ", ")
    }

    /// MP `validInvitableRow` + `merge`: rows without memberId, name or chapterName are dropped; one row per member.
    static func merged(_ values: [MerchantContentValue]) -> [NearbyMerchantInvitableRow] {
        var order: [Int] = []
        var byMember: [Int: (name: String, address: String?, chapters: [Chapter], replacement: Bool)] = [:]
        for value in values {
            guard let member = value["memberId"].integer, member > 0,
                  let name = value["name"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
                  let chapterName = value["chapterName"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !chapterName.isEmpty
            else { continue }
            let chapter = Chapter(name: chapterName, terms: CoopNearbyStationTerms(row: value))
            let replacement = (value["replacementOfOfferId"].integer ?? 0) > 0 && (value["chapterId"].integer ?? 0) > 0
            if var existing = byMember[member] {
                if !existing.chapters.contains(chapter) { existing.chapters.append(chapter) }
                existing.replacement = existing.replacement || replacement
                if existing.address == nil { existing.address = value["address"].text }
                byMember[member] = existing
            } else {
                order.append(member)
                byMember[member] = (name, value["address"].text, [chapter], replacement)
            }
        }
        return order.compactMap { member in
            byMember[member].map { .init(memberID: member, name: $0.name, address: $0.address, chapters: $0.chapters, hasReplacement: $0.replacement) }
        }
    }
}

/// The topic a 找商家 page is scoped to, plus what it needs to read candidates and open the 补位 flow.
@MainActor struct NearbyMerchantTopicScope {
    let topic: CoopNearbyTopicContext
    let service: any MerchantContentServing
    /// Nil when the signed-in member cannot act for the topic; 邀请补位 is then not offered.
    let replacementContext: MerchantChapterReplacementHostContext?
}

/// Loads the invitable rows for the topic whenever the nearby result becomes ready; clears them otherwise.
struct NearbyMerchantInvitableLoader: ViewModifier {
    let scope: NearbyMerchantTopicScope?
    let ready: Bool
    @Binding var rows: [NearbyMerchantInvitableRow]
    @Binding var failed: Bool

    func body(content: Content) -> some View {
        content.task(id: LoadKey(topicID: scope?.topic.topicID, ready: ready)) {
            rows = []; failed = false
            guard ready, let scope else { return }
            do {
                let snapshot = try await scope.service.load(.invitable(topicID: scope.topic.topicID))
                guard !Task.isCancelled else { return }
                rows = NearbyMerchantInvitableRow.merged(snapshot.rows)
            } catch {
                guard !Task.isCancelled else { return }
                // MP fails closed when either read fails; here the nearby rows stay and the page says the
                // topic candidates could not be read (no invite is offered from a partial list).
                failed = true
            }
        }
    }
    private struct LoadKey: Equatable { let topicID: Int?; let ready: Bool }
}

/// MC8-33-5: the topic header (MP 邀请商家 + topicName under the title).
struct NearbyMerchantTopicHeader: View {
    let topic: CoopNearbyTopicContext
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text("merchantCoop.nearby.topic.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            if !topic.topicName.isEmpty {
                Text(verbatim: topic.topicName).cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nearbyMerchant.topic.header")
    }
}

/// 可承接 · 章节 under a card (MP `chapterText`).
struct NearbyMerchantChapterLine: View {
    let text: String
    var body: some View {
        Text("merchantCoop.nearby.topic.chapters \(text)").cyText(.meta).foregroundStyle(CYColor.brandStrong)
    }
}

/// 邀请补位 → the C9 replacement-invitation flow for the topic.
struct NearbyMerchantReplacementLink: View {
    let scope: NearbyMerchantTopicScope
    let memberID: Int
    var body: some View {
        if let context = scope.replacementContext {
            NavigationLink {
                ChapterReplacementInvitationEntry(context: context, topicID: scope.topic.topicID, merchantAccess: nil)
            } label: {
                Label("merchantCoop.nearby.topic.replacement", systemImage: "arrow.triangle.2.circlepath")
                    .frame(minHeight: CYSpacing.minTouchTarget)
            }
            .accessibilityIdentifier("nearbyMerchant.replacement.\(memberID)")
        }
    }
}

/// Invitable merchants outside the nearby radius (MP: merged rows with no distance sort last).
struct NearbyMerchantInvitableOnlyRows: View {
    let scope: NearbyMerchantTopicScope
    let rows: [NearbyMerchantInvitableRow]
    let publicMerchant: PublicMerchantHomeContext
    @Environment(\.locale) private var locale
    var body: some View {
        ForEach(rows) { row in
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                if let owner = PublicMerchantOwnerID(row.memberID) {
                    NavigationLink {
                        PublicMerchantHomeView(target: .ownerMemberID(owner), context: publicMerchant)
                    } label: { label(row) }
                    .accessibilityIdentifier("nearbyMerchant.invitable.\(row.memberID)")
                } else { label(row) }
                if row.hasReplacement { NearbyMerchantReplacementLink(scope: scope, memberID: row.memberID) }
            }
        }
    }
    private func label(_ row: NearbyMerchantInvitableRow) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: row.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            if let address = row.address, !address.isEmpty { Text(verbatim: address).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if let text = row.chapterText(chinese: LocaleDisplay.isChinese(locale)) { NearbyMerchantChapterLine(text: text) }
        }
    }
}

extension SessionNearbyMerchantsView {
    /// MC8-33-3: the topic scope for a `pages/coop/nearby/index?topicId=&topicName=` link or a coop-list 再邀别人.
    static func topicScope(session: AppSession, topic: CoopNearbyTopicContext?, merchantScope: Bool = false) -> NearbyMerchantTopicScope? {
        guard let topic, topic.topicID > 0 else { return nil }
        let service = session.merchantContentService
        var context: MerchantChapterReplacementHostContext?
        if let actor = session.account?.id, actor > 0 {
            let replacementScope: ChapterReplacementInvitationScope = merchantScope ? .merchant : .currentMember
            context = MerchantChapterReplacementHostContext(
                makeEffects: { service.chapterReplacementInvitationEffects(scope: replacementScope, publisherProof: $0) },
                actorAccountID: actor, scope: replacementScope, merchantAccess: nil,
                loadPublisherProof: { topicID in
                    let access = try? await session.merchantAccess()
                    return await service.chapterReplacementPublisherProof(topicID: topicID, actorAccountID: actor, access: access)
                },
                coordinates: nil)
        }
        return NearbyMerchantTopicScope(topic: topic, service: service, replacementContext: context)
    }
}
