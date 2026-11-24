import Foundation

/// Round-2 Core models & helpers for remaining `member` MP gaps:
/// `FIN-16-2`, `FIN-17-4/8`, `FIN-18-2`, `FIN-19-1`, `PLY-21-5`, `PLY-23-3/4/6`, `PLY-26-5`.

// MARK: - FIN-16-2 / FIN-18-2 / FIN-19-1: Keep-on-Refresh Paged Buffer

public struct PagedKeepOnRefreshBuffer<Item: Equatable>: Equatable {
    public private(set) var items: [Item] = []
    public private(set) var currentPage: Int = 1
    public private(set) var hasMore: Bool = false
    public private(set) var lastRefreshError: String?

    public init(items: [Item] = [], currentPage: Int = 1, hasMore: Bool = false) {
        self.items = items
        self.currentPage = currentPage
        self.hasMore = hasMore
    }

    public mutating func applyRefreshSuccess(_ newItems: [Item], hasMore: Bool) {
        self.items = newItems
        self.currentPage = 1
        self.hasMore = hasMore
        self.lastRefreshError = nil
    }

    /// Keeps existing `items` on pull-to-refresh failure and records error for toast.
    public mutating func applyRefreshFailure(_ message: String = "刷新失败，稍后再试") {
        self.lastRefreshError = message
    }

    public mutating func appendPage(_ pageItems: [Item], hasMore: Bool) {
        self.items.append(contentsOf: pageItems)
        self.currentPage += 1
        self.hasMore = hasMore
        self.lastRefreshError = nil
    }
}

// MARK: - FIN-17-4: Order Detail Team, Seats, Club & Merchant Consent

public struct OrderDetailExtraActionsModel: Equatable, Sendable {
    public let hasTeamSection: Bool
    public let teamName: String?
    public let hasSeatsEntry: Bool
    public let clubID: Int?
    public let clubName: String?
    public let isClubMember: Bool
    public let merchantConsentText: String?

    public init(
        hasTeamSection: Bool = false,
        teamName: String? = nil,
        hasSeatsEntry: Bool = false,
        clubID: Int? = nil,
        clubName: String? = nil,
        isClubMember: Bool = false,
        merchantConsentText: String? = nil
    ) {
        self.hasTeamSection = hasTeamSection
        self.teamName = teamName
        self.hasSeatsEntry = hasSeatsEntry
        self.clubID = clubID
        self.clubName = clubName
        self.isClubMember = isClubMember
        self.merchantConsentText = merchantConsentText
    }
}

// MARK: - PLY-21-5: Ticket Wallet Card Copy

public struct TicketWalletCardSubline: Equatable, Sendable {
    public let typeLabel: String
    public let daysLeftText: String?
    public let verifiedProgressText: String?
    public let partyLabel: String?

    public init(
        typeLabel: String,
        daysLeftText: String? = nil,
        verifiedProgressText: String? = nil,
        partyLabel: String? = nil
    ) {
        self.typeLabel = typeLabel
        self.daysLeftText = daysLeftText
        self.verifiedProgressText = verifiedProgressText
        self.partyLabel = partyLabel
    }

    public var combinedSubline: String {
        [typeLabel, daysLeftText, partyLabel, verifiedProgressText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

// MARK: - PLY-26-5: Template Shelf Operation Scope

public enum TemplateShelfOperationScope: String, Equatable, Sendable {
    case player = "PLAYER"
    case merchant = "MERCHANT"
}
