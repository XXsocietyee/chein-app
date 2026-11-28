#if DEBUG
import SwiftUI

enum RegistrationFixtureScenario: String, CaseIterable {
    case standard, noPaymentParameters, unknownAmounts, quoteError, participantsError
    case createTimeout, readbackError, conflictingStatus, soldOut, disabled, signupClosed
    case waitlistWaiting, waitlistOffer, waitlistExpiringOffer, waitlistClaimed, waitlistConverted, waitlistOrderError
    /// Source checkout parity: isSignUp=1 banner, ticket meeting point and a priority-only club benefit.
    case alreadyRegistered
    /// Server quote deducts nothing while the viewer has points. The sheet turns points off and quotes again.
    case pointsRefused
    var isWaitlist: Bool { self == .waitlistWaiting || isOffer || isOrder }
    var isOrder: Bool { self == .waitlistClaimed || self == .waitlistConverted || self == .waitlistOrderError }
    var isOffer: Bool { self == .waitlistOffer || self == .waitlistExpiringOffer }
    static func selected(arguments: [String]) -> Self? {
        guard let index = arguments.firstIndex(of: "--uitesting-registration-fixture"),
              arguments.indices.contains(index + 1) else { return nil }
        return Self(rawValue: arguments[index + 1])
    }
}

