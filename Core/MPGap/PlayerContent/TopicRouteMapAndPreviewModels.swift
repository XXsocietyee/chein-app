import Foundation

/// Models for `player-content` MP gaps (`PC-A-7-2`, `PC-B-1-5`, `PC-B-2-3`, `PC-B-4-2/4`, `PC-C-2-3/4/6`, `PC-C-4-2`).

// MARK: - PC-A-7-2: Topic Template Card Deck Preview

public struct TopicTemplatePreviewCard: Identifiable, Equatable, Sendable {
    public let id: String
    public let isCover: Bool
    public let title: String
    public let steps: [String]
    public let footText: String
    public let footCopy: TopicTemplatePreviewCopy

    public init(id: String, isCover: Bool, title: String, steps: [String], footText: String, footCopy: TopicTemplatePreviewCopy) {
        self.id = id
        self.isCover = isCover
        self.title = title
        self.steps = steps
        self.footText = footText
        self.footCopy = footCopy
    }
}

public struct TopicTemplatePreviewCopy: Equatable, Sendable {
    public let key: String
    public let arguments: [String]
    public init(key: String, arguments: [String] = []) {
        self.key = key
        self.arguments = arguments
    }
}

public struct TopicTemplatePreviewData: Equatable, Sendable {
    public let templateID: Int
    public let name: String
    public let coverURL: String?
    public let description: String?
    public let productType: Int
    public let isMerchantScope: Bool
    public let isReadonly: Bool
    public let cards: [TopicTemplatePreviewCard]
    public let checks: [String]
    public let checkCopies: [TopicTemplatePreviewCopy]

    public init(
        templateID: Int,
        name: String,
        coverURL: String?,
        description: String?,
        productType: Int,
        isMerchantScope: Bool = false,
        isReadonly: Bool = false,
        cards: [TopicTemplatePreviewCard],
        checks: [String],
        checkCopies: [TopicTemplatePreviewCopy] = []
    ) {
        self.templateID = templateID
        self.name = name
        self.coverURL = coverURL
        self.description = description
        self.productType = productType
        self.isMerchantScope = isMerchantScope
        self.isReadonly = isReadonly
        self.cards = cards
        self.checks = checks
        self.checkCopies = checkCopies
    }

    /// Mirrors MP `pages/templatedetail/topic-preview/index.js:16-54` (`fmtSec`, `buildDeck`, `buildChecks`).
    public static func formatSeconds(_ seconds: Int) -> String {
        let minutes = Int((Double(max(0, seconds)) / 60.0).rounded())
        guard minutes > 0 else { return "" }
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem > 0 ? "\(hours) 小时\(rem) 分" : "\(hours) 小时"
    }

    static func durationCopy(_ seconds: Int) -> TopicTemplatePreviewCopy {
        let minutes = Int((Double(max(0, seconds)) / 60.0).rounded())
        if minutes < 60 { return TopicTemplatePreviewCopy(key: "topic.template.preview.minutes", arguments: [String(max(0, minutes))]) }
        let hours = minutes / 60
        let rem = minutes % 60
        if rem > 0 { return TopicTemplatePreviewCopy(key: "topic.template.preview.hoursMinutes", arguments: [String(hours), String(rem)]) }
        return TopicTemplatePreviewCopy(key: "topic.template.preview.hours", arguments: [String(hours)])
    }

