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

/// Reader for the pass-card lab: an empty wallet or a failing read (offline example, no data invented).
@MainActor final class E1PassCardStateReader: TicketWalletReading {
    enum Mode { case empty, failing }
    let mode: Mode
    let scope = UUID()
    init(_ mode: Mode) { self.mode = mode }
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { true }
    func ticketWallet() async throws -> TicketWalletSnapshot {
        if mode == .failing { throw TicketWalletReadFailure.unavailable }
        return TicketWalletSnapshot(tickets: [])
    }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket { throw TicketWalletReadFailure.unavailable }
}

/// Pass-card sheet lab (W1-5): `--design-fixture ui-pass-card-sheet | -pending | -used | -expired | -empty | -error`.
/// The valid one has no code factory, so it shows the honest staff tile at the same 240 pt white size.
struct PassCardFixture: View {
    enum Kind { case valid, pending, used, expired, empty, error }
    let kind: Kind
    @State private var holder = E1TicketHolderReader()
    @State private var empty = E1PassCardStateReader(.empty)
    @State private var failing = E1PassCardStateReader(.failing)
    private var reader: any TicketWalletReading {
        switch kind {
        case .empty: return empty
        case .error: return failing
        default: return holder
        }
    }
    var body: some View {
        // The holder lists four passes; the card leads with the first usable one, so the other states are chosen
        // by a reader that exposes only that ticket.
        TicketPassSheet(reader: kind == .valid || kind == .empty || kind == .error ? reader : SingleTicketReader(base: holder, id: id), onClose: {}, onOpenWallet: {})
            .themeDomain(.player)
            .preferredColorScheme(.dark)
    }
    private var id: Int {
        switch kind {
        case .pending: return E1TicketHolderReader.pendingID
        case .used: return E1TicketHolderReader.usedID
        default: return E1TicketHolderReader.expiredID
        }
    }
}

@MainActor private final class SingleTicketReader: TicketWalletReading {
    let base: E1TicketHolderReader
    let id: Int
    let scope = UUID()
    init(base: E1TicketHolderReader, id: Int) { self.base = base; self.id = id }
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { true }
    func ticketWallet() async throws -> TicketWalletSnapshot {
        TicketWalletSnapshot(tickets: base.ticket(id: id).map { [$0] } ?? [])
    }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket { try await base.ticketDetail(id: id) }
}

/// One ticket whose status is chosen at init: ready (verificationStatus 0) or verified (1). Two instances with
/// different scopes make the sheet reload, which is how `ui-pass-card-verify` flips the status.
@MainActor final class E1PassCardVerifyReader: TicketWalletReading {
    let scope = UUID()
    let verified: Bool
    init(verified: Bool) { self.verified = verified }
    var isConfigured: Bool { true }
    var isAuthenticated: Bool { true }
    var isOfflineExample: Bool { true }
    private struct Envelope: Decodable { let data: [TicketWalletTicket] }
    private var tickets: [TicketWalletTicket] {
        let time = verified ? #","verificationTime":"2030-05-18 19:04:00""# : ""
        let json = #"{"data":[{"id":1001,"ownerType":1,"ownerId":201,"registrationStatus":2,"verificationStatus":\#(verified ? 1 : 0),"registrationNo":"EXAMPLE-PASS-1001","participateDate":"2030-05-18"\#(time),"cmsTopic":{"name":"Lantern Walk, Old Town (offline example)","productType":2,"addressName":"Drum Tower Square","startDate":"2030-05-18 19:00:00","endDate":"2030-05-18 22:00:00"}}]}"#
        return (try? JSONDecoder().decode(Envelope.self, from: Data(json.utf8)))?.data ?? []
    }
    func ticketWallet() async throws -> TicketWalletSnapshot { TicketWalletSnapshot(tickets: tickets) }
    func ticketDetail(id: Int) async throws -> TicketWalletTicket {
        guard let t = tickets.first(where: { $0.id == id }) else { throw TicketWalletReadFailure.unavailable }
        return t
    }
}

/// `--design-fixture ui-pass-card-verify`: the real pass sheet on a ready ticket; 1.5 s after it appears the reader
/// answers "verified". Expected beats (ms after the flip): 0 tile dims + edge glow sweeps the display corners (450),
/// 300 pass flips to the green "You're in" face, 800 perforation tears and the stub slides, 1700 the stub drops toward
/// the tab bar. With `--uitesting-reduce-motion`: glow fades, faces crossfade, no flip, no tear.
struct PassCardVerifyFixture: View {
    @State private var ready = E1PassCardVerifyReader(verified: false)
    @State private var done = E1PassCardVerifyReader(verified: true)
    @State private var flipped = false
    var body: some View {
        TicketPassSheet(reader: flipped ? done : ready, onClose: {}, onOpenWallet: {})
            .themeDomain(.player)
            .preferredColorScheme(.dark)
            .task {
                try? await Task.sleep(for: .milliseconds(1500))
                flipped = true
            }
    }
}

/// `--design-fixture ui-pass-card`: the wallet card on an ink page. It opens by itself at 0.9 s (the pass grows out of
/// the card), rests 2.4 s, then returns along the same path as a drag-down would; tap the card to open it again, drag
/// the pass down past 120 pt (or tap the backdrop) to send it back.
struct PassCardHostFixture: View {
    @State private var holder = E1TicketHolderReader()
    @State private var presented = false
    @Environment(\.locale) private var locale
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }
    var body: some View {
        ZStack {
            CYNight.ink0.ignoresSafeArea()
            if let ticket = holder.ticket(id: E1TicketHolderReader.validID) {
                CYPassFromCard(isPresented: $presented) {
                    E1TicketCard(ticket: ticket, interactive: false)
                } pass: {
                    TicketPassCard(ticket: ticket)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, CYSpacing.xxl)
            }
        }
        .themeDomain(.player)
        .preferredColorScheme(.dark)
        .task {
            try? await Task.sleep(for: .milliseconds(900))
            presented = true
            try? await Task.sleep(for: .milliseconds(3300))
            presented = false
        }
    }
}

struct E1TicketHolderFixture: View {
    enum Kind { case wallet, valid, pending, used, expired, present }
    let kind: Kind
    @StateObject private var session = AppSession()
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
        .environmentObject(session)
    }
}
#endif
