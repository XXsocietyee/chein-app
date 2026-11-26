#if DEBUG
import SwiftUI

/// HANDOVER 44. DEBUG hosts for batch-7 screens whose view types already compile on this base.
/// A paid screen stays on the closed copy: the money switch is not opened and no charge is shown.
/// A missing fact is an em dash. `--design-fixture cur3-<name>`.
/// The table is `docs/release/receipts/ui-cur-fixtures-3.md`.
enum CurFixtures3 {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur3-ws-purchased": return frame("Purchased workshop · reads off", zh: false) { Cur3PurchasedHost(zh: false) }
        case "cur3-ws-purchased-zh": return frame("Purchased workshop · reads off", zh: true) { Cur3PurchasedHost(zh: true) }
        case "cur3-ws-purchased-unavailable": return frame("Purchased workshop · no browser", zh: false) { Cur3PurchasedUnavailable(zh: false) }
        case "cur3-ws-purchased-unavailable-zh": return frame("Purchased workshop · no browser", zh: true) { Cur3PurchasedUnavailable(zh: true) }
        case "cur3-ws-install": return frame("Paid install · no charge", zh: false) { Cur3InstallHost(zh: false, decode: true) }
        case "cur3-ws-install-zh": return frame("Paid install · no charge", zh: true) { Cur3InstallHost(zh: true, decode: true) }
        case "cur3-ws-install-undecoded": return frame("Paid install · unknown item", zh: false) { Cur3InstallHost(zh: false, decode: false) }
        case "cur3-ws-install-undecoded-zh": return frame("Paid install · unknown item", zh: true) { Cur3InstallHost(zh: true, decode: false) }
        case "cur3-video-bounty": return frame("Video bounty", zh: false) { Cur3VideoBountyHost(zh: false, failed: false) }
        case "cur3-video-bounty-zh": return frame("Video bounty", zh: true) { Cur3VideoBountyHost(zh: true, failed: false) }
        case "cur3-video-bounty-failed": return frame("Video bounty · read failed", zh: false) { Cur3VideoBountyHost(zh: false, failed: true) }
        case "cur3-video-bounty-failed-zh": return frame("Video bounty · read failed", zh: true) { Cur3VideoBountyHost(zh: true, failed: true) }
        case "cur3-video-bounty-empty": return frame("Video bounty · empty", zh: false) { Cur3VideoBountyHost(zh: false, failed: false, empty: true) }
        default: return nil
        }
    }

    @MainActor private static func frame<V: View>(_ title: String, zh: Bool, @ViewBuilder _ view: @escaping () -> V) -> AnyView {
        AnyView(Cur3Frame(title: title, zh: zh, content: view))
    }
}

private enum Cur3 {
    static let base = URL(string: "https://fixture.example")!
    static let token = "synthetic-fixture-token"
    static let hash = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    static let paidItemJSON = #"{"licenseId":"w18-paid-1","moduleId":"harbor","purchasedVersionId":"v1","contentHash":"\#(hash)","acquiredAt":"2026-11-13T02:00:00Z","termsVersion":"t1","termsHash":"\#(hash)","status":"ACTIVE","commercialUse":"PROHIBITED","adaptation":"BIND_RESOURCES_ONLY","translation":"PROHIBITED","allowedRegions":["CN"],"themeLimit":{"unlimited":false,"maximum":1},"merchantLimit":{"unlimited":true,"maximum":0},"runLimit":{"unlimited":false,"maximum":3},"acquisition":"PAID","buyerKind":"INDIVIDUAL","useDuration":"PERPETUAL_PURCHASED_VERSION","updates":"EXACT_PURCHASED_VERSION","redistribution":"PROHIBITED","contentUseStatus":"PAID_INSTALL_AUTHORITY_UNAVAILABLE","purchaseActionStatus":"CHANNEL_APPROVAL_REQUIRED"}"#

    static func paidItem() -> WorkshopPurchasedItem? {
        try? JSONDecoder().decode(WorkshopPurchasedItem.self, from: Data(paidItemJSON.utf8))
    }

