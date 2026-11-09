#if DEBUG
import SwiftUI

/// E5 design fixtures (utility and long-tail player pages). Synthetic data, debug only, never in Release.
/// Every fixture mounts the REAL view with an offline fake source; titles and names say "Sample" / "debug fixture".
enum E5Fixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e5-route-error":
            return wrap(NavigationStack { NativeRouteErrorView(failure: .cannotOpen, goHome: {}) })
        case "e5-route-legacy":
            return wrap(NavigationStack { NativeRouteErrorView(failure: .legacyTeamLink, goHome: {}) })
        case "e5-circle-link":
            return wrap(NavigationStack { PlayCircleRetiredLinkView(goHome: {}) })
        case "e5-guide":
            return wrap(NavigationStack { SocialPlayGuideView(reader: SocialAccountFixtureReader(.content)) })
        case "e5-guide-empty":
            return wrap(NavigationStack { SocialPlayGuideView(reader: SocialAccountFixtureReader(.empty)) })
        case "e5-info-detail":
            let id = (try? SocialAccountSyntheticFixtures.information().first(where: \.isUsable)?.id) ?? 1
            return wrap(NavigationStack { SocialInformationView(id: id, reader: SocialAccountFixtureReader(.content)) })
        case "e5-info-link":
            return wrap(NavigationStack { SocialInformationView(id: 0, reader: SocialAccountFixtureReader(.content)) })
        case "e5-h5-waiting":
            return wrap(E5H5Host(kind: .waiting))
        case "e5-h5-shell":
            return wrap(E5H5Host(kind: .shell))
        case "e5-h5-declared":
            return wrap(E5H5Host(kind: .declared))
        case "e5-invoice-history": return wrap(E5InvoiceHost(screen: .history, scenario: .rows))
        case "e5-invoice-empty": return wrap(E5InvoiceHost(screen: .history, scenario: .empty))
        case "e5-invoice-detail": return wrap(E5InvoiceHost(screen: .detail(2002), scenario: .rows))
        case "e5-invoice-detail-rejected": return wrap(E5InvoiceHost(screen: .detail(2003), scenario: .rows))
        case "e5-invoice-titles": return wrap(E5InvoiceHost(screen: .titles, scenario: .rows))
        case "e5-invoice-apply": return wrap(E5InvoiceHost(screen: .apply, scenario: .rows))
        case "e5-free-explore": return wrap(E5FreeExploreHost())
        case "e5-creator-projects":
            return wrap(NavigationStack { CreatorContentProjectsView(reader: CreatorContentFixtureReader(), onOpen: { _ in }) })
        case "e5-creator-empty":
            let reader = CreatorContentFixtureReader(); reader.projectsJSON = #"{"code":200,"data":{"rows":[],"total":0}}"#
            return wrap(NavigationStack { CreatorContentProjectsView(reader: reader, onOpen: { _ in }) })
        case "e5-creator-error":
            let reader = CreatorContentFixtureReader(); reader.failure = .httpStatus(503)
            return wrap(NavigationStack { CreatorContentProjectsView(reader: reader, onOpen: { _ in }) })
        case "e5-creator-center":
            return wrap(NavigationStack { CreatorContentCenterView(reader: CreatorContentFixtureReader()) })
        case "e5-creator-rejected":
            let reader = CreatorContentFixtureReader()
            reader.centerJSON = #"{"code":200,"data":{"applyStatus":"rejected","rejectReason":"Sample rejection reason (debug fixture)"}}"#
            return wrap(NavigationStack { CreatorContentCenterView(reader: reader) })
        case "e5-club-ai":
            return wrap(NavigationStack {
                ClubAIDesignView(clubID: 1, session: nil, flow: ClubAIDesignFlow(generator: nil, current: { nil }), onAdopt: { _ in })
            })
        case "e5-external-game":
            return wrap(NavigationStack { ScrollView { ExternalGameLibrarySection(store: ExternalGameStore()).padding(CYSpacing.lg) } })
        case "e5-crop": return wrap(MiniCropFixtureHostView())
        default: return nil
        }
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(view.themeDomain(.player).cyDomainPageBackground().themeDomain(.player).environment(\.colorScheme, .dark))
    }
}

// MARK: - H5

