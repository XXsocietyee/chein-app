#if DEBUG
import SwiftUI
import QuestifyCore

/// Synthetic bundle shelf / detail (DEBUG only). Labelled offline example data; never a production path.
@MainActor private final class E1ShelfClient: BundleShelfClient {
    let json: String?
    init(json: String?) { self.json = json }
    func page(cursor: String?, limit: Int) async throws -> BundleShelfPage {
        guard let json else { throw BundleShelfFailure.failed }
        return try JSONDecoder().decode(BundleShelfPage.self, from: Data(json.utf8))
    }
}

struct E1BundleFixture: View {
    enum Kind { case shelf, shelfEmpty, shelfError, detail, detailOff }
    let kind: Kind
    @State private var model: BundleShelfModel
    init(_ kind: Kind) {
        self.kind = kind
        let rows = (1...3).map { #"{"topicId":"\#($0)","topicName":"Example bundle \#($0) (offline example)","fromPrice":"\#(99 * $0).00","validityDays":30}"# }.joined(separator: ",")
        let json: String?
        switch kind {
        case .shelf: json = #"{"items":[\#(rows)],"saleEnabled":true}"#
        case .shelfEmpty: json = #"{"items":[],"saleEnabled":true}"#
        default: json = nil
        }
        _model = State(initialValue: BundleShelfModel(client: E1ShelfClient(json: json)))
    }
    var body: some View {
        NavigationStack {
            switch kind {
            case .detail, .detailOff:
                if let content = try? BundleDetailContent.decode(Data(#"{"topicId":"1","productType":2,"saleEnabled":\#(kind == .detail),"reservationEnabled":false,"items":[],"price":"199.00","validityDays":30,"compliance":{"declarations":["Offline example compliance line."]}}"#.utf8)) {
                    BundleDetailView(content: content, onPurchase: {})
                }
            default:
                BundleShelfView(model: model, onSelect: { _ in })
            }
        }
        .themeDomain(.player).cyDomainPageBackground().themeDomain(.player)
    }
}
#endif
