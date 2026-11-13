import SwiftUI

/// Production reader for the ticket-wallet filter. It only reports the flag already decoded
/// on the registration list row. It does not invent tickets or send another request.
@MainActor struct TicketWalletDecodedCompletionReader: TicketWalletCompletionReading {
    func topicCompleted(_ ticket: TicketWalletTicket) -> Bool? { ticket.topicCompletedFlag }
}

/// Injected at the player root so every ticket wallet sees the same read-only reader.
/// `AppSession` and `AppCompositionRoot` stay unchanged.
struct TicketWalletCompletionRootModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.environment(\.ticketWalletCompletionReader, TicketWalletDecodedCompletionReader())
    }
}
