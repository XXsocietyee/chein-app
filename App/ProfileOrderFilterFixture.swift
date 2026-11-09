#if DEBUG
import SwiftUI

/// Memory-only rows exercise the actual list and detail. No transport, token or live grant.
@MainActor final class ProfileOrderFilterFixtureReader: ObservableObject, ProfileReading {
    @Published var isConfigured = true
    @Published var identity: ProfileReadIdentity? = .init(accountID: 7001, epoch: 1)
    @Published private(set) var listReads = 0
    @Published private(set) var detailReads = 0
    let rows: [ProfileOrder]
    init(empty: Bool = false, rich: Bool = false) {
        rows = empty ? [] : (try! JSONDecoder().decode([ProfileOrder].self, from: Data((rich ? Self.richJson : Self.json).utf8)))
    }
    func profileOrders() async throws -> [ProfileOrder] {
        guard isConfigured else { throw APIError.notConfigured }; guard identity != nil else { throw APIError.unauthorized }
        listReads += 1; return rows.filter { $0.memberID == identity?.accountID }
    }
    func profileOrder(id: Int) async throws -> ProfileOrder {
        guard isConfigured else { throw APIError.notConfigured }; guard identity != nil else { throw APIError.unauthorized }
        guard let row = rows.first(where: { $0.id == id && $0.memberID == identity?.accountID }) else { throw APIError.invalidRequest }
        detailReads += 1; return row
    }
    func profileParticipants() async throws -> [ProfileParticipant] { throw APIError.notConfigured }
    func profileParticipant(id: Int) async throws -> ProfileParticipant { throw APIError.notConfigured }
    func profileBadges() async throws -> ProfileBadgeWall { throw APIError.notConfigured }
    /// Design fixtures only: the same rows with a synthetic number, amount and address so the card shows its full anatomy.
    static var richJson: String {
        var out = json
        for i in 701...707 { out = out.replacingOccurrences(of: "{\"id\":\(i),\"memberId\":7001,", with: "{\"id\":\(i),\"memberId\":7001,\"registrationNo\":\"A2026092\(i)FAD04987\",\"payableAmount\":\(i - 700).5,") }
        // Every row gets the same time range and address so each card shows its full anatomy.
        out = out.replacingOccurrences(of: ",\"startDate\":\"2099-01-01\",\"endDate\":\"2099-01-02\"", with: "")
        return out.replacingOccurrences(of: "\"cmsTopic\":{\"name\"", with: "\"cmsTopic\":{\"addressName\":\"Synthetic address 100\",\"startDate\":\"2099-01-01\",\"endDate\":\"2099-01-02\",\"name\"")
    }
    static let json = #"[{"id":701,"memberId":7001,"registrationStatus":1,"cmsTopic":{"name":"Synthetic pending"}},{"id":702,"memberId":7001,"registrationStatus":2,"paymentStatus":2,"cmsTopic":{"name":"Synthetic upcoming","startDate":"2099-01-01","endDate":"2099-01-02"}},{"id":703,"memberId":7001,"registrationStatus":2,"verificationStatus":1,"cmsTopic":{"name":"Synthetic completed"}},{"id":704,"memberId":7001,"registrationStatus":3,"refundApplication":{"payoutStatus":0,"status":1,"refundAmount":2},"cmsTopic":{"name":"Synthetic refunding"}},{"id":705,"memberId":7001,"registrationStatus":3,"refundApplication":{"payoutStatus":4,"refundAmount":2},"cmsTopic":{"name":"Synthetic refunded"}},{"id":706,"memberId":7001,"registrationStatus":3,"cmsTopic":{"name":"Synthetic cancelled"}},{"id":707,"memberId":7001,"registrationStatus":99,"cmsTopic":{"name":"Synthetic unknown"}}]"#
}

@MainActor struct ProfileOrderFilterFixtureHost: View {
    @StateObject private var reader: ProfileOrderFilterFixtureReader
    var designClean = false
    init(empty: Bool = false, designClean: Bool = false) { self.designClean = designClean; _reader = StateObject(wrappedValue: ProfileOrderFilterFixtureReader(empty: empty, rich: designClean)) }
    var body: some View {
        NavigationStack { ProfileOrdersView(reader: reader).id(reader.identity) }
            .safeAreaInset(edge: .top, spacing: 0) {
                if designClean { Text(verbatim: "Synthetic fixture · debug only").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 2) }
            }
            .safeAreaInset(edge: .bottom) {
                if !designClean { VStack {
                    Text(verbatim: "Synthetic local filters; production order reads remain blocked.")
                    HStack {
                        Text(verbatim: String(reader.listReads)).accessibilityIdentifier("profile.orderFilter.fixture.listReads")
                        Text(verbatim: String(reader.detailReads)).accessibilityIdentifier("profile.orderFilter.fixture.detailReads")
                        Button("Revoke") { reader.isConfigured = false }.accessibilityIdentifier("profile.orderFilter.fixture.revoke")
                            .accessibilityValue(reader.isConfigured ? "configured" : "revoked")
                        Button("Switch account") { reader.identity = .init(accountID: 7002, epoch: 2) }.accessibilityIdentifier("profile.orderFilter.fixture.switch")
                    }
                }.font(.caption) }
            }
    }
}
#endif
