import SwiftUI

/// T-10. Rows in the server's order (the server returns them by start time); the client does not re-sort and does
/// not interpret `startAt` against the device clock. Display only: no cancel or reserve control lives here
/// (cancel is IWP-1, reserve is the existing launch flow).
@MainActor struct BundleReservationsView: View {
    let order: BundleOrderReadModel
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var artHeight: CGFloat = 112
    private let table = BundleOrderStatusPresentation.table
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader(verbatim: ChannelCopy.text("预约", "Reservations", locale: locale)) {
                    CYCoverArt(seed: "bundle-reservations", symbol: "calendar", showsDebugLabel: false)
                        .frame(maxWidth: .infinity)
                        .frame(height: artHeight)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityHidden(true)
                }
                if order.isLegacy {
                    CYEmptyState(systemImage: "doc.text", "order.legacy", tableName: table)
                } else if order.reservations.isEmpty {
                    CYEmptyState(systemImage: "calendar", "reservations.empty", tableName: table, messageIdentifier: "bundle.reservations.empty")
                } else {
                    VStack(spacing: CYSpacing.md) {
                        ForEach(order.reservations, id: \.id) { row in reservationCard(row) }
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.xxl)
        }
        .cyDomainPageBackground()
        .themeDomain(.player)
        .cyHeroScreen()
        .cyAnimation(value: order.reservations.map(\.id))
    }

    private func reservationCard(_ row: BundleReservationRow) -> some View {
        let tone = statusTone(row.status)
        return VStack(alignment: .leading, spacing: CYSpacing.sm) {
            CYListRow(verbatim: statusLine(row), meta: shown(row.startAt), trailing: .none) {
                CYCoverArt(seed: row.id.text, symbol: tone.symbol, showsDebugLabel: false, cornerRadius: CYRadius.sm)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            Text(verbatim: shown(row.id.text))
                .cyText(.caption)
                .monospacedDigit()
                .foregroundStyle(palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(Text(verbatim: shown(row.id.text)))
        }
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }

    /// Known statuses use catalog copy. A blank status is unknown (em dash). Any other server string stays verbatim, including a real "0".
    private func statusLine(_ row: BundleReservationRow) -> String {
        let raw = row.status.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "—" }
        guard let key = BundleOrderStatusPresentation.reservationStatusKey(row) else { return raw }
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key), table: table)
        if resolved.isEmpty || resolved == key { return raw }
        return resolved
    }

    private func shown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func statusTone(_ status: String) -> (tone: CYStatusTone, symbol: String) {
        switch status {
        case "FULFILLED": return (.success, "checkmark.circle.fill")
        case "BOOKED": return (.info, "clock.fill")
        case "WAIVED": return (.warning, "hand.raised.fill")
        case "CANCELLED", "LATE_CANCELLED", "NO_SHOW", "MERCHANT_EXITED": return (.danger, "xmark.circle.fill")
        default: return (.neutral, "questionmark.circle")
        }
    }
}

#if DEBUG
#Preview("Reservations · player dark") {
    NavigationStack { BundleReservationsView(order: BundleReservationsPreviewData.legacy) }
        .themeDomain(.player)
}
#Preview("Reservations · rows") {
    NavigationStack { BundleReservationsView(order: BundleReservationsPreviewData.rows) }
        .themeDomain(.player)
}
#Preview("Reservations · merchant light") {
    NavigationStack { BundleReservationsView(order: BundleReservationsPreviewData.legacy) }
        .themeDomain(.merchant)
}

private enum BundleReservationsPreviewData {
    static var legacy: BundleOrderReadModel {
        let order = try! JSONDecoder().decode(FreeExploreLaunchOrder.self, from: Data(#"{"registrationId":"1"}"#.utf8))
        return BundleOrderReadModel(order: order)
    }
    static var rows: BundleOrderReadModel {
        let json = #"""
        {"registrationId":"1","paymentStatus":2,"registrationStatus":2,"bundle":{"order":{"registrationId":"1","holderMemberId":"2","topicId":"3"},"units":[{"id":"4","registrationId":"1","holderMemberId":"2","chapterId":"5","status":"RESERVED"}],"reservations":[{"id":"6","registrationId":"1","holderMemberId":"2","unitId":"4","chapterId":"5","offerId":"7","merchantId":"8","startAt":"2027-01-01 12:00:00","status":"BOOKED","idempotencyKey":"k","requestFingerprint":"f"},{"id":"9","registrationId":"1","holderMemberId":"2","unitId":"4","chapterId":"5","offerId":"7","merchantId":"8","startAt":"","status":"","idempotencyKey":"k2","requestFingerprint":"f2"}]}}
        """#
        let order = try! JSONDecoder().decode(FreeExploreLaunchOrder.self, from: Data(json.utf8))
        return BundleOrderReadModel(order: order)
    }
}
#endif
