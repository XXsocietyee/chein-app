import SwiftUI

/// BINDING STUB for Cursor (mp-mpfresh receipt): the source wallet filter splits tickets by the server
/// `topicCompleted` flag (`subpackageMember/signup` 全部 / 即将开始 / 已通关). `TicketWalletTicket` does not decode
/// that flag yet. Until a Core reader is injected, the filter stays hidden (capability absent => hidden).
@MainActor protocol TicketWalletCompletionReading {
    /// `nil` = unknown; unknown tickets only appear under 全部.
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
