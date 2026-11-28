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
/// `List` with `LabeledContent` facts and the CTA in the bottom toolbar. Sections follow the MP detail order:
/// header → cancelled → facts → 主题路线 → 关于 → people / plays → 票种 → 评价; then native extras. Read-only; every action is a
/// closure supplied by the existing detail screen.
@MainActor struct CityOrientationEventDetailList<More: View>: View {
    @Environment(\.locale) private var locale
    let detail: ActivityDetail
    let priceLine: Text?
    /// Nil when this entry point does not offer registration (same `registrationEnabled` gate as before).
    let cta: CityOrientationEventCTA?
    var onDirections: (() -> Void)? = nil
    var onReview: (() -> Void)? = nil
    var topicDestination: AnyView? = nil
    /// MP order (scene-play-activity-detail index.wxml): 主理人 / N 人已报名 / 关联玩法模板 sit between 关于 and 票种.
    var people: AnyView? = nil
    /// MP 评价 block follows 票种.
    var reviews: AnyView? = nil
    var channel: AnyView? = nil
    @ViewBuilder var more: () -> More

    private var facts: ActivityDetailHeaderFacts { ActivityDetailHeaderFacts(detail: detail) }

    var body: some View {
        List {
            // design-r2-play P15: place facts in one line, actions as a pill row (Apple Maps place card).
            // name → category · area → live status in colour ("Starts in 12 min") → Directions · Share capsules.
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: detail.summary.name).font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let line = placeLine {
                        Text(verbatim: line).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("activity.detail.category")
                    }
                    if !detail.isCancelled {
                        ExploreStartsInLine(startRaw: detail.summary.startDate, endRaw: detail.summary.endDate, tint: CYColor.successText)
                    }
                    actionPills
                }
                .padding(.vertical, 4)
            }
            if detail.isCancelled {
                Section {
                    Label("activity.cancelled.title", systemImage: "xmark.octagon").foregroundStyle(CYColor.dangerText)
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
                // MP `openLocation`: the 集合点 row opens Maps (the page has no embedded map).
                if let onDirections, detail.summary.hasValidCoordinates {
                    Button(action: onDirections) {
                        LabeledContent("nativeR2.city.event.meetingPoint") { meetingPointText }
                            .foregroundStyle(.primary)
                    }
                    .accessibilityHint(Text("activity.meetingPoint.openMaps"))
                    .accessibilityIdentifier("activity.detail.meetingPoint")
                } else {
                    LabeledContent("nativeR2.city.event.meetingPoint") { meetingPointText }
                        .accessibilityIdentifier("activity.detail.meetingPoint")
                }
                LabeledContent("nativeR2.city.event.registered") {
                    Text(verbatim: facts.registrationCount.map(String.init) ?? "—").monospacedDigit()
                }
                .accessibilityIdentifier("activity.detail.registeredCount")
                if let priceLine {
                    LabeledContent("nativeR2.city.event.price") { priceLine }
                        .accessibilityIdentifier("activity.pinned.summary")
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
            if let people { people }
            Section("nativeR2.city.event.tickets") {
                if detail.tickets.isEmpty {
                    Text("activity.source.noTickets").foregroundStyle(.secondary)
                }
                ForEach(detail.tickets) { ticket in
                    LabeledContent {
                        Text(verbatim: ticket.price.map { LocaleDisplay.money($0, locale: locale) } ?? "—").monospacedDigit()
                    } label: {
                        Text(verbatim: ticket.name)
                        if let left = ticket.remainingInventory { Text("nativeR2.city.event.remaining \(left)") }
                    }
                }
            }
            if let reviews { reviews }
            Section {
                if let onReview {
                    Button(action: onReview) { Label("context.review.title", systemImage: "square.and.pencil") }
                        .accessibilityIdentifier("activity.openReview")
                }
                Label("activity.reviewPointsNote", systemImage: "star")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("activity.detail.readOnly")
            }
            // Native extra (no MP section): the in-game channel, after the MP sections.
            if let channel { Section { channel } }
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

    /// P15 "category · area": the MP category names, then the named meeting place when there is one.
    private var placeLine: String? {
        var parts: [String] = []
        if let category = facts.categoryText { parts.append(category) }
        if case .named(let place) = facts.meetingPoint { parts.append(place) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var shareText: String {
        [detail.summary.name, timeText].compactMap { $0 }.joined(separator: " · ")
    }

    /// Name · time, then the `pages/activity/detail/index?id=` universal link when it parses back (else text only).
    private var shareItem: String {
        guard let url = PublicContentShareLink.activity(id: detail.summary.id) else { return shareText }
        return shareText + "\n" + url.absoluteString
    }

    /// P15 capsule row. Scrolls sideways when English labels run long (P12); Directions keeps its identifier.
    private var actionPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let onDirections, detail.summary.hasValidCoordinates {
                    Button(action: onDirections) {
                        Label("nativeR2.city.event.directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                    }
                    .accessibilityIdentifier("nativeR2.city.event.directions")
                }
                // MP pages/activity/detail onShareAppMessage path `?id=`: share the activity link, not bare text.
                ShareLink(item: shareItem) {
                    Label("nativeR2.city.finish.share", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("activity.detail.share")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .font(.subheadline.weight(.semibold))
        }
        .padding(.top, 4)
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
