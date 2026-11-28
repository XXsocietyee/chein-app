import EventKit
import EventKitUI
import SwiftUI

/// mp-home r3 (P28): the activity time line carries an Add to Calendar action.
/// The system event editor needs no calendar permission on iOS 17+ (it runs out of process), and nothing is saved
/// unless the player taps Add in Apple's own sheet. Offered only for an upcoming activity with a readable start.
struct ActivityCalendarDraft: Equatable {
    let title: String
    let start: Date
    let end: Date
    let location: String?

    static func make(summary: ActivitySummary, now: Date = Date()) -> ActivityCalendarDraft? {
        guard E1ActivityState.of(start: summary.startDate, end: summary.endDate, now: now) == .upcoming else { return nil }
        guard let title = ActivityPresentation.nonempty(summary.name) else { return nil }
        let utc = TimeZone(secondsFromGMT: 0)!
        func parse(_ raw: String?) -> Date? {
            guard let raw, !raw.isEmpty else { return nil }
            return HomeFeedDate.parse(raw, sourceTimeZone: nil) ?? HomeFeedDate.parse(raw, sourceTimeZone: utc)
        }
        guard let start = parse(summary.startDate) else { return nil }
        let end: Date
        if let parsedEnd = parse(summary.endDate), parsedEnd > start {
            end = parsedEnd
        } else {
            end = start.addingTimeInterval(3600)
        }
        let location = ActivityPresentation.nonempty(summary.addressName) ?? ActivityPresentation.nonempty(summary.address)
        return ActivityCalendarDraft(title: title, start: start, end: end, location: location)
    }
}

/// Small bordered button under the hero date line; opens the system event editor as a sheet.
struct ActivityAddToCalendarButton: View {
    let draft: ActivityCalendarDraft
    @State private var showsEditor = false

    var body: some View {
        Button {
            showsEditor = true
        } label: {
            Label("activity.calendar.add", systemImage: "calendar.badge.plus")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityHint(Text("activity.calendar.add.hint"))
        .accessibilityIdentifier("activity.detail.addToCalendar")
        .sheet(isPresented: $showsEditor) {
            ActivityCalendarEditor(draft: draft) { showsEditor = false }
                .ignoresSafeArea()
        }
    }
}

@MainActor struct ActivityCalendarEditor: UIViewControllerRepresentable {
    let draft: ActivityCalendarDraft
    let onDone: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDone: onDone) }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let store = EKEventStore()
        let event = EKEvent(eventStore: store)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.location = draft.location
        let controller = EKEventEditViewController()
        controller.eventStore = store
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: EKEventEditViewController, context: Context) {}

    @MainActor final class Coordinator: NSObject, EKEventEditViewDelegate {
        let onDone: () -> Void
        init(onDone: @escaping () -> Void) { self.onDone = onDone }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onDone()
        }
    }
}
