import SwiftUI
import MapKit

/// The one prominent action of the event detail (S2). Built by `ActivityDetailContentView` from the
/// same rules as its footer pill, so the paid-registration gate, the guest sign-in, the wallet and the
/// host cancel stay exactly where they were.
struct CityOrientationEventCTA {
    let titleKey: String
    let identifier: String
    let enabled: Bool
    var destructive = false
    let action: () -> Void
}

/// S2 event detail for a playable (topic-linked) activity: Maps place card layout in an inset grouped
/// `List` with `LabeledContent` facts and the CTA in the bottom toolbar. Read-only; every action is a
/// closure supplied by the existing detail screen.
@MainActor struct CityOrientationEventDetailList<More: View>: View {
    let detail: ActivityDetail
    let priceLine: Text?
    /// Nil when this entry point does not offer registration (same `registrationEnabled` gate as before).
    let cta: CityOrientationEventCTA?
    var onDirections: (() -> Void)? = nil
    var onReview: (() -> Void)? = nil
    var topicDestination: AnyView? = nil
    var channel: AnyView? = nil
    @ViewBuilder var more: () -> More

    private var facts: ActivityDetailHeaderFacts { ActivityDetailHeaderFacts(detail: detail) }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: detail.summary.name).font(.title2.bold())
                    if let category = facts.categoryText {
                        Text(verbatim: category).foregroundStyle(.secondary)
                            .accessibilityIdentifier("activity.detail.category")
                    }
                }
                .padding(.vertical, 4)
            }
            if detail.isCancelled {
                Section {
                    Label("activity.cancelled.title", systemImage: "xmark.octagon").foregroundStyle(.red)
                    if let reason = detail.cancelReason { Text("activity.cancelled.reason \(reason)") }
                } footer: {
                    Text("activity.cancelled.hint")
                }
                .accessibilityIdentifier("activity.detail.cancelled")
            }
            Section("nativeR2.city.event.info") {
                if let time = timeText {
                    LabeledContent("nativeR2.city.event.time") { Text(verbatim: time) }
                }
                LabeledContent("nativeR2.city.event.meetingPoint") { meetingPointText }
                    .accessibilityIdentifier("activity.detail.meetingPoint")
                LabeledContent("nativeR2.city.event.registered") {
                    Text(verbatim: facts.registrationCount.map(String.init) ?? "—").monospacedDigit()
                }
                .accessibilityIdentifier("activity.detail.registeredCount")
                if let priceLine {
                    LabeledContent("nativeR2.city.event.price") { priceLine }
                        .accessibilityIdentifier("activity.pinned.summary")
                }
            }
            if detail.summary.hasValidCoordinates, let latitude = detail.summary.latitude, let longitude = detail.summary.longitude {
                Section("activity.location") {
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    // Static map: an interactive map inside a List traps VoiceOver focus.
                    Map(initialPosition: .region(CYMapRegion.region(center: coordinate, span: 0.01)), interactionModes: []) {
                        Marker(detail.summary.name, coordinate: coordinate)
                    }
                    .frame(height: 180)
                    .listRowInsets(EdgeInsets())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("activity.location"))
                    .accessibilityAddTraits(.isImage)
                    if let onDirections {
                        Button(action: onDirections) { Label("nativeR2.city.event.directions", systemImage: "arrow.triangle.turn.up.right.diamond") }
                            .accessibilityIdentifier("nativeR2.city.event.directions")
                    }
                }
            }
            if let topicDestination {
                Section {
                    NavigationLink { topicDestination } label: { Label("activity.viewTopic", systemImage: "map") }
                        .accessibilityIdentifier("activity.openTopic")
                }
            }
            if let about = detail.summary.description?.trimmingCharacters(in: .whitespacesAndNewlines), !about.isEmpty {
                Section("activity.about") {
                    Text(verbatim: about).textSelection(.enabled)
                }
            }
            Section("nativeR2.city.event.tickets") {
                if detail.tickets.isEmpty {
                    Text("activity.source.noTickets").foregroundStyle(.secondary)
                }
                ForEach(detail.tickets) { ticket in
                    LabeledContent {
                        Text(verbatim: ticket.price.map { MoneyDisplay.yuan($0) } ?? "—").monospacedDigit()
                    } label: {
                        Text(verbatim: ticket.name)
                        if let left = ticket.remainingInventory { Text("nativeR2.city.event.remaining \(left)") }
                    }
                }
            }
            if let channel { Section { channel } }
            Section {
                if let onReview {
                    Button(action: onReview) { Label("context.review.title", systemImage: "square.and.pencil") }
                        .accessibilityIdentifier("activity.openReview")
                }
                Label("activity.reviewPointsNote", systemImage: "star")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("activity.detail.readOnly")
            }
            more()
        }
        .listStyle(.insetGrouped)
        .toolbar {
            if let cta {
                ToolbarItem(placement: .bottomBar) {
                    Button(role: cta.destructive ? .destructive : nil, action: cta.action) {
                        Text(LocalizedStringKey(cta.titleKey)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!cta.enabled)
                    .accessibilityIdentifier(cta.identifier)
                }
            }
        }
        .accessibilityIdentifier("activity.detail.content")
    }

    private var timeText: String? {
        let parts = [detail.summary.startDate, detail.summary.endDate]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " – ")
    }

    @ViewBuilder private var meetingPointText: some View {
        switch facts.meetingPoint {
        case .named(let place): Text(verbatim: place)
        case .mapOnly: Text("nativeR2.city.event.onMap")
        case .unconfirmed: Text(verbatim: "—")
        }
    }
}