@MainActor private struct E5H5Host: View {
    enum Kind { case waiting, shell, declared }
    let kind: Kind
    private static let hash = String(repeating: "ab", count: 32)
    private struct Source: WorkshopOriginalInstallReading {
        func request(_ requestID: String, identity: WorkshopInstallIdentity) async throws -> WorkshopOriginalInstallFact {
            throw WorkshopOriginalInstallError.unknown
        }
    }
    var body: some View {
        let identity = WorkshopInstallIdentity(licenseId: "lic-sample", moduleId: "mod-sample", releaseId: "rel-sample",
                                               contentHash: Self.hash, termsHash: Self.hash)
        let frozen = H5FrozenCapability(signedDomains: ["play.example.test"], sdkCapabilities: ["answer"],
                                        packageVersion: "1.0.0", contentHash: Self.hash)
        switch kind {
        case .waiting:
            if let identity {
                H5ShellParentFlowView(requestID: "00000000-0000-4000-8000-000000000001", shellURL: nil, launch: nil,
                                      identity: identity, source: Source(), onClose: {})
            }
        case .shell:
            if let identity {
                H5PlatformShellView(shellURL: nil, launch: nil, requestID: "00000000-0000-4000-8000-000000000001",
                                    identity: identity, source: Source(), onClose: {})
            }
        case .declared:
            if let frozen {
                NavigationStack {
                    H5DeclaredSessionView(frozen: frozen, host: "play.example.test", capability: "answer", sdkVersion: "1.0.0", launch: nil)
                }
            }
        }
    }
}

// MARK: - Invoices

@MainActor private final class E5InvoiceHolder: ObservableObject {
    enum Scenario { case rows, empty }
    let model: InvoiceLaunchPresentation
    @MainActor private final class Memory: InvoiceLaunchStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    @MainActor private final class Wire: HTTPTransport {
        let scenario: Scenario
        init(_ scenario: Scenario) { self.scenario = scenario }
        private func order(_ id: Int, _ title: String, _ amount: Double) -> [String: Any] {
            ["orderId": String(id), "amount": amount, "orderTitle": title]
        }
        private func application(_ id: Int, _ status: String, summary: Bool) -> [String: Any] {
            let orders = [order(21, "Sample city walk ticket (debug fixture)", 68), order(22, "Sample museum trail ticket (debug fixture)", 52.5)]
            var value: [String: Any] = [
                "id": String(id), "applicationNo": "SAMPLE-\(id)", "status": status, "titleType": id % 2 == 0 ? "COMPANY" : "PERSONAL",
                "titleName": id % 2 == 0 ? "Sample Studio Co. (debug fixture)" : "Sample Person (debug fixture)",
                "totalAmount": 120.5, "orderCount": 2, "createTime": "2026-10-2\(id % 10) 14:30",
                "orders": summary ? [] : orders]
            if id % 2 == 0 { value["taxNoMasked"] = "91******1234" }
            if status == "ISSUED" { value["invoiceNo"] = "SAMPLE-INV-0001"; value["issuedAt"] = "2026-10-28 09:12" }
            if status == "REJECTED" { value["rejectReason"] = "Sample reason: tax number does not match (debug fixture)" }
            return value
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            let none: [[String: Any]] = []
            let titles: [[String: Any]] = [
                ["id": "11", "titleType": "PERSONAL", "titleName": "Sample Person (debug fixture)", "isDefault": true],
                ["id": "12", "titleType": "COMPANY", "titleName": "Sample Studio Co. (debug fixture)", "taxNoMasked": "91******1234", "isDefault": false]]
            let eligible: [[String: Any]] = [order(31, "Sample night market pass (debug fixture)", 36), order(32, "Sample river cruise (debug fixture)", 88)]
            let list: [[String: Any]] = [application(2001, "SUBMITTED", summary: true), application(2002, "ISSUED", summary: true),
                                         application(2003, "REJECTED", summary: true), application(2004, "CANCELLED", summary: true)]
            let data: Any
            switch request.url?.lastPathComponent {
            case "titles": data = scenario == .empty ? none : titles
            case "eligible": data = scenario == .empty ? none : eligible
            case "list": data = scenario == .empty ? none : list
            case "detail":
                let object = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: Any]
                let id = (object?["id"] as? NSNumber)?.intValue ?? 2001
                let status = [2001: "SUBMITTED", 2002: "ISSUED", 2003: "REJECTED", 2004: "CANCELLED"][id] ?? "SUBMITTED"
                data = application(id, status, summary: false)
            default: data = none
            }
            return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": data]), 200)
        }
    }
    init(_ scenario: Scenario) {
        let session = try! InvoiceLaunchSession(baseURL: URL(string: "https://example.test/native")!, namespace: "e5-fixture",
                                                accountID: 7, role: "player", epoch: 1, token: "synthetic-token")
        let service = InvoiceLaunchService(session: session, transport: Wire(scenario), enabled: { true }, current: { session })
        let store = InvoiceLaunchPendingStore(session: session, storage: Memory())
        model = InvoiceLaunchPresentation(coordinator: try! InvoiceLaunchCoordinator(service: service, store: store),
                                          isCurrent: { true }, permits: { _ in true })
    }
}