    public static func fromWire(
        _ data: PlayWireValue,
        templateID: Int,
        isMerchantScope: Bool = false,
        isReadonly: Bool = false
    ) -> TopicTemplatePreviewData {
        let name = data["name"].text ?? ""
        let coverURL = data["imgUrl"].text
        let desc = data["description"].text ?? data["intro"].text
        let productType = data["productType"].tolerantInteger ?? 1
        let totalTime = data["totalTime"].tolerantInteger ?? 0
        let totalDur = formatSeconds(totalTime)
        let finishMedalName = data["finishMedalName"].text

        let games = data["games"].array ?? []
        let gameCards: [TopicTemplatePreviewCard] = games.enumerated().map { idx, g in
            let title = g["title"].text ?? ""
            let mins = g["duration"].tolerantInteger ?? 0
            let foot = mins > 0 ? "\(mins) 分钟" : totalDur
            let footCopy = mins > 0
                ? TopicTemplatePreviewCopy(key: "topic.template.preview.minutes", arguments: [String(mins)])
                : durationCopy(totalTime)
            return TopicTemplatePreviewCard(
                id: "game-\(idx)",
                isCover: false,
                title: title,
                steps: [],
                footText: foot,
                footCopy: footCopy
            )
        }
        let titles = gameCards.map(\.title)
        let coverSteps = titles.count > 5 ? Array(titles.prefix(5)) + ["…"] : titles
        let coverCard = TopicTemplatePreviewCard(
            id: "cover",
            isCover: true,
            title: name,
            steps: coverSteps,
            footText: totalDur,
            footCopy: durationCopy(totalTime)
        )
        let cards = [coverCard] + gameCards

        let chapters = data["chapters"].array ?? []
        var checks: [String] = []
        var checkCopies: [TopicTemplatePreviewCopy] = []
        if productType == 1 {
            let nodeCount = chapters.reduce(0) { $0 + ($1["nodeCount"].tolerantInteger ?? 0) }
            let shape = [
                chapters.isEmpty ? nil : "\(chapters.count) 章节",
                nodeCount > 0 ? "\(nodeCount) 节点" : nil
            ].compactMap { $0 }.joined(separator: " · ")
            if !shape.isEmpty {
                checks.append(shape)
                if !chapters.isEmpty && nodeCount > 0 {
                    checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.chaptersNodes", arguments: [String(chapters.count), String(nodeCount)]))
                } else if !chapters.isEmpty {
                    checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.chapters", arguments: [String(chapters.count)]))
                } else {
                    checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.nodes", arguments: [String(nodeCount)]))
                }
            }
            if !totalDur.isEmpty {
                checks.append("约 \(totalDur)")
                checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.about", arguments: [totalDur]))
            }
            if let medal = finishMedalName, !medal.isEmpty {
                checks.append("勋章「\(medal)」")
                checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.medal", arguments: [medal]))
            }
        } else if gameCards.count <= 1 {
            if !gameCards.isEmpty {
                checks.append("1 个玩法")
                checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.oneGame"))
            }
            if !totalDur.isEmpty {
                checks.append("约 \(totalDur)")
                checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.about", arguments: [totalDur]))
            }
        } else {
            let chapterNames = chapters.compactMap { $0["name"].text?.split(separator: " ").first.map(String.init) }
                .filter { !$0.isEmpty }
            if !chapterNames.isEmpty {
                checks.append(chapterNames.joined(separator: " / "))
                checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.chapterNames", arguments: chapterNames))
            }
            checks.append("\(gameCards.count) 个小玩法")
            checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.miniGames", arguments: [String(gameCards.count)]))
            if !totalDur.isEmpty {
                checks.append("首局约 \(totalDur)")
                checkCopies.append(TopicTemplatePreviewCopy(key: "topic.template.preview.firstAbout", arguments: [totalDur]))
            }
        }

        return TopicTemplatePreviewData(
            templateID: templateID,
            name: name,
            coverURL: coverURL,
            description: desc,
            productType: productType,
            isMerchantScope: isMerchantScope,
            isReadonly: isReadonly,
            cards: cards,
            checks: checks,
            checkCopies: checkCopies
        )
    }
}

// MARK: - PC-B-1-5: Topic Route Map, Progress, Team Summary & Free-Explore Merchant Cards

public struct TopicRouteNodePin: Identifiable, Equatable, Sendable {
    public let id: String
    public let sequence: Int
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    public let isCompleted: Bool

    public init(
        id: String,
        sequence: Int,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.sequence = sequence
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.isCompleted = isCompleted
    }
}

public struct TopicRouteTeamSummary: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let memberCount: Int
    public let missingCount: Int

    public init(id: Int, name: String, memberCount: Int, missingCount: Int) {
        self.id = id
        self.name = name
        self.memberCount = memberCount
        self.missingCount = missingCount
    }
}

