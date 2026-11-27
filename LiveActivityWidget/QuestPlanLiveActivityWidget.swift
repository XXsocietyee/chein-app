import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// Components r1 R-island: the shared invite / plan Live Activity (`QuestPlanActivityAttributes`).
/// Expanded Dynamic Island and Lock Screen show the plan card: eyebrow (team / club), headline question, a taped-note line,
/// one or two stickers, and 加入 (a `Link` into the app) / 稍后 (`QuestPlanTuckIntent`, folds the card to the pill).
/// Tucked, the expanded region keeps only the headline and the Lock Screen a single line. System fonts, SF Symbols,
/// `Text(timerInterval:countsDown: true)` and a system `ProgressView`; one accent per kind; dark high-contrast surface.
struct QuestPlanLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuestPlanActivityAttributes.self) { context in
            QuestPlanLockScreenView(attributes: context.attributes, state: context.state, isStale: context.isStale)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
                .environment(\.colorScheme, .dark)
                .widgetURL(QuestPlanLinks.join(kind: context.attributes.kind, targetID: context.attributes.targetID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    QuestPlanStickerStack(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    QuestPlanTrailingValue(attributes: context.attributes, state: context.state, isStale: context.isStale)
                        .font(.title3.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    QuestPlanHeadline(attributes: context.attributes, state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if !context.state.isTucked {
                        VStack(alignment: .leading, spacing: 8) {
                            QuestPlanTapedNote(state: context.state)
                            QuestPlanTeamProgress(attributes: context.attributes, state: context.state)
                            QuestPlanActionRow(attributes: context.attributes, state: context.state)
                        }
                    }
                }
            } compactLeading: {
                QuestPlanGlyph(attributes: context.attributes, state: context.state)
            } compactTrailing: {
                QuestPlanCompactValue(attributes: context.attributes, state: context.state, isStale: context.isStale)
                    .font(.caption.monospacedDigit())
            } minimal: {
                QuestPlanGlyph(attributes: context.attributes, state: context.state)
            }
            .keylineTint(QuestPlanStyle.tint(context.attributes.kind))
            .widgetURL(QuestPlanLinks.join(kind: context.attributes.kind, targetID: context.attributes.targetID))
        }
    }
}

enum QuestPlanStyle {
    static func tint(_ kind: QuestPlanKind) -> Color {
        switch kind {
        case .teamInvite, .friendInvite: return .green
        case .clubEvent: return .accentColor
        case .teamStatus: return .orange
        }
    }
    static func symbol(_ kind: QuestPlanKind) -> String {
        switch kind {
        case .teamInvite: return "person.2.fill"
        case .friendInvite: return "figure.walk"
        case .clubEvent: return "calendar.badge.clock"
        case .teamStatus: return "flag.checkered"
        }
    }
    static func title(_ kind: QuestPlanKind) -> LocalizedStringKey {
        switch kind {
        case .teamInvite: return "plan.teamInvite.title"
        case .friendInvite: return "plan.friendInvite.title"
        case .clubEvent: return "plan.clubEvent.title"
        case .teamStatus: return "plan.teamStatus.title"
        }
    }
}

/// Compact leading / minimal: the first sticker, else the kind's symbol.
struct QuestPlanGlyph: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    var body: some View {
        Group {
            switch state.visibleStickers.first {
            case .emoji(let value): Text(verbatim: value)
            case .symbol(let name): Image(systemName: name)
            case nil: Image(systemName: QuestPlanStyle.symbol(attributes.kind))
            }
        }
        .foregroundStyle(QuestPlanStyle.tint(attributes.kind))
        .accessibilityLabel(Text(QuestPlanStyle.title(attributes.kind)))
    }
}

/// Expanded leading: up to two stickers, slightly turned like stickers on a note.
struct QuestPlanStickerStack: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    var body: some View {
        let stickers = state.visibleStickers
        HStack(spacing: -6) {
            if stickers.isEmpty {
                sticker(.symbol(QuestPlanStyle.symbol(attributes.kind)), turn: -6)
            } else {
                ForEach(Array(stickers.enumerated()), id: \.offset) { index, value in
                    sticker(value, turn: index == 0 ? -8 : 7)
                }
            }
        }
        .accessibilityHidden(true)
    }
    @ViewBuilder private func sticker(_ value: QuestPlanSticker, turn: Double) -> some View {
        Group {
            switch value {
            case .emoji(let emoji): Text(verbatim: emoji).font(.title2)
            case .symbol(let name):
                Image(systemName: name)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(QuestPlanStyle.tint(attributes.kind))
            }
        }
        .frame(width: 36, height: 36)
        .background(Circle().fill(Color.white.opacity(0.12)))
        .rotationEffect(.degrees(turn))
    }
}

