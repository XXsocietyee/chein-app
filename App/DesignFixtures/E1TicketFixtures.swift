#if DEBUG
import SwiftUI

/// Ticket holder lab (E1): the real wallet and detail views over four synthetic passes, one per ribbon state.
/// `--design-fixture e1-ticket-holder` (wallet stack), `e1-ticket-holder-valid | -pending | -used | -expired`
/// (detail pass), `e1-ticket-holder-present` (present mode without a code factory: the honest staff tile).
/// Add `--uitesting-reduce-motion` to see the fallbacks. Offline example data, labelled; never a production path.
@MainActor final class E1TicketHolderReader: TicketWalletReading {
    let scope = UUID()
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { true }
    private struct Envelope: Decodable { let data: [TicketWalletTicket] }
    private lazy var tickets: [TicketWalletTicket] = {
        (try? JSONDecoder().decode(Envelope.self, from: Data(Self.json.utf8)))?.data ?? []
    }()
    func ticket(id: Int) -> TicketWalletTicket? { tickets.first { $0.id == id } }
    func ticketWallet() async throws -> TicketWalletSnapshot { TicketWalletSnapshot(tickets: tickets) }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket {
        guard let ticket = ticket(id: id) else { throw TicketWalletReadFailure.unavailable }
        return ticket
    }
    static let validID = 1001, pendingID = 1002, usedID = 1003, expiredID = 1004
    static let json = #"""
    {"data":[
      {"id":1001,"ownerType":1,"ownerId":201,"registrationStatus":2,"verificationStatus":0,"registrationNo":"EXAMPLE-PASS-1001","participateDate":"2030-05-18",
       "cmsTopic":{"name":"Lantern Walk, Old Town (offline example)","productType":2,"addressName":"Drum Tower Square","startDate":"2030-05-18 19:00:00","endDate":"2030-05-18 22:00:00"}},
      {"id":1002,"ownerType":2,"ownerId":202,"registrationStatus":1,"verificationStatus":0,"participateDate":"2030-06-02",
       "cmsActivity":{"name":"Night Market Tasting (offline example)","productType":1,"addressName":"Riverside Night Market"}},
      {"id":1003,"ownerType":1,"ownerId":203,"registrationStatus":2,"verificationStatus":1,"registrationNo":"EXAMPLE-PASS-1003","participateDate":"2030-04-20","verificationTime":"2030-04-20 18:42:00",
       "cmsTopic":{"name":"Hidden Courtyards Route (offline example)","productType":2,"addressName":"South Gate"},
       "entitlements":[{"id":41,"status":1,"chapterId":11,"chapterName":"Courtyard one","redeemedAt":"2030-04-20 18:50:00"},{"id":42,"status":1,"chapterId":12,"chapterName":"Courtyard two","redeemedAt":"2030-04-20 19:30:00"}]},
      {"id":1004,"ownerType":2,"ownerId":204,"registrationStatus":4,"verificationStatus":0,"registrationNo":"EXAMPLE-PASS-1004","participateDate":"2029-12-31",
       "cmsActivity":{"name":"New Year Rooftop Count-in (offline example)","productType":1,"addressName":"Clock Tower Terrace"}}
    ]}
    """#
}

struct E1TicketHolderFixture: View {
    enum Kind { case wallet, valid, pending, used, expired, present }
    let kind: Kind
    @State private var reader = E1TicketHolderReader()

    var body: some View {
        Group {
            switch kind {
            case .wallet: TicketWalletView(reader: reader)
            case .valid: NavigationStack { TicketWalletDetailView(id: E1TicketHolderReader.validID, reader: reader) }
            case .pending: NavigationStack { TicketWalletDetailView(id: E1TicketHolderReader.pendingID, reader: reader) }
            case .used: NavigationStack { TicketWalletDetailView(id: E1TicketHolderReader.usedID, reader: reader) }
            case .expired: NavigationStack { TicketWalletDetailView(id: E1TicketHolderReader.expiredID, reader: reader) }
            case .present:
                if let ticket = reader.ticket(id: E1TicketHolderReader.validID) {
                    TicketPassPresentView(ticket: ticket) {}
                }
            }
        }
        .themeDomain(.player)
        .cyDomainPageBackground()
        .preferredColorScheme(.dark)
    }
}
#endif
