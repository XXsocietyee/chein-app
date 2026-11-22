import SwiftUI

@MainActor struct RoamVoucherEntryView: View {
    @State private var poiID = ""
    @Environment(\.verificationCodeFactory) private var codeFactory
    private var target: VerificationCodeTarget? {
        guard let id = Int(poiID), id > 0 else { return nil }
        return .init(kind: .cityVoucher, id: id)
    }
    var body: some View {
        List {
            Section {
                TextField("roam.experience.poiID", text: $poiID).keyboardType(.numberPad)
                    .accessibilityIdentifier("roam.experience.voucher.poiID")
                if let target {
                    if let codeFactory {
                        NavigationLink("verificationCode.city.open") { VerificationCodeView(model: codeFactory(target)) }
                            .accessibilityIdentifier("verificationCode.city.open")
                    } else { CYEmptyState(systemImage: "lock", "verificationCode.phase.disabled") }
                } else {
                    Label("roam.experience.voucherMissing", systemImage: "questionmark.circle")
                    Text("roam.experience.voucherMissingHint").cyText(.meta)
                }
                Text("verificationCode.city.authority").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }.cyGroupedSurface().cyPageTitle("roam.experience.voucher")
            .accessibilityIdentifier("roam.experience.voucher")
        .cyDomainScreen(.player)
    }
}
struct RoamHangoutUnavailableView: View {
    var body: some View {
        CYEmptyState(systemImage: "person.3", "roam.experience.hangoutUnavailable", detail: "roam.experience.hangoutHint")
            .cyPageTitle("roam.experience.hangout")
            .accessibilityIdentifier("roam.experience.hangout.unavailable")
        .cyDomainScreen(.player)
    }
}
