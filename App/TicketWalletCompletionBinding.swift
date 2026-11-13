import SwiftUI

/// Source wallet filter (`subpackageMember/signup` 全部 / 即将开始 / 已通关) reads the server
/// `topicCompleted` flag. Until a reader is injected, the filter stays hidden.
@MainActor protocol TicketWalletCompletionReading {
    /// `true` completed, `false` upcoming. `nil` stays in 全部 only (absent hides the completed state; a non-boolean is unknown).
    func topicCompleted(_ ticket: TicketWalletTicket) -> Bool?
}

private struct TicketWalletCompletionReaderKey: EnvironmentKey {
    static let defaultValue: (any TicketWalletCompletionReading)? = nil
}

extension EnvironmentValues {
    var ticketWalletCompletionReader: (any TicketWalletCompletionReading)? {
        get { self[TicketWalletCompletionReaderKey.self] }
        set { self[TicketWalletCompletionReaderKey.self] = newValue }
    }
}

enum TicketWalletFilter: String, CaseIterable, Hashable {
    case all, upcoming, completed
    var titleKey: String { "mpfresh.ticketWallet.filter.\(rawValue)" }
    /// Source nav label: 票夹 when 全部, otherwise the picked filter.
    var navKey: String { self == .all ? "mpfresh.ticketWallet.filter.nav" : titleKey }
    var emptyKey: String { "mpfresh.ticketWallet.filter.empty.\(rawValue)" }
}
