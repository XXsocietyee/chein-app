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
    /// R7-PC-B1-13: MP pages/topic/index/index.js:1312-1351 goes from a picked session straight to baoming (checkout).
    @Environment(\.topicSessionRegistrationDestination) private var registrationDestination
    @State private var flow = TopicSessionSelectionFlow()
    @State private var path: [Int] = []

    private var resolution: TopicSessionSelectionResolution {
        TopicSessionSelectionResolution.resolve(activities: detail.activities, hasDestination: activityDestination != nil)
    }

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
                }
                if !detail.tickets.isEmpty {
                    Section("topic.tickets") {
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
                                    TopicPrice(value: ticket.price, label: "topic.price")
                                    if let start = ticket.startTime { LabeledContent("topic.start", value: start) }
                                    if let end = ticket.endTime { LabeledContent("topic.end", value: end) }
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
            .appNavigationTitle("topic.sessionSelection.title")
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
            if let start = activity.startDate { LabeledContent("topic.start", value: start) }
            if let end = activity.endDate { LabeledContent("topic.end", value: end) }
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
