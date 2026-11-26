import SwiftUI

/// Mini event-ops series copy around the existing draft bindings. It never submits or validates for the command.
@MainActor struct ClubOpsEventSeriesFields: View {
    let operation: ClubGovernanceMutation
    @Binding var capacity: String
    @Binding var waitlist: Bool
    /// CLB-event-ops-06 (MP event-ops wxml:253, js:581): the selected topic's facts from the eventTopics read.
    /// A multi-ticket topic (`sessionTicketCount > 1`) keeps each ticket's capacity, so the field is hidden.
    var topicFact: ClubOpsEventTopicFact? = nil
    var body: some View {
        if operation == .updateSeries {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("clubOpsEvent.edit.locked", tableName: "ClubOpsEvent").cyText(.meta)
                    .accessibilityIdentifier("clubOpsEvent.edit.locked")
                Text("clubOpsEvent.series.note", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                Text("clubOpsEvent.refundAnchor", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        } else if operation == .createSeries {
            VStack(alignment: .leading, spacing: 6) {
                Text("clubOpsEvent.recurrence.note", tableName: "ClubOpsEvent").cyText(.bodyCompact).foregroundStyle(.secondary)
                Text("clubOpsEvent.refundAnchor", tableName: "ClubOpsEvent").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
            if topicFact?.showsCapacity ?? true {
            VStack(alignment: .leading, spacing: 6) {
                Text("clubOpsEvent.section.capacity", tableName: "ClubOpsEvent").cyText(.cardTitle)
                Text("clubOpsEvent.capacity.note", tableName: "ClubOpsEvent").cyText(.bodyCompact).foregroundStyle(.secondary)
                Text("club.gov.field.capacity")
                TextField(text: $capacity, prompt: Text("clubOpsEvent.capacity.placeholder", tableName: "ClubOpsEvent")) { Text("club.gov.field.capacity") }
                    .keyboardType(.numberPad).accessibilityIdentifier("club.gov.input.capacity")
                if ClubOpsEventInput.capacityInvalid(capacity) {
                    Text("clubOpsEvent.capacity.invalid", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("clubOpsEvent.capacity.invalid")
                }
                Text("clubOpsEvent.capacity.help", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(.secondary)
            }
            }
            Toggle("club.gov.field.waitlistEnabled", isOn: $waitlist).accessibilityIdentifier("club.gov.input.waitlistEnabled")
        }
    }
}

/// Explains the existing offer field; the hidden value still goes through the command's 5...1440 check.
@MainActor struct ClubOpsEventOfferHelp: View {
    let minutes: String
    let visible: Bool
    private var offerReadout: String? {
        guard let value = Int(minutes.trimmingCharacters(in: .whitespaces)) else { return nil }
        let text = ClubEventOpsFormRules.offerWindowText(minutes: value)
        return text.isEmpty ? nil : text
    }
    var body: some View {
        if visible {
            // CLB-event-ops-06 (MP event-ops wxml:264, js:233 offerWindowText): the 候补认领时长 readout, e.g. 「1 天」.
            if let readout = offerReadout {
                Text(verbatim: readout).cyText(.bodyCompact, weight: .semibold)
                    .accessibilityIdentifier("clubOpsEvent.offer.readout")
            }
            Text("clubOpsEvent.offer.placeholder", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(.secondary)
            Text("clubOpsEvent.offer.help", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(.secondary)
        }
        if ClubOpsEventInput.offerInvalid(minutes) {
            Text("clubOpsEvent.offer.invalid", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(CYColor.dangerText)
                .accessibilityIdentifier("clubOpsEvent.offer.invalid")
        }
    }
}

/// Reason input for cancel/correct with the mini placeholder and inline range message.
@MainActor struct ClubOpsEventReasonField: View {
    let operation: ClubGovernanceMutation
    @Binding var reason: String
    var body: some View {
        let cancel = operation == .cancelOccurrence
        VStack(alignment: .leading, spacing: 4) {
            TextField(text: $reason, prompt: Text(cancel ? "clubOpsEvent.cancel.placeholder" : "clubOpsEvent.correct.placeholder", tableName: "ClubOpsEvent"),
                      axis: .vertical) { Text("club.gov.field.reason") }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("club.gov.input.reason")
            if !reason.isEmpty, cancel ? ClubOpsEventInput.cancelReasonInvalid(reason) : ClubOpsEventInput.correctionReasonInvalid(reason) {
                Text(cancel ? "clubOpsEvent.cancel.reasonInvalid" : "clubOpsEvent.correct.reasonInvalid", tableName: "ClubOpsEvent")
                    .cyText(.meta).foregroundStyle(CYColor.dangerText).accessibilityIdentifier("clubOpsEvent.reason.invalid")
            }
            if cancel {
                Text("clubOpsEvent.cancel.subtitle", tableName: "ClubOpsEvent").cyText(.bodyCompact).foregroundStyle(.secondary)
            }
        }
    }
}

struct ClubOpsEventVisibility: ViewModifier {
    let visible: Bool
    @ViewBuilder func body(content: Content) -> some View { if visible { content } }
}
extension View {
    func clubOpsEventVisible(_ visible: Bool) -> some View { modifier(ClubOpsEventVisibility(visible: visible)) }
}

enum ClubOpsEventFormCopy {
    static func title(_ route: ClubGovernanceFormRoute) -> Text {
        if route.operation == .correctAttendance, let arrived = route.seed["arrived"]?.bool {
            return Text(arrived ? "clubOpsEvent.correct.toArrived" : "clubOpsEvent.correct.toAbsent", tableName: "ClubOpsEvent")
        }
        // Mini roles page: the button reads 分配 under the 分配固定角色 section, so the sheet keeps the section name.
        if route.operation == .assignRole { return Text("clubOpsGov.roles.assign.title", tableName: "ClubOpsGovernance") }
        // CLB-group-code-04 (fix-r3-club-b): MP sheet title 活动核验团码.
        if route.operation == .issueGroupCode { return Text("clubR3b.groupCode.title") }
        return Text(LocalizedStringKey("club.gov.action." + route.operation.rawValue))
    }
}

/// CLB-event-ops-06: the eventTopics fact for the topic a create-series form was opened from.
/// Set by ClubSeriesCreationPresentationOwner; nil keeps the capacity field (the MP default ticketCount 1).
private struct ClubOpsEventTopicFactKey: EnvironmentKey {
    static let defaultValue: ClubOpsEventTopicFact? = nil
}
extension EnvironmentValues {
    var clubOpsEventTopicFact: ClubOpsEventTopicFact? {
        get { self[ClubOpsEventTopicFactKey.self] }
        set { self[ClubOpsEventTopicFactKey.self] = newValue }
    }
}
