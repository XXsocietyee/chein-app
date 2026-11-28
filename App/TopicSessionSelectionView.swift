import SwiftUI

/// Session-picker sheet for a topic. It only displays the activities already
/// loaded with the topic and forwards a chosen, real `activity.id` to the
/// host-injected activity destination (the existing activity detail and its
/// sign-up flow). It performs no request and no enrollment itself.
@MainActor
struct TopicSessionSelectionView: View {
    let detail: TopicDetail
    let scope: UUID
    var activityDestination: ((Int) -> AnyView)? = nil
    /// R7-PC-B1-13: the ticket the player tapped on the topic page (MP preselects it by name).
    var preferredTicketName: String? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    /// R7-PC-B1-13: MP pages/topic/index/index.js:1312-1351 goes from a picked session straight to baoming (checkout).
    @Environment(\.topicSessionRegistrationDestination) private var registrationDestination
    @State private var flow = TopicSessionSelectionFlow()
    @State private var path: [Int] = []

    private var resolution: TopicSessionSelectionResolution {
        TopicSessionSelectionResolution.resolve(activities: detail.activities, hasDestination: activityDestination != nil)
    }

    /// MP session-picker title: 选择票种 when the topic has one day, else 选择场次.
    private var isSingleDay: Bool { resolution.activities.count == 1 }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                switch resolution {
                case .missingData:
                    ContentUnavailableView { Label("topic.sessionSelection.missingData", systemImage: "calendar.badge.exclamationmark") }
                        .accessibilityIdentifier("topic.sessionSelection.missingData")
                case .empty:
                    ContentUnavailableView { Label("topic.sessionSelection.empty", systemImage: "calendar") }
                        .accessibilityIdentifier("topic.sessionSelection.empty")
                case .destinationUnavailable(let activities):
                    Text("topic.sessionSelection.destinationUnavailable")
                        .accessibilityIdentifier("topic.sessionSelection.destinationUnavailable")
                    ForEach(activities) { activity in activityRow(activity) }
                case .ready(let activities):
                    // MP session-picker: several days list under 日期; a single day is written out without a header.
                    Section {
                        ForEach(activities) { activity in
                            Button {
                                if let selected = flow.select(activityID: activity.id, hasDestination: activityDestination != nil) {
                                    path.append(selected)
                                }
                            } label: {
                                activityRow(activity)
                            }
                            .accessibilityIdentifier("topic.sessionSelection.activity.\(activity.id)")
                        }
                    } header: {
                        if activities.count > 1 { Text("topic.sessionSelection.dates") }
                    }
                }
                if detail.tickets.isEmpty, case .ready = resolution {
                    // MP session-picker.wxml:30 cy-empty 暂无可买票种 · sub 放票后可购买 / 换个日期试试.
                    Section("topic.sessionSelection.tickets") {
                        ContentUnavailableView {
                            Label("topic.sessionSelection.ticketsEmpty", systemImage: "ticket")
                        } description: {
                            Text(isSingleDay ? "topic.sessionSelection.ticketsEmpty.singleDay" : "topic.sessionSelection.ticketsEmpty.otherDay")
                        }
                        .accessibilityIdentifier("topic.sessionSelection.ticketsEmpty")
                    }
                } else if !detail.tickets.isEmpty {
                    Section("topic.sessionSelection.tickets") {
                        Text("topic.sessionSelection.ticketDependency")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("topic.sessionSelection.ticketDependency")
                        ForEach(Array(detail.tickets.enumerated()), id: \.offset) { _, ticket in
                            let preferred = !(preferredTicketName ?? "").isEmpty
                                && ticket.name.trimmingCharacters(in: .whitespacesAndNewlines) == preferredTicketName
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(verbatim: ticket.name).font(.headline)
                                    if let rule = ticket.refundRule, !rule.isEmpty {
                                        Text(verbatim: rule).font(.footnote).foregroundStyle(.secondary)
                                    }
                                    TopicPrice(value: ticket.price, label: "topic.price")
                                    if ticket.remaining == 0 {
                                        Text("topic.sessionSelection.soldOut").font(.footnote).foregroundStyle(.secondary)
                                    }
                                    if let start = ticket.startTime { LabeledContent("topic.start", value: LocaleDisplay.civil(start, locale: locale)) }
                                    if let end = ticket.endTime { LabeledContent("topic.end", value: LocaleDisplay.civil(end, locale: locale)) }
                                }
                                if preferred {
                                    Spacer()
                                    Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true)
                                }
                            }
                            .accessibilityAddTraits(preferred ? .isSelected : [])
                        }
                    }
                }
            }
            .appNavigationTitle(isSingleDay ? "topic.sessionSelection.ticketTitle" : "topic.sessionSelection.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("topic.sessionSelection.close") { flow.close(); dismiss() }
                        .accessibilityIdentifier("topic.sessionSelection.close")
                }
            }
            .navigationDestination(for: Int.self) { activityID in
                if let registrationDestination {
                    registrationDestination(activityID, preferredTicketName)
                } else if let activityDestination {
                    activityDestination(activityID)
                } else {
                    Text("topic.sessionSelection.destinationUnavailable")
                }
            }
        }
        .accessibilityIdentifier("topic.sessionSelection")
        .onAppear { flow.open(scope: scope, activityIDs: resolution.activities.map(\.id)) }
        .onChange(of: path) { _, newPath in
            if newPath.isEmpty { flow.returnedFromActivity() }
        }
        .onChange(of: scope) { _, newScope in
            if flow.scopeChanged(to: newScope) { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, flow.isPresented { flow.backgrounded(); dismiss() }
        }
        .cyDomainScreen(.player)
    }

    private func activityRow(_ activity: TopicActivitySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: activity.name).font(.headline).foregroundStyle(.primary)
            if let address = activity.addressName { Text(verbatim: address) }
            if let start = activity.startDate { LabeledContent("topic.start", value: LocaleDisplay.civil(start, locale: locale)) }
            if let end = activity.endDate { LabeledContent("topic.end", value: LocaleDisplay.civil(end, locale: locale)) }
        }
    }
}

private struct TopicSessionRegistrationDestinationKey: EnvironmentKey { static let defaultValue: ((Int, String?) -> AnyView)? = nil }
extension EnvironmentValues {
    /// R7-PC-B1-13: activity id + preferred ticket name → the activity detail with the registration sheet open
    /// (same as the `pages/activity/baoming/baoming` route). Nil falls back to the plain activity destination.
    var topicSessionRegistrationDestination: ((Int, String?) -> AnyView)? {
        get { self[TopicSessionRegistrationDestinationKey.self] }
        set { self[TopicSessionRegistrationDestinationKey.self] = newValue }
    }
}