/// Explicit offline fixtures only. Every response is in-memory synthetic JSON. No URL,
/// HTTP transport, production credential, consent endpoint or payment SDK is referenced.
@MainActor
private final class RegistrationFixtureStore: RegistrationCoordinatingService, ProfileReading, RegistrationWaitlistServing {
    let scenario: RegistrationFixtureScenario
    let isConfigured = true
    let identity: ProfileReadIdentity? = .init(accountID: 9400, epoch: 1)
    private var waitlistState = "NONE"
    private var offerDeadline: String
    private var quotes = 0
    init(_ scenario: RegistrationFixtureScenario) {
        self.scenario = scenario
        offerDeadline = ISO8601DateFormatter().string(from: scenario == .waitlistExpiringOffer ? Date.distantFuture : Date().addingTimeInterval(3600))
        if scenario.isOffer { waitlistState = "OFFERED" }
        if scenario.isOrder { waitlistState = scenario == .waitlistConverted ? "CONVERTED" : "CLAIMED" }
    }
    func armOfferExpiry() {
        guard scenario == .waitlistExpiringOffer else { return }
        offerDeadline = ISO8601DateFormatter().string(from: Date().addingTimeInterval(20))
    }
    func quote(_ selection: RegistrationQuoteRequest, token: String) async throws -> RegistrationQuote {
        quotes += 1
        if scenario == .quoteError, quotes == 1 { throw URLError(.notConnectedToInternet) }
        if scenario == .unknownAmounts { return try decode(#"{"pointsUsable":true,"quoteSign":"offline-only"}"#) }
        if scenario == .pointsRefused, selection.usePoints {
            return try decode(#"{"payAmount":12.5,"pointsUsed":0,"pointsDeductYuan":0,"pointsUsable":true,"memberDiscountYuan":0,"couponDeductYuan":0,"quoteSign":"offline-only-points-refused"}"#)
        }
        let amount = selection.ticketID == 9403 ? 0 : (selection.usePoints ? 10 : 12.5)
        return try decode("""
        {"payAmount":\(amount),"pointsUsed":\(selection.usePoints ? 250 : 0),
         "pointsDeductYuan":\(selection.usePoints ? 2.5 : 0),"pointsUsable":true,
         "memberDiscountYuan":0,"couponDeductYuan":0,"clubMember":\(scenario == .alreadyRegistered),
         "prioritySignupEnabled":\(scenario == .alreadyRegistered),
         "quoteSign":"offline-only-\(selection.ticketID ?? 0)-\(selection.usePoints)"}
        """)
    }
    func create(_ intent: RegistrationCreateIntent, token: String) async throws -> RegistrationCreateResult {
        if scenario.isOffer {
            guard intent.selection.waitlistOffer == intent.waitlistOffer, intent.waitlistOffer?.id == 9405,
                  intent.waitlistOffer?.token == "offline-only-offer" else { throw APIError.invalidRequest }
        }
        if scenario == .createTimeout { throw URLError(.timedOut) }
        if scenario == .noPaymentParameters || intent.selection.ticketID == 9403 {
            return try decode(#"{"registrationId":9401,"registrationNo":"OFFLINE-9401","payableAmount":0}"#)
        }
        return try decode("""
        {"registrationId":9401,"registrationNo":"OFFLINE-9401","payableAmount":\(intent.selection.usePoints ? 10 : 12.5),"payParams":{"fixture":"non-executable"}}
        """)
    }
    func readStatus(registrationID: Int, token: String) async throws -> RegistrationStatusSnapshot {
        if scenario == .readbackError { throw URLError(.notConnectedToInternet) }
        if scenario == .conflictingStatus { return try decode(#"{"id":9401,"registrationStatus":3,"paymentStatus":2,"verificationStatus":0}"#) }
        return try decode(#"{"id":9401,"registrationStatus":1,"paymentStatus":1,"verificationStatus":0}"#)
    }
    func status(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        guard scope.activityID == 9400, scope.ticketID == 9401 else { throw APIError.invalidRequest }
        let offer = waitlistState == "OFFERED" ? ",\"offerToken\":\"offline-only-offer\",\"offerExpiresAt\":\"\(offerDeadline)\"" : ""
        let order = scenario.isOrder ? ",\"registrationId\":9417" : ""
        return try decode("{\"id\":9405,\"activityId\":9400,\"ticketId\":9401,\"memberId\":9400,\"state\":\"\(waitlistState)\",\"eligibilityState\":\"ELIGIBLE\",\"waitlistJoinAllowed\":true\(offer)\(order)}")
    }
    func join(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        waitlistState = "WAITING"; return try await status(scope)
    }
    func cancel(_ scope: RegistrationWaitlistScope) async throws -> RegistrationWaitlistStatus {
        waitlistState = "CANCELLED"; return try await status(scope)
    }
    func profileParticipants() async throws -> [ProfileParticipant] {
        if scenario == .participantsError { throw URLError(.notConnectedToInternet) }
        // Fixture names follow the UI language (coordinator 19:15: no English data in the Chinese UI).
        let zh = Locale.preferredLanguages.first?.hasPrefix("zh") == true
        let guest = zh ? "陈晓" : "Alex Chen"
        let saved = zh ? "林佳" : "Jamie Lin"
        return try decode("[{\"id\":9401,\"fullName\":\"\(guest)\",\"mobilePhone\":\"13800000000\"},{\"id\":9402,\"fullName\":\"\(saved)\",\"mobilePhone\":\"13900000000\",\"isDefault\":true}]")
    }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.invalidRequest }
    func profileOrders() async throws -> [ProfileOrder] { [] }
    func profileOrder(id: Int) async throws -> ProfileOrder {
        guard scenario.isOrder, id == 9417 else { throw APIError.invalidRequest }
        if scenario == .waitlistOrderError { throw URLError(.notConnectedToInternet) }
        let name = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "运河灯笼夜行" : "Riverside Lantern Walk"
        return try decode("{\"id\":9417,\"memberId\":9400,\"ownerType\":2,\"ownerId\":9400,\"ticketId\":9401,\"registrationNo\":\"OFFLINE-WAITLIST-9417\",\"registrationStatus\":0,\"paymentStatus\":0,\"cmsActivity\":{\"name\":\"\(name)\"}}")
    }
    func profileBadges() async throws -> ProfileBadgeWall { .init(identities: [], medals: []) }
    private func decode<T: Decodable>(_ json: String) throws -> T { try JSONDecoder().decode(T.self, from: Data(json.utf8)) }
}

@MainActor
private final class RegistrationFixtureModel: ObservableObject {
    let store: RegistrationFixtureStore
    let coordinator: RegistrationCoordinator
    let activity: ActivityDetail?
    let scenario: RegistrationFixtureScenario
    private(set) var expiryFlow: RegistrationUIFlow?
    @Published private(set) var expiryArmed = false
    init(scenario: RegistrationFixtureScenario) {
        self.scenario = scenario
        let store = RegistrationFixtureStore(scenario)
        self.store = store
        coordinator = RegistrationCoordinator(service: store, makeRequestID: { "offline-fixture-retained-intent" })
        try? coordinator.setAccount(id: 9400, token: "offline-fixture-unused-token")
        // Fixture text follows the UI language (coordinator 22:20: no English data in the Chinese sheet).
        let zh = Locale.preferredLanguages.first?.hasPrefix("zh") == true
        let tt: (String, String) -> String = { en, cn in zh ? cn : en }
        let activityName = tt("Riverside Lantern Walk", "运河灯笼夜行")
        let venue = tt("Gongchen Bridge, Hangzhou", "杭州拱宸桥")
        let standard = tt("Standard ticket", "标准票")
        let gathering = tt("East end of the bridge", "桥东入口")
        let openPrice = tt("Pay-on-site ticket", "现场定价票")
        let free = tt("Free ticket", "免费票")
        activity = try? JSONDecoder().decode(ActivityDetail.self, from: Data("""
        {"id":9400,"name":"\(activityName)","startDate":"2026-10-12 19:00:00","endDate":"2026-10-12 21:00:00",\(scenario == .alreadyRegistered ? "\"isSignUp\":1," : "")
         "addressName":"\(venue)","omsTicketList":[
         {"id":9401,"name":"\(standard)","price":12.5,"remainingInventory":\(scenario == .soldOut || scenario.isWaitlist ? 0 : 4),"startTime":\(scenario == .signupClosed ? "\"2020-01-01 00:00:00\"" : "null")\(scenario == .alreadyRegistered ? ",\"meetingPoint\":\"\(gathering)\"" : "")},
         {"id":9402,"name":"\(openPrice)","price":null,"remainingInventory":null},
         {"id":9403,"name":"\(free)","price":0,"remainingInventory":2}]}
        """.utf8))
        if scenario == .waitlistExpiringOffer, let activity {
            expiryFlow = RegistrationUIFlow(activity: activity, coordinator: coordinator,
                participantReader: store, currentIdentity: { store.identity }, quoteEnabled: true,
                creationPolicy: .offlineFixture, waitlistService: store)
        }
    }
    func armOfferExpiry() async {
        guard scenario == .waitlistExpiringOffer, let expiryFlow, !expiryArmed else { return }
        expiryArmed = true
        store.armOfferExpiry()
        // Refresh only the synthetic status once, then let the unchanged real clock expire it.
        await expiryFlow.loadWaitlist()
    }
}

/// The same coordinator survives reopening the sheet: no replacement after uncertainty.
@MainActor
struct RegistrationFixtureHostView: View {
    @StateObject private var model: RegistrationFixtureModel
    @State private var presented = true
    /// Design fixtures: hide the 离线演示 note (writes stay offline).
    private let hidesFixtureNotice: Bool
    init(scenario: RegistrationFixtureScenario = .standard, hidesFixtureNotice: Bool = false) {
        _model = StateObject(wrappedValue: RegistrationFixtureModel(scenario: scenario))
        self.hidesFixtureNotice = hidesFixtureNotice
    }
    var body: some View {
        VStack(spacing: 20) {
            Text("registration.form.fixtureNotice")
            Button("registration.form.open") { presented = true }
                .accessibilityIdentifier("registration.fixture.open")
        }
        .cySheet(isPresented: $presented) { Group {
            if let flow = model.expiryFlow {
                RegistrationSheetView(fixtureFlow: flow)
                    .safeAreaInset(edge: .bottom) {
                        if !model.expiryArmed {
                            Button("Arm synthetic offer expiry") { Task { await model.armOfferExpiry() } }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("registration.fixture.armExpiry")
                        }
                    }
                    .modifier(AccessibilityFixtureOptions())
            } else if let activity = model.activity {
                RegistrationSheetView(activity: activity, coordinator: model.coordinator,
                                      participantReader: model.store, orderReader: model.store, currentIdentity: { model.store.identity },
                                      quoteEnabled: true,
                                      creationPolicy: model.scenario == .disabled ? .disabled : .offlineFixture,
                                      waitlistService: model.scenario.isWaitlist ? model.store : nil,
                                      availablePoints: model.scenario == .pointsRefused ? { 300 } : nil)
                    .safeAreaInset(edge: .bottom) {
                        if model.scenario == .pointsRefused { RegistrationPointsPayClosedNote() }
                    }
                    .modifier(AccessibilityFixtureOptions())
            }
        }
        .environment(\.registrationHidesFixtureNotice, hidesFixtureNotice)
        // Design fixtures run offline: the 活动信息 cover uses a bundled MP cover, like the activity-detail hero fixture.
        .environment(\.e1ActivityHeroFixtureCover, MPAsset.BannerCover.feNight)
        // Same detent as the real presentation (`ActivityDetailView` → `SessionRegistrationSheet`, `.large`).
        .cySheet(detents: [.large]) }
    }
}

/// Pay stays on the closed side of the money switch. No executor, so the sheet cannot submit a charge.
private struct RegistrationPointsPayClosedNote: View {
    var body: some View {
        List {
            RegistrationPaySection(registrationID: 9401, payableAmount: 12.5, consented: false)
        }
        .frame(minHeight: 88)
    }
}

#Preview("Registration · offline") { RegistrationFixtureHostView() }
#Preview("Registration · unknown outcome") { RegistrationFixtureHostView(scenario: .createTimeout) }
#Preview("Registration · live create disabled") { RegistrationFixtureHostView(scenario: .disabled) }
#endif
