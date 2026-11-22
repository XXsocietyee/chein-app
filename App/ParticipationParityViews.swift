import SwiftUI

/// Source mycanyu/mycanyuinfo presentation pieces. Display only; no reads or writes start here.
struct ParticipationStatusBadge: View {
    let status: ParticipationStatus
    let detail: Bool
    var body: some View {
        ParticipationTag(key: status.labelKey, tone: status.tone(detail: detail))
            .accessibilityIdentifier("playerJourney.status")
    }
}

struct ParticipationTag: View {
    let key: String
    let tone: ParticipationStatus.Tone
    private var color: Color {
        switch tone {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .neutral: return .secondary
        }
    }
    var body: some View {
        Text(LocalizedStringKey(key)).cyText(.meta, weight: .semibold)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}

/// Header card: name, 距离路线开始还剩N天 (1–3 Shanghai calendar days) or the full date range,
/// mode and status badges, then the description.
struct ParticipationDetailHeader: View {
    let detail: ParticipationDetail
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        let record = detail.record
        Section {
            VStack(alignment: .leading, spacing: Theme.Space.s3) {
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s2))
                    : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: Theme.Space.s3))) {
                    Group {
                        if let name = record.name { Text(verbatim: name) }
                        else { Text("playerJourney.parity.unknownTopic") }
                    }
                    .cyText(.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    TimelineView(.periodic(from: Date(), by: 60)) { clock in
                        ParticipationScheduleBadge(presentation: ProfileParticipationSchedule(
                            start: record.order.ownerStartDate, end: record.order.ownerEndDate).presentation(now: clock.date))
                    }
                }
                (typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: Theme.Space.s2))
                    : AnyLayout(HStackLayout(spacing: Theme.Space.s2))) {
                    ParticipationTag(key: record.modeKey, tone: record.isFreeExplore ? .success : .info)
                        .accessibilityIdentifier("playerJourney.mode")
                    ParticipationStatusBadge(status: record.participationStatus(), detail: true)
                }
                if let description = detail.description {
                    Text(verbatim: description).cyText(.body).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }.padding(.vertical, 4)
        }
    }
}

struct ParticipationScheduleBadge: View {
    let presentation: ProfileParticipationSchedule.Presentation
    var body: some View {
        if let days = presentation.reminderDays {
            Text("playerJourney.parity.countdown \(days)").cyText(.meta, weight: .semibold).foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playerJourney.countdown")
        } else if let range = presentation.range {
            Text(verbatim: range).cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playerJourney.dateRange")
        }
    }
}

struct ParticipationIssueView: View {
    let issue: ParticipationLoadIssue
    let retry: () -> Void
    var body: some View {
        let kind: CYStateKind = {
            switch issue.kind {
            case .notConfigured: return .offline
            case .signIn: return .generic
            case .failed: return .failure
            }
        }()
        let detail: Text? = issue.kind == .failed
            ? (issue.serverMessage.map { Text(verbatim: $0) } ?? Text(LocalizedStringKey(issue.fallbackKey)))
            : (issue.kind == .notConfigured ? Text(LocalizedStringKey(issue.fallbackKey)) : nil)
        return CYStateLayout(
            kind: kind,
            title: Text(LocalizedStringKey(issue.titleKey)),
            detail: detail,
            primary: ("action.retry", retry)
        )
        .accessibilityIdentifier("playerJourney.issue")
    }
}
