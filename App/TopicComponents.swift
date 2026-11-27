import SwiftUI

struct TopicWalkingEstimate: View {
    let minutes: Int
    let position: Int
    var body: some View {
        LabeledContent("topic.itinerary.estimatedWalkMinutes", value: String(minutes))
            .font(.subheadline)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("topic.itinerary.estimatedWalkMinutes"))
            .accessibilityValue(String(minutes))
            .accessibilityIdentifier("topic.itinerary.walk.\(position)")
    }
}

struct TopicPrice: View {
    let value: Decimal?
    let label: LocalizedStringKey
    var body: some View {
        LabeledContent(label) {
            if let value { Text(verbatim: NSDecimalNumber(decimal: value).stringValue) }
            else { Text("topic.priceUnknown") }
        }
        // Source supplies an amount but no currency code; never infer a currency symbol.
    }
}
enum TopicScreenIssue {
    case notConfigured, unauthorized, unavailable, failed
    init(_ error: Error) {
        if error as? APIError == .notConfigured { self = .notConfigured }
        else if error as? APIError == .unauthorized { self = .unauthorized }
        else if error as? TopicReadFailure == .unavailable { self = .unavailable }
        else { self = .failed }
    }
    var key: LocalizedStringKey {
        switch self {
        case .notConfigured: return "topic.notConfigured"
        case .unauthorized: return "topic.unauthorized"
        case .unavailable: return "topic.unavailable"
        case .failed: return "topic.failed"
        }
    }
}
struct TopicIssueView: View {
    let issue: TopicScreenIssue
    var retry: (() -> Void)? = nil
    /// mp-states r3: the one state pattern — ContentUnavailableView with one bordered 重试.
    var body: some View {
        ContentUnavailableView {
            Label(issue.key, systemImage: "exclamationmark.triangle")
        } actions: {
            if let retry { Button("topic.retry", action: retry).buttonStyle(.bordered).controlSize(.large) }
        }
        .accessibilityIdentifier("topic.error")
    }
}

/// Full-route metadata remains separate from the visible per-chapter projection.
struct TopicTotalStops: View {
    let count: Int?
    let identifier: String
    /// A page model's unknown mark (em dash). Nil keeps the shared `topic.countUnknown` copy.
    var unknownMark: String? = nil
    var body: some View {
        LabeledContent("topic.totalStops") {
            if let count { Text(verbatim: String(count)).accessibilityIdentifier(identifier) }
            else if let unknownMark { Text(verbatim: unknownMark).accessibilityIdentifier(identifier) }
            else { Text("topic.countUnknown").accessibilityIdentifier(identifier) }
        }
    }
}
