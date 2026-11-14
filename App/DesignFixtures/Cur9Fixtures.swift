#if DEBUG
import SwiftUI

/// DEBUG hosts for the three branches merged into ui/cur-fixtures-9.
/// Each pair mounts a view that already exists. Nothing here opens money on
/// www.chengyinhub.com, and the ledger transport never treats that host as success.
/// Launch with `--design-fixture cur9-<id>`.
enum Cur9Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "cur9-growth-pushed": return AnyView(Cur9TabShell(pushed: true))
        case "cur9-tab-root": return AnyView(Cur9TabShell(pushed: false))
        case "cur9-offline-sync": return AnyView(Cur9OfflineHost(failed: false))
        case "cur9-offline-still": return AnyView(Cur9OfflineHost(failed: true))
        case "cur9-ledger": return AnyView(Cur9LedgerHost(known: true))
        case "cur9-ledger-unknown": return AnyView(Cur9LedgerHost(known: false))
        default: return nil
        }
    }
}

private enum Cur9Push: Hashable {
    case growth
}

/// Player tab shell from ui/h-visual-bugs. A pushed growth page hides the tab bar
/// and shows the palette contrast already on `GrowthCenterView`. The root keeps the bar.
@MainActor private struct Cur9TabShell: View {
    private let pushed: Bool
    @State private var visibility = CYTabBarVisibility()
    @State private var tab = RootTab.home
    @State private var path: [Cur9Push]
    @State private var reader: GrowthCenterFixtureReader

    init(pushed: Bool) {
        self.pushed = pushed
        _path = State(initialValue: pushed ? [.growth] : [])
        _reader = State(initialValue: GrowthCenterFixtureReader(scenario: .content))
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                Text("tabBar.home")
                    .accessibilityIdentifier("cur9.root")
                    .navigationDestination(for: Cur9Push.self) { _ in
                        GrowthCenterView(reader: reader)
                    }
            }
            .tabItem { Label("tabBar.home", systemImage: "house") }
            .tag(RootTab.home)
            .environment(\.cyTabBarVisibility, visibility)
        }
        .overlay { CYNightTabBar(selection: tab, isHidden: visibility.isHidden) }
        .background(alignment: .topLeading) {
            Color.clear
                .frame(width: 1, height: 1)
                .accessibilityIdentifier(visibility.isHidden ? "cur9.tabBar.hidden" : "cur9.tabBar.visible")
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
    }
}

/// Offline write banner plus the roam sync status. The tracker is updated in memory.
/// There is no transport and no retry action.
@MainActor private struct Cur9OfflineHost: View {
    let failed: Bool

    private var syncOffline: Bool {
        var tracker = RoamSyncStatusTracker(systemConnected: !failed)
        if failed { return tracker.isOffline }
        tracker.recordOutcome(netFail: true)
        tracker.recordOutcome(netFail: true)
        return tracker.isOffline
    }

    var body: some View {
        List {
            if syncOffline {
                CYStatusOfflineBanner(
                    messageKey: RoamSyncStatusTracker.offlineKey,
                    stillOffline: failed
                )
            }
            CYOfflineWriteStatusBanner(
                status: failed ? .rejected(count: 1) : .queued(count: 1),
                isOnline: false
            )
        }
        .accessibilityIdentifier(failed ? "cur9.offline.still" : "cur9.offline.sync")
        .themeDomain(.player)
        .preferredColorScheme(.dark)
    }
}

/// Merchant direct-receivable ledger and personal settlement/mine.
/// A ledger amount is the text `Sweep2ClubDirectLedgerSection` already formats.
/// Settlement on www.chengyinhub.com stays on the closed chip. An unknown ledger
/// does not become 0; the fixture draws the existing em dash.
@MainActor private struct Cur9LedgerHost: View {
    let known: Bool
    private let ledgerClient: Sweep2Client?
    private let settlementClient: Sweep2Client?

    init(known: Bool) {
        self.known = known
        ledgerClient = Cur9LedgerClients.make(host: "8120.example.test", known: known)
        settlementClient = known ? Cur9LedgerClients.make(host: "www.chengyinhub.com", known: false) : nil
    }

    var body: some View {
        List {
            Sweep2ClubDirectLedgerSection(scope: .merchant())
                .environment(\.sweep2Client, ledgerClient)
            ClubPersonalSettlementSection()
                .environment(\.sweep2Client, settlementClient)
            if !known {
                Text(verbatim: "—")
                    .accessibilityIdentifier("cur9.ledger.unknown")
            }
        }
        .accessibilityIdentifier(known ? "cur9.ledger" : "cur9.ledger.missing")
        .themeDomain(.merchant)
        .preferredColorScheme(.light)
    }
}

private enum Cur9LedgerClients {
    static func make(host: String, known: Bool) -> Sweep2Client? {
        guard let base = URL(string: "https://\(host)") else { return nil }
        guard let configuration = try? APIConfiguration(baseURL: base) else { return nil }
        return Sweep2Client(
            configuration: configuration,
            transport: Cur9LedgerTransport(known: known),
            tokenProvider: { "synthetic-fixture-token" }
        )
    }
}

private struct Cur9LedgerTransport: HTTPTransport {
    let known: Bool

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        let host = request.url?.host?.lowercased() ?? ""
        if host == "www.chengyinhub.com" {
            throw URLError(.cannotConnectToHost)
        }
        let path = request.url?.path ?? ""
        if !known || !path.contains("club-direct-merchant") {
            return (Data(#"{"code":200,"data":{"status":"unknown"}}"#.utf8), 200)
        }
        let body = #"{"code":200,"data":[{"id":11,"redemptionId":21,"topicId":31,"payerClubId":41,"merchantMemberId":51,"status":"OPEN","perHeadFeeSnapshot":"12.50","createTime":"2026-11-14T03:00:00","claimId":"7"}]}"#
        return (Data(body.utf8), 200)
    }
}
#endif