@MainActor private struct E5InvoiceHost: View {
    enum Screen { case history, detail(Int64), titles, apply }
    let screen: Screen
    @StateObject private var holder: E5InvoiceHolder
    init(screen: Screen, scenario: E5InvoiceHolder.Scenario) {
        self.screen = screen
        _holder = StateObject(wrappedValue: E5InvoiceHolder(scenario))
    }
    var body: some View {
        NavigationStack {
            switch screen {
            case .history: InvoiceLaunchHistoryView(model: holder.model)
            case .detail(let id): InvoiceLaunchDetailView(model: holder.model, applicationID: id)
            case .titles: InvoiceLaunchTitlesView(model: holder.model)
            case .apply: InvoiceLaunchApplyView(model: holder.model)
            }
        }
    }
}

// MARK: - Free-explore bundle launch

@MainActor private struct E5FreeExploreHost: View {
    @State private var model: FreeExploreBundleLaunchModel?
    @MainActor private final class Store: TemplateAuthoringStorage {
        var values: [String: Data] = [:]
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws { values.removeValue(forKey: key) }
    }
    @MainActor private final class Wire: FreeExploreLaunchServing {
        let session: FreeExploreLaunchSession
        var isCurrent = true
        var permitsReservationDispatch = false
        init() throws {
            session = try .init(baseURL: URL(string: "https://example.test")!, accountID: 7, market: "CN", namespace: "e5-fixture",
                                role: "player", epoch: 1, token: "synthetic-token")
        }
        private func decode<T: Decodable>(_ value: Any) throws -> T {
            try JSONDecoder().decode(T.self, from: JSONSerialization.data(withJSONObject: value))
        }
        func catalog(topicID: FreeExploreLaunchID) async throws -> FreeExploreLaunchCatalog {
            try decode(["topicId": 88, "topicName": "Sample free-explore bundle (debug fixture)", "productType": 2, "saleEnabled": false, "reservationEnabled": true,
                        "items": [["chapterId": 3, "name": "Sample old-town chapter", "unitsPerHolder": 1,
                                   "stores": [["offerId": 29, "merchantName": "Sample Tea House", "validEnd": "2026-12-31"],
                                              ["offerId": 30, "merchantName": "Sample Noodle Bar", "validEnd": "2026-12-31"]]]]])
        }
        func order(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchOrder {
            try decode(["registrationId": 41, "bundle": [
                "order": ["registrationId": 41, "holderMemberId": 7, "topicId": 88],
                "units": [["id": 17, "registrationId": 41, "holderMemberId": 7, "chapterId": 3, "status": "AVAILABLE"]],
                "reservations": []]])
        }
        func reserve(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation { throw FreeExploreLaunchFailure.disabled }
        func receipt(_ command: FreeExploreLaunchReservationCommand) async throws -> FreeExploreLaunchReservation? { nil }
        func refundQuote(registrationID: FreeExploreLaunchID) async throws -> FreeExploreLaunchRefundQuote { throw FreeExploreLaunchFailure.disabled }
    }
    var body: some View {
        NavigationStack {
            if let model { FreeExploreBundleLaunchView(model: model) }
        }.task {
            guard model == nil, let wire = try? Wire(), let topic = try? FreeExploreLaunchID(88), let registration = try? FreeExploreLaunchID(41) else { return }
            model = try? FreeExploreBundleLaunchModel(topicID: topic, registrationID: registration, service: wire,
                                                      pending: FreeExploreLaunchPendingStore(storage: Store(), session: wire.session), dispatchAllowed: { true })
        }
    }
}
#endif
