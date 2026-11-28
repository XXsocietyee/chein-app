import Foundation

/// MP `pages/coop/nearby/index.js` `chooseChapterReplacement` (js:457-473): tapping a merchant that has replacement
/// candidates on 找商家承接 opens 选择补位操作 with one action per candidate:
/// `邀请补位 · {chapterName}` plus `（补位 n）` when the same chapter has more than one candidate (n = 1-based position
/// among that chapter's candidates). Candidates are collected per merchant from `chapter-application/invitable`
/// rows with a valid `chapterId` and `replacementOfOfferId`, de-duplicated by that pair (js:390-396), server order.
public struct CoopNearbyReplacementOption: Equatable, Hashable, Sendable, Identifiable {
    public let merchantMemberID: Int
    /// The merchant's name from the invitable row (MP `merchant.name`), used in the confirm sentence.
    public let merchantName: String
    public let chapterID: Int
    public let chapterName: String
    public let replacementOfOfferID: Int
    /// 1-based position among this merchant's candidates for the same chapter; nil when it is the only one.
    public let position: Int?

    public var id: String { "\(merchantMemberID):\(chapterID):\(replacementOfOfferID)" }

    public init(merchantMemberID: Int, merchantName: String, chapterID: Int, chapterName: String, replacementOfOfferID: Int, position: Int?) {
        self.merchantMemberID = merchantMemberID
        self.merchantName = merchantName
        self.chapterID = chapterID
        self.chapterName = chapterName
        self.replacementOfOfferID = replacementOfOfferID
        self.position = position
    }

    /// MP label `邀请补位 · 灯笼巷（补位 2）`; en "Invite a replacement · Lantern Lane (option 2)".
    public func label(chinese: Bool) -> String {
        if chinese {
            let suffix = position.map { "（补位 \($0)）" } ?? ""
            return "邀请补位 · \(chapterName)\(suffix)"
        }
        let suffix = position.map { " (option \($0))" } ?? ""
        return "Invite a replacement · \(chapterName)\(suffix)"
    }

    /// MP confirm modal 邀请商家补位 content (js:496): 邀请「{商家}」补位「{章节}」，商家可直接填写供给与节点。
    public func confirmText(chinese: Bool) -> String {
        chinese ? "邀请「\(merchantName)」补位「\(chapterName)」，商家可直接填写供给与节点。"
            : "Invite “\(merchantName)” to take over “\(chapterName)”. The merchant can fill in the supply and checkpoints directly."
    }

    /// MP toast when the chosen candidate is no longer in the fresh list (js:503).
    public static func changedText(chinese: Bool) -> String {
        chinese ? "补位候选已变化，请刷新后重试" : "The replacement options have changed. Refresh and try again."
    }

    /// One merchant's options from the invitable rows (rows of other members are ignored).
    public static func options(merchantMemberID: Int, rows: [MerchantContentValue]) -> [CoopNearbyReplacementOption] {
        guard merchantMemberID > 0 else { return [] }
        var raw: [(chapterID: Int, name: String, offerID: Int)] = []
        var merchantName = ""
        for row in rows {
            guard row["memberId"].integer == merchantMemberID,
                  let chapterID = row["chapterId"].integer, chapterID > 0,
                  let offerID = row["replacementOfOfferId"].integer, offerID > 0,
                  let name = row["chapterName"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
            else { continue }
            if merchantName.isEmpty, let value = row["name"].text?.trimmingCharacters(in: .whitespacesAndNewlines) { merchantName = value }
            if raw.contains(where: { $0.chapterID == chapterID && $0.offerID == offerID }) { continue }
            raw.append((chapterID, name, offerID))
        }
        return raw.map { item in
            let sameChapter = raw.filter { $0.chapterID == item.chapterID }
            let index = sameChapter.firstIndex(where: { $0.offerID == item.offerID }) ?? 0
            return CoopNearbyReplacementOption(merchantMemberID: merchantMemberID, merchantName: merchantName, chapterID: item.chapterID,
                                               chapterName: item.name, replacementOfOfferID: item.offerID,
                                               position: sameChapter.count > 1 ? index + 1 : nil)
        }
    }

    /// MP `confirmChapterReplacement` stillInvitable check: the focused candidate must still be in the fresh
    /// candidate list for its vacancy (same merchant, chapter and replaced offer), else 补位候选已变化，请刷新后重试.
    public func matches(_ candidate: ChapterReplacementInvitationCandidate) -> Bool {
        candidate.merchantMemberID == merchantMemberID && candidate.chapterID == chapterID
            && candidate.replacementOfOfferID == replacementOfOfferID
    }
}
