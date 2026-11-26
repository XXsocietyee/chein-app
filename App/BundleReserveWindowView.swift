import SwiftUI

/// Free-time picker constrained to a `BundleReserveWindow` (UX clipping only; the server validates).
/// Hands the chosen instant to `onChoose`; the host forwards it to the existing
/// `FreeExploreBundleLaunchModel.prepare(unitID:offerID:startAt:)`. Not mounted anywhere.
struct BundleReserveWindowView: View {
    let window: BundleReserveWindow
    let onChoose: (Int64) -> Void
    @State private var selection: Date?
    @State private var commitTick = 0
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
                Button {
                    commit(in: range)
                } label: {
                    Label { text("window.choose") } icon: { Image(systemName: "calendar.badge.checkmark") }
                }
                .accessibilityLabel(text("window.choose"))
                .cyHaptic(.impactMedium, trigger: commitTick)
            } header: {
                hero
            }
        } else {
            Section {
                ContentUnavailableView {
                    Label {
                        text("window.none").accessibilityIdentifier("bundleStall.noWindow")
                    } icon: {
                        Image(systemName: "calendar.badge.exclamationmark")
                    }
                }
            } header: {
                hero
            }
        }
    }

    /// Native r2: the window title is the section header, not an in-list hero title.
    private var hero: some View {
        text("window.header")
    }

    private func commit(in range: ClosedRange<Date>) {
        let chosen = selection ?? range.lowerBound
        let millis = chosen.timeIntervalSince1970 * 1_000
        guard millis.isFinite, millis > 0, millis < Double(Int64.max) else { return }
        let ms = Int64(millis)
        guard window.contains(ms) else { return }
        onChoose(ms)
        commitTick += 1
    }
}

#if DEBUG
#Preview("Window · player dark") {
    NavigationStack {
        Form {
            BundleReserveWindowView(window: BundleReserveWindow.make(validFromMs: nil, validToMs: nil, serverNowMs: 1_700_000_000_000, deviceNowMs: 1_700_000_000_000), onChoose: { _ in })
        }
    }
    .themeDomain(.player)
}
#Preview("Window · none") {
    NavigationStack {
        Form {
            BundleReserveWindowView(window: BundleReserveWindow.make(validFromMs: 100, validToMs: 1, serverNowMs: 50, deviceNowMs: 50), onChoose: { _ in })
        }
    }
    .themeDomain(.player)
}
#Preview("Window · merchant light") {
    NavigationStack {
        Form {
            BundleReserveWindowView(window: BundleReserveWindow.make(validFromMs: nil, validToMs: nil, serverNowMs: 1_700_000_000_000, deviceNowMs: 1_700_000_000_000), onChoose: { _ in })
        }
    }
    .themeDomain(.merchant)
}
#endif
