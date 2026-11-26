import PassKit
import SwiftUI

// Design P1 G-056: "Add to Apple Wallet" with Apple's own button (`AddPassToWalletButton`, the SwiftUI
// `PKAddPassButton`). The server does not send a signed .pkpass today (no ticket field carries one, and this lane
// adds no request), so this is a guarded hook: the button renders only when a provider installed by the host returns
// signed pass bytes for the ticket id, the device can add passes, and PassKit accepts the bytes. Otherwise it draws
// nothing and the pass sheet looks exactly as before.

/// Returns already-downloaded, signed .pkpass bytes for a ticket id, or nil. Must not start a request.
typealias TicketAppleWalletPassData = @MainActor (Int) -> Data?

private struct TicketAppleWalletPassDataKey: EnvironmentKey {
    static let defaultValue: TicketAppleWalletPassData? = nil
}

extension EnvironmentValues {
    /// Nil (the default) keeps the Add to Apple Wallet button hidden everywhere.
    var ticketAppleWalletPassData: TicketAppleWalletPassData? {
        get { self[TicketAppleWalletPassDataKey.self] }
        set { self[TicketAppleWalletPassDataKey.self] = newValue }
    }
}

/// Apple's Add to Apple Wallet button for one ticket; empty unless a signed pass is available locally.
struct TicketAppleWalletPassButton: View {
    let ticketID: Int
    @Environment(\.ticketAppleWalletPassData) private var passData
    @Environment(\.locale) private var locale
    @State private var addedCount = 0

    var body: some View {
        if let provide = passData, PKAddPassesViewController.canAddPasses(),
           let bytes = provide(ticketID), let pass = try? PKPass(data: bytes) {
            AddPassToWalletButton([pass]) { added in
                guard added else { return }
                addedCount += 1
                if IslandCenter.isEnabled {
                    IslandCenter.shared.show(IslandItem(kind: .status(.success), title: .key("ticketWallet.appleWallet.added")))
                } else {
                    AccessibilityNotification.Announcement(appLocalized("ticketWallet.appleWallet.added", locale: locale)).post()
                }
            }
            .frame(maxWidth: 360, minHeight: 48)
            .sensoryFeedback(.success, trigger: addedCount)
            .accessibilityIdentifier("ticketPass.addToAppleWallet")
        }
    }
}
