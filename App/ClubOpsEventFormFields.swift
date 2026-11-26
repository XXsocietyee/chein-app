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
                Text("clubOpsEvent.edit.locked", tableName: "ClubOpsEvent").font(.footnote)
                    .accessibilityIdentifier("clubOpsEvent.edit.locked")
                Text("clubOpsEvent.series.note", tableName: "ClubOpsEvent").font(.footnote).foregroundStyle(.secondary)
                Text("clubOpsEvent.refundAnchor", tableName: "ClubOpsEvent").font(.footnote).foregroundStyle(.secondary)
            }
        } else if operation == .createSeries {
            VStack(alignment: .leading, spacing: 6) {
                Text("clubOpsEvent.recurrence.note", tableName: "ClubOpsEvent").font(.subheadline).foregroundStyle(.secondary)
                Text("clubOpsEvent.refundAnchor", tableName: "ClubOpsEvent").font(.subheadline).foregroundStyle(.secondary)
            }
            // CLB-G15 (MP event-ops wxml:199): the selected topic cannot take online payment for priced sessions.
            if let notice = topicFact?.paymentNotice, !notice.isEmpty {
                Label("club.eventOps.paymentNotice", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("clubOpsEvent.paymentNotice")
            }
            // CLB-r10-nat-event-ops-04: 容量 and 候补 are their own Section (ClubOpsEventCapacitySection).
        }
    }
}

/// CLB-r10-nat-event-ops-04 (MP event-ops wxml:253 人数上限 + 候补): its own Form Section, the capacity
/// notes and the inline validation in the footer, one labelled TextField (no caption above it).
@MainActor struct ClubOpsEventCapacitySection: View {
    @Binding var capacity: String
    @Binding var waitlist: Bool
    /// CLB-event-ops-06: a multi-ticket topic keeps each ticket's capacity, so the field is hidden.
    let showsCapacity: Bool
    var body: some View {
        Section {
            if showsCapacity {
                TextField(text: $capacity, prompt: Text("clubOpsEvent.capacity.placeholder", tableName: "ClubOpsEvent")) { Text("club.gov.field.capacity") }
                    .keyboardType(.numberPad).accessibilityIdentifier("club.gov.input.capacity")
            }
            Toggle("club.gov.field.waitlistEnabled", isOn: $waitlist).accessibilityIdentifier("club.gov.input.waitlistEnabled")
        } header: {
            Text("clubOpsEvent.section.capacity", tableName: "ClubOpsEvent")
        } footer: {
            if showsCapacity { footer }
        }
    }
    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("clubOpsEvent.capacity.note", tableName: "ClubOpsEvent")
            if ClubOpsEventInput.capacityInvalid(capacity) {
                Text("clubOpsEvent.capacity.invalid", tableName: "ClubOpsEvent").foregroundStyle(.red)
                    .accessibilityIdentifier("clubOpsEvent.capacity.invalid")
            }
            Text("clubOpsEvent.capacity.help", tableName: "ClubOpsEvent")
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
                Text(verbatim: readout).font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("clubOpsEvent.offer.readout")
            }
            Text("clubOpsEvent.offer.placeholder", tableName: "ClubOpsEvent").font(.footnote).foregroundStyle(.secondary)
            Text("clubOpsEvent.offer.help", tableName: "ClubOpsEvent").font(.footnote).foregroundStyle(.secondary)
        }
        if ClubOpsEventInput.offerInvalid(minutes) {
            Text("clubOpsEvent.offer.invalid", tableName: "ClubOpsEvent").font(.footnote).foregroundStyle(.red)
                .accessibilityIdentifier("clubOpsEvent.offer.invalid")
        }
    }
}

/// Reason input for cancel/correct with the mini placeholder and inline range message.
/// CLB-r10-nat-event-ops-04: its own Section; the subtitle and the red validation are the Section footer.
@MainActor struct ClubOpsEventReasonField: View {
    let operation: ClubGovernanceMutation
    @Binding var reason: String
    private var cancel: Bool { operation == .cancelOccurrence }
    private var invalid: Bool {
        !reason.isEmpty && (cancel ? ClubOpsEventInput.cancelReasonInvalid(reason) : ClubOpsEventInput.correctionReasonInvalid(reason))
    }
    var body: some View {
        Section {
            TextField(text: $reason, prompt: Text(cancel ? "clubOpsEvent.cancel.placeholder" : "clubOpsEvent.correct.placeholder", tableName: "ClubOpsEvent"),
                      axis: .vertical) { Text("club.gov.field.reason") }
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("club.gov.input.reason")
        } footer: {
            if cancel || invalid {
                VStack(alignment: .leading, spacing: 4) {
                    if cancel { Text("clubOpsEvent.cancel.subtitle", tableName: "ClubOpsEvent") }
                    if invalid {
                        Text(cancel ? "clubOpsEvent.cancel.reasonInvalid" : "clubOpsEvent.correct.reasonInvalid", tableName: "ClubOpsEvent")
                            .foregroundStyle(.red).accessibilityIdentifier("clubOpsEvent.reason.invalid")
                    }
                }
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
