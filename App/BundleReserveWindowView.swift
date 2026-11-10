import SwiftUI

/// Free-time picker constrained to a `BundleReserveWindow` (UX clipping only; the server validates).
/// Hands the chosen instant to `onChoose`; the host forwards it to the existing
/// `FreeExploreBundleLaunchModel.prepare(unitID:offerID:startAt:)`. Not mounted anywhere.
struct BundleReserveWindowView: View {
    let window: BundleReserveWindow
    let onChoose: (Int64) -> Void
    @State private var selection: Date?
    private let table = "BundleStall"
    private func text(_ key: String) -> Text { Text(LocalizedStringKey(key), tableName: table) }
    private func date(_ ms: Int64) -> Date { Date(timeIntervalSince1970: Double(ms) / 1_000) }

    var body: some View {
        if let first = window.earliestMs, let last = window.latestMs {
            let range = date(first)...date(last)
            Section {
                DatePicker(selection: Binding(get: { selection ?? range.lowerBound },
                                              set: { selection = $0 }),
                           in: range) { text("window.pick") }
                CYPillButton("window.choose", style: .primary, tableName: table) {
                    let chosen = selection ?? range.lowerBound
                    let millis = chosen.timeIntervalSince1970 * 1_000
                    guard millis.isFinite, millis > 0, millis < Double(Int64.max) else { return }
                    let ms = Int64(millis)
                    guard window.contains(ms) else { return }
                    onChoose(ms)
                }
            } header: { text("window.header") }
        } else {
            text("window.none").accessibilityIdentifier("bundleStall.noWindow")
        }
    }
}