public struct TopicFreeExploreMerchantCard: Identifiable, Equatable, Sendable {
    public let id: Int
    public let merchantName: String
    public let address: String?
    public let perkTitle: String?
    public let coverURL: String?
    /// R7-PC-B1-6: owner member id (opens the public merchant home) and `mmsMerchant.id` (catalog overlay key). 0 when unknown.
    public let memberID: Int
    public let merchantID: Int

    public init(id: Int, merchantName: String, address: String?, perkTitle: String?, coverURL: String?,
                memberID: Int = 0, merchantID: Int = 0) {
        self.id = id
        self.merchantName = merchantName
        self.address = address
        self.perkTitle = perkTitle
        self.coverURL = coverURL
        self.memberID = memberID
        self.merchantID = merchantID
    }
}

// MARK: - PC-C-2-3 / C-2-4 / C-2-6: Activity Registration Gap Models

public struct ActivityChildAgeRange: Equatable, Sendable {
    public let minAge: Int
    public let maxAge: Int

    public init(minAge: Int, maxAge: Int) {
        self.minAge = min(minAge, maxAge)
        self.maxAge = max(minAge, maxAge)
    }

    public var options: [Int] { Array(minAge...maxAge) }
}

public struct ActivityDeliveryItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let label: String
    public let value: String

    public init(id: String, label: String, value: String) {
        self.id = id
        self.label = label
        self.value = value
    }
}

public struct ActivityHostReservationState: Equatable, Sendable {
    public let isShown: Bool
    public let statusText: String
    public let awaitingPayment: Bool
    public let paymentDeadlineText: String?
    public let canRequest: Bool
    public let canCancel: Bool

    public init(
        isShown: Bool,
        statusText: String,
        awaitingPayment: Bool = false,
        paymentDeadlineText: String? = nil,
        canRequest: Bool = false,
        canCancel: Bool = false
    ) {
        self.isShown = isShown
        self.statusText = statusText
        self.awaitingPayment = awaitingPayment
        self.paymentDeadlineText = paymentDeadlineText
        self.canRequest = canRequest
        self.canCancel = canCancel
    }
}

// MARK: - PC-B-4-2 / B-4-4: Topic Pricing Gap Models

public struct TopicPricingPerTicketField: Identifiable, Equatable, Sendable {
    public let id: Int
    public let ticketName: String
    public var priceText: String

    public init(id: Int, ticketName: String, priceText: String) {
        self.id = id
        self.ticketName = ticketName
        self.priceText = priceText
    }
}

public struct TopicPricingExtraStatus: Equatable, Sendable {
    public let saleStatusText: String?
    public let settlementPendingText: String?
    public let platformFeeRatePercent: Double?

    public init(
        saleStatusText: String? = nil,
        settlementPendingText: String? = nil,
        platformFeeRatePercent: Double? = nil
    ) {
        self.saleStatusText = saleStatusText
        self.settlementPendingText = settlementPendingText
        self.platformFeeRatePercent = platformFeeRatePercent
    }
}

// MARK: - PC-C-4-2: Official Event Leaderboard

public struct OfficialEventLeaderboardRow: Identifiable, Equatable, Sendable {
    public let id: String
    public let rank: Int
    public let displayName: String
    public let scoreText: String
    public let isSelf: Bool

    public init(id: String, rank: Int, displayName: String, scoreText: String, isSelf: Bool) {
        self.id = id
        self.rank = rank
        self.displayName = displayName
        self.scoreText = scoreText
        self.isSelf = isSelf
    }
}

// MARK: - PC-B-2-3: Merchant Host Workbench Commands (Owner-gated)

public enum MerchantHostWorkbenchAction: String, CaseIterable, Identifiable, Sendable {
    case openRecruitment
    case finishChapter
    case confirmClubCandidates
    case contactHost
    case selfSupply
    case circleSupplyToggle

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .openRecruitment: return "开放商家招募"
        case .finishChapter: return "结束本章节"
        case .confirmClubCandidates: return "确认俱乐部承接"
        case .contactHost: return "联系主办方"
        case .selfSupply: return "自主供货"
        case .circleSupplyToggle: return "圈子供货管理"
        }
    }
}