    static func locale(_ zh: Bool) -> Locale { Locale(identifier: zh ? "zh-Hans" : "en") }
}

@MainActor private struct Cur3Frame<Content: View>: View {
    let title: String
    let zh: Bool
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            content()
            Text(verbatim: title + " · DEBUG fixture · synthetic")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.sm)
                .accessibilityIdentifier("cur3.fixture.footer")
        }
        .environment(\.locale, Cur3.locale(zh))
        .themeDomain(.player)
        .preferredColorScheme(.dark)
    }
}

@MainActor private final class Cur3PurchasedReader: WorkshopPurchasedReading {
    func list(before: Int64?, lifetime: WorkshopPurchasedReadLifetime) async throws -> WorkshopPurchasedPage {
        throw WorkshopPurchasedIssue.disabled
    }
    func detail(licenseId: String, lifetime: WorkshopPurchasedReadLifetime) async throws -> WorkshopPurchasedDetail {
        throw WorkshopPurchasedIssue.disabled
    }
}

@MainActor private struct Cur3PurchasedHost: View {
    @StateObject private var session = AppSession()
    let zh: Bool
    private let browser: WorkshopPurchasedBrowser?
    init(zh: Bool) {
        self.zh = zh
        guard let play = try? PlayExperienceSession(accountID: 7, epoch: 1, namespace: "synthetic", token: Cur3.token) else {
            browser = nil
            return
        }
        let context = RuntimeDependencyContext(market: .china, baseURL: Cur3.base, role: "player", session: play)
        browser = WorkshopPurchasedBrowser(reader: Cur3PurchasedReader(), lease: ContentDraftSessionLease(context: context, current: { context }))
    }
    var body: some View {
        if let browser {
            WorkshopPurchasedLibraryView(browser: browser)
                .environmentObject(session)
                .environment(\.locale, Cur3.locale(zh))
        } else {
            Text(verbatim: "—")
        }
    }
}

@MainActor private struct Cur3PurchasedUnavailable: View {
    let zh: Bool
    var body: some View {
        NavigationStack {
            List {
                WorkshopPurchasedAccountLink(browser: nil)
            }
        }
        .environment(\.locale, Cur3.locale(zh))
    }
}

@MainActor private struct Cur3InstallHost: View {
    let zh: Bool
    let decode: Bool
    var body: some View {
        if decode, let item = Cur3.paidItem() {
            List {
                WorkshopPaidInstallEntry(item: item, makeController: { _ in nil })
            }
            .environment(\.locale, Cur3.locale(zh))
        } else {
            Text(verbatim: "—")
                .accessibilityIdentifier("cur3.install.unknown")
        }
    }
}

@MainActor private struct Cur3VideoBountyHost: View {
    let zh: Bool
    let failed: Bool
    var empty = false
    var body: some View {
        NavigationStack {
            VideoBountyView(
                state: failed ? Cur3.failedBounty : (empty ? Cur3.emptyBounty : Cur3.readyBounty),
                campaign: nil,
                onLoad: {},
                onSubmit: { _, _, _, _, _ in },
                onAppeal: { _, _ in },
                onCancel: { _ in }
            )
        }
        .environment(\.locale, Cur3.locale(zh))
    }
}

private extension Cur3 {
    static var readyBounty: VideoBountyState {
        var state = VideoBountyState()
        state.submissions = .ready([
            VideoBountySubmissionRow(
                id: "sub-1",
                platform: nil,
                sourceURL: "https://fixture.example/night",
                status: .approved,
                reviewNote: nil,
                windowEndText: "2026.11.30",
                canAppeal: false,
                canCancel: false
            )
        ])
        state.accruals = .ready([
            VideoBountyAccrualRow(id: "acc-1", amountText: nil, views: nil, groupViews: nil)
        ])
        return state
    }

    static var emptyBounty: VideoBountyState {
        var state = VideoBountyState()
        state.submissions = .ready([])
        state.accruals = .ready([])
        return state
    }

    static var failedBounty: VideoBountyState {
        var state = VideoBountyState()
        state.submissions = .failed(nil)
        state.accruals = .failed(nil)
        return state
    }
}
#endif
