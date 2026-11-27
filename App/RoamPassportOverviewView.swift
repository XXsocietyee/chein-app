import SwiftUI

/// Same-page P005 passport header. Existing Hub links below remain the only history/album routes.
@MainActor struct RoamPassportOverviewView: View {
    let phase: RoamPassportOverviewState.Phase
    let retry: () -> Void
    /// BL-41 official-events card destination (single event detail, or the official task list).
    var officialEventDestination: ((Int?) -> AnyView)? = nil
    @Environment(\.roamPassportHistoryReader) private var serverReader
    var body: some View {
        // pages/roam _loadIntroPassport: server completed facts are the passport stats when the owner read exists.
        if let serverReader, serverReader.isConfigured {
            RoamPassportServerSummarySection(reader: serverReader)
            Section { OfficialRoamActiveCardView(destination: officialEventDestination) }
        } else {
            localOverview
        }
    }
    @ViewBuilder private func secondaryStats(_ summary: RoamPassportSummary) -> some View {
        stat("roam.passport.shopVisits") {
            if let shops = summary.knownShopVisits { Text(shops, format: .number) }
            else { Text("roam.passport.unknown").accessibilityLabel(Text("roam.passport.unknown.a11y")) }
        }.accessibilityIdentifier("roam.passport.shops")
        stat("roam.passport.activeDays") {
            if let days = summary.activeDays { Text(days, format: .number) }
            else { Text("roam.passport.unknown").accessibilityLabel(Text("roam.passport.unknown.a11y")) }
        }.accessibilityIdentifier("roam.passport.days")
        stat("roam.experience.knownDistance") {
            if let distance = summary.knownKilometers {
                Text(distance, format: .number.precision(.fractionLength(1))) + Text(verbatim: " km")
            } else { Text("roam.passport.unknown").accessibilityLabel(Text("roam.passport.unknown.a11y")) }
        }.accessibilityIdentifier("roam.passport.distance")
    }
    private func stat<Value: View>(_ label: LocalizedStringKey, @ViewBuilder value: () -> Value) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).cyText(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            value().cyText(.numericBody, monospacedDigit: true)
        }
        .accessibilityElement(children: .combine)
    }
    private var localOverview: some View {
        Section("roam.passport.title") {
            switch phase {
            case .unloaded:
                CYSkeleton().accessibilityLabel(Text("roam.loading")).accessibilityIdentifier("roam.passport.loading")
            case .failed(let error):
                RoamExperienceIssue(error: error, retry: retry)
                    .accessibilityIdentifier("roam.passport.error")
            case .loaded(let summary):
                // Design pass roam (P1 one glance, one number): walks taken is the hero; shops, days and
                // distance sit in a quiet row under it (stacked when English runs long, P12).
                VStack(alignment: .leading, spacing: 2) {
                    Text("roam.experience.trips").cyText(.caption).foregroundStyle(.secondary)
                    CYLiveCounter(summary.trips, label: "roam.experience.trips", style: .data2XL)
                }
                .padding(.vertical, 4)
                .accessibilityIdentifier("roam.passport.trips")
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) { secondaryStats(summary) }
                    VStack(alignment: .leading, spacing: 10) { secondaryStats(summary) }
                }
                OfficialRoamActiveCardView(destination: officialEventDestination)
                if summary.trips == 0 {
                    CYEmptyState(systemImage: "figure.walk", "roam.experience.historyEmpty")
                        .accessibilityIdentifier("roam.passport.empty")
                } else if summary.hasPartialMetrics {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("roam.passport.partial")
                        LabeledContent("roam.passport.distanceCoverage", value: "\(summary.tripsWithDistance)/\(summary.trips)")
                        LabeledContent("roam.passport.shopsCoverage", value: "\(summary.tripsWithShops)/\(summary.trips)")
                        LabeledContent("roam.passport.dateCoverage", value: "\(summary.tripsWithDate)/\(summary.trips)")
                    }.cyText(.meta).foregroundStyle(.secondary)
                        .accessibilityIdentifier("roam.passport.partial")
                }
                Text("roam.passport.localOnly").cyText(.meta).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("roam.passport.counting").cyText(.meta).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.accessibilityIdentifier("roam.passport.overview")
    }
}
