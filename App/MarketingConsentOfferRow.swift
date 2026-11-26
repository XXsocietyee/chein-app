import SwiftUI

/// R7-PC-B1-12 / R11-PC-C-3: optional "接收{商家}站内活动消息" opt-in after a paid order or a registration
/// (MP utils/marketing-consent-entry.js:52-100; pages/topic/index/index.js:2083-2139; pages/activity/baoming/baoming.js:1300-1368).
/// The GET is silent: no offer, a failure or an ambiguous owner hides the row. The POST is sent once per opt-in intent and
/// reuses its request id on retry. Off by default; turning it off after saving does nothing (MP has no opt-out here).
@MainActor struct MarketingConsentOfferRow: View {
    let ownerMemberID: Int?
    let makeService: @MainActor () -> PlayerContentRound4Service?
    private enum Save: Equatable { case idle, saving, saved, failed(String) }
    @State private var offer: MarketingConsentOffer?
    @State private var optedIn = false
    @State private var save = Save.idle
    @State private var requestID: String?
    @Environment(\.locale) private var locale

    var body: some View {
        Group {
            if let offer {
                Toggle(isOn: Binding(get: { optedIn }, set: { value in
                    guard value, save != .saving, save != .saved else { return }
                    optedIn = true
                    submit(offer)
                })) {
                    Text(verbatim: appLocalized("marketingConsent.offer \(offer.merchantName)", locale: locale))
                }
                .disabled(save == .saving || save == .saved)
                .accessibilityIdentifier("marketingConsent.toggle")
                switch save {
                case .saving:
                    ProgressView().accessibilityIdentifier("marketingConsent.saving")
                case .saved:
                    Label("marketingConsent.saved", systemImage: "checkmark.circle")
                        .font(.footnote).foregroundStyle(.secondary)
                case .failed(let message):
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: message).font(.footnote).foregroundStyle(.red)
                        Button("marketingConsent.retry") { submit(offer) }
                            .accessibilityIdentifier("marketingConsent.retry")
                    }
                case .idle:
                    EmptyView()
                }
            }
        }
        .task(id: ownerMemberID) {
            guard offer == nil, let service = makeService() else { return }
            let picked = await service.loadMarketingConsentOffer(ownerMemberID: ownerMemberID)
            guard !Task.isCancelled else { return }
            offer = picked
        }
    }

    private func submit(_ offer: MarketingConsentOffer) {
        guard let service = makeService() else {
            save = .failed(appLocalized("marketingConsent.failed", locale: locale)); return
        }
        let id = requestID ?? MarketingConsentOffer.newRequestID()
        requestID = id
        save = .saving
        Task {
            let reply = await service.submitMarketingConsent(merchantRowID: offer.merchantRowID,
                                                             merchantOwnerMemberID: offer.merchantOwnerMemberID,
                                                             optedIn: true, requestID: id)
            switch reply {
            case .ok:
                save = .saved
            case .refused(_, let message):
                save = .failed(message.flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("marketingConsent.failed", locale: locale))
            case .unauthorized, .unknown:
                save = .failed(appLocalized("marketingConsent.networkFailed", locale: locale))
            }
        }
    }
}

extension AppSession {
    /// R7-PC-B1-12 / R11-PC-C-3 / R11-PC-B-3: signed-in marketing-consent reads, the opt-in write and the self-supply write.
    func makePlayerContentRound4Service() -> PlayerContentRound4Service? {
        guard (account?.id ?? 0) > 0, let token, let api = regionalConfiguration?.apiConfiguration else { return nil }
        return PlayerContentRound4Service(baseURL: api.baseURL, token: { token }, transport: runtimeHTTPTransport)
    }
}

private struct MarketingConsentServiceKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> PlayerContentRound4Service?)? = nil
}
extension EnvironmentValues {
    /// R11-PC-C-3: the registration sheet's marketing-consent service. Nil hides the opt-in row.
    var marketingConsentService: (@MainActor () -> PlayerContentRound4Service?)? {
        get { self[MarketingConsentServiceKey.self] }
        set { self[MarketingConsentServiceKey.self] = newValue }
    }
}