extension TopicFreeExploreMerchantCard {
    /// R7-PC-B1-6: MP `buildMerchantCards` (pages/topic/utils/topic-motion.js:178-200). One card per shop id (else name) from
    /// `chapters[].nodes[].registrationMerchantList`; the node name is the place line. Image: cover, else the first photo.
    /// Needs no sign-in: it reads the topic detail only.
    public static func cards(fromChapters chapters: [TopicChapter]) -> [TopicFreeExploreMerchantCard] {
        var seen = Set<String>()
        var cards: [TopicFreeExploreMerchantCard] = []
        for chapter in chapters {
            for node in chapter.nodes {
                for merchant in node.merchants {
                    let name = merchant.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { continue }
                    let key = merchant.merchantID > 0 ? "id:\(merchant.merchantID)" : "name:" + name
                    guard seen.insert(key).inserted else { continue }
                    let place = node.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    cards.append(TopicFreeExploreMerchantCard(
                        id: cards.count + 1, merchantName: name, address: place.isEmpty ? nil : place,
                        perkTitle: merchant.derivativeBenefits ?? merchant.slogan, coverURL: merchant.coverImage ?? merchant.imageURL,
                        memberID: merchant.memberID, merchantID: merchant.merchantID))
                }
            }
        }
        return cards
    }

    /// R7-PC-B1-6: MP `mergeExploreCatalog` (topic-motion.js:246-261). Overlay the catalog perk line onto base cards by
    /// `merchantId`, else `merchantName`. The perk line is the store `perkName`, else the catalog item name. Cards without a
    /// match keep their own line; a missing catalog leaves the cards as they are.
    public static func overlay(_ cards: [TopicFreeExploreMerchantCard], catalog data: PlayWireValue?) -> [TopicFreeExploreMerchantCard] {
        guard let items = data?["items"].array else { return cards }
        var byID: [Int: String] = [:], byName: [String: String] = [:]
        for item in items {
            let itemName = item["name"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            for store in item["stores"].array ?? [] {
                let perkName = store["perkName"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let line = (perkName?.isEmpty == false ? perkName : nil) ?? (itemName?.isEmpty == false ? itemName : nil) else { continue }
                if let id = store["merchantId"].tolerantInteger, id > 0 { byID[id] = line }
                if let name = store["merchantName"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty, byName[name] == nil {
                    byName[name] = line
                }
            }
        }
        return cards.map { card in
            guard let line = (card.merchantID > 0 ? byID[card.merchantID] : nil) ?? byName[card.merchantName] else { return card }
            return TopicFreeExploreMerchantCard(id: card.id, merchantName: card.merchantName, address: card.address, perkTitle: line,
                                                coverURL: card.coverURL, memberID: card.memberID, merchantID: card.merchantID)
        }
    }

    /// R7-PC-B1-6: MP pages/topic/index/index.js:665-669 reads `/api/free-explore/bundle/catalog` and lists every store of
    /// every item. One card per `offerId` (first item wins); the item name is the perk line. Stores without a positive id or a
    /// name are dropped; nothing is invented.
    public static func cards(fromCatalog data: PlayWireValue?) -> [TopicFreeExploreMerchantCard] {
        var seen = Set<Int>()
        var cards: [TopicFreeExploreMerchantCard] = []
        for item in data?["items"].array ?? [] {
            let perk = item["name"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
            for store in item["stores"].array ?? [] {
                guard let id = store["offerId"].tolerantInteger, id > 0, !seen.contains(id),
                      let name = store["merchantName"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty
                else { continue }
                seen.insert(id)
                let address = store["address"].text?.trimmingCharacters(in: .whitespacesAndNewlines)
                cards.append(TopicFreeExploreMerchantCard(id: id, merchantName: name,
                                                          address: address?.isEmpty == false ? address : nil,
                                                          perkTitle: perk?.isEmpty == false ? perk : nil, coverURL: nil))
            }
        }
        return cards
    }
}