/// Eyebrow (team / club name or the kind) over the headline question.
struct QuestPlanHeadline: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let title = attributes.title { Text(verbatim: title) } else { Text(QuestPlanStyle.title(attributes.kind)) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            Text(verbatim: state.headline)
                .font(.headline)
                .lineLimit(state.isTucked ? 1 : 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The taped-note line: a pale slip with a strip of "tape" across its top edge.
struct QuestPlanTapedNote: View {
    let state: QuestPlanContent
    var body: some View {
        if let note = state.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            Text(verbatim: note)
                .font(.subheadline)
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)
                .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.yellow.opacity(0.9)))
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 34, height: 9)
                        .rotationEffect(.degrees(-4))
                        .offset(y: -4)
                        .accessibilityHidden(true)
                }
                .rotationEffect(.degrees(-1.5))
                .accessibilityLabel(Text(verbatim: note))
        }
    }
}

/// Starts-in countdown while ahead, team "2/5" for a status card, otherwise nothing.
struct QuestPlanTrailingValue: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    let isStale: Bool
    var body: some View {
        if !isStale, let interval = state.startInterval(now: Date()) {
            VStack(alignment: .trailing, spacing: 0) {
                Text("plan.startsIn").font(.caption2).foregroundStyle(.secondary)
                Text(timerInterval: interval, countsDown: true)
                    .foregroundStyle(QuestPlanStyle.tint(attributes.kind))
                    .frame(maxWidth: 72, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
        } else if state.startsAt != nil {
            Text("plan.started").font(.caption)
        } else if attributes.kind == .teamStatus, state.total != nil {
            Text(verbatim: QuestLiveActivityText.fraction(state.done, state.total))
        }
    }
}

struct QuestPlanCompactValue: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    let isStale: Bool
    var body: some View {
        if !isStale, let interval = state.startInterval(now: Date()) {
            Text(timerInterval: interval, countsDown: true).frame(maxWidth: 52)
        } else if attributes.kind == .teamStatus, state.total != nil {
            Text(verbatim: QuestLiveActivityText.fraction(state.done, state.total))
        } else if state.joined == true {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(QuestPlanStyle.tint(attributes.kind))
                .accessibilityLabel(Text("plan.joined"))
        } else {
            Image(systemName: "envelope.badge.fill")
                .foregroundStyle(QuestPlanStyle.tint(attributes.kind))
                .accessibilityLabel(Text(QuestPlanStyle.title(attributes.kind)))
        }
    }
}

/// G-088 style: system progress bar for team status (members done / team size).
struct QuestPlanTeamProgress: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    var body: some View {
        if attributes.kind == .teamStatus, let progress = QuestLiveActivityText.progress(state.done, state.total) {
            ProgressView(value: progress.value, total: progress.total)
                .tint(QuestPlanStyle.tint(attributes.kind))
                .accessibilityLabel(Text("plan.teamStatus.progress"))
                .accessibilityValue(Text(verbatim: QuestLiveActivityText.fraction(state.done, state.total)))
        }
    }
}

/// 加入 (opens the app on the plan) and 稍后 (Tuck). Status cards have nothing to join, so only 稍后 shows.
struct QuestPlanActionRow: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    var body: some View {
        if state.joined == true {
            Label("plan.joined", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(QuestPlanStyle.tint(attributes.kind))
        } else if state.showsActions {
            HStack(spacing: 8) {
                if let url = QuestPlanLinks.join(kind: attributes.kind, targetID: attributes.targetID) {
                    Link(destination: url) {
                        Label("plan.action.join", systemImage: "hand.wave.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(QuestPlanStyle.tint(attributes.kind)))
                            .foregroundStyle(Color.black)
                    }
                    .accessibilityLabel(Text("plan.action.join"))
                }
                Button(intent: QuestPlanTuckIntent(planKey: attributes.planKey)) {
                    Label("plan.action.later", systemImage: "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color.white)
                .accessibilityLabel(Text("plan.action.later"))
                .accessibilityHint(Text("plan.action.later.hint"))
            }
        }
    }
}

struct QuestPlanLockScreenView: View {
    let attributes: QuestPlanActivityAttributes
    let state: QuestPlanContent
    let isStale: Bool
    var body: some View {
        if state.isTucked {
            HStack(spacing: 10) {
                QuestPlanGlyph(attributes: attributes, state: state)
                Text(verbatim: state.headline).font(.subheadline.weight(.semibold)).lineLimit(1)
                Spacer()
                QuestPlanCompactValue(attributes: attributes, state: state, isStale: isStale)
                    .font(.subheadline.monospacedDigit())
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    QuestPlanStickerStack(attributes: attributes, state: state)
                    QuestPlanHeadline(attributes: attributes, state: state)
                    QuestPlanTrailingValue(attributes: attributes, state: state, isStale: isStale)
                        .font(.title3.monospacedDigit())
                }
                QuestPlanTapedNote(state: state)
                QuestPlanTeamProgress(attributes: attributes, state: state)
                QuestPlanActionRow(attributes: attributes, state: state)
            }
        }
    }
}
