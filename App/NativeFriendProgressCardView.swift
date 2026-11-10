import SwiftUI

@MainActor struct NativeFriendProgressCardView: View {
    @Environment(\.themeDomain) private var domain
    @Environment(\.locale) private var locale
    private var copy: NativeProgressPrivacyLocalization { .init(locale: locale) }
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var model: NativeFriendProgressCard
    var body: some View {
        Section {
            switch model.state {
            case .awaitingIndex: CYStatusChip(verbatim: String(localized: "friendIndexPending", table: "NativeChannelProgress"), tone: .neutral, systemImage: "hourglass")
            case .loading: ProgressView()
            case .hidden: CYStatusChip(verbatim: String(localized: "hidden", table: "NativeChannelProgress"), tone: .neutral, systemImage: "eye.slash")
            case .unconfirmed: CYStatusChip(verbatim: String(localized: "unconfirmed", table: "NativeChannelProgress"), tone: .warning, systemImage: "questionmark.circle")
            case .closed: CYStatusChip(verbatim: String(localized: "closed", table: "NativeChannelProgress"), tone: .neutral, systemImage: "lock")
            case .visible(let rows):
                if rows.isEmpty { CYEmptyState(systemImage: "person.2", "friendEmpty", tableName: "NativeChannelProgress") }
                ForEach(rows) { row in
                    LabeledContent {
                        VStack(alignment: .trailing, spacing: Theme.Space.s1) {
                            if let done = row.meter.done, let required = row.meter.required { Text(verbatim: copy.format("p31.friend.fraction", copy.number(done), copy.number(required))).monospacedDigit() }
                            if let percent = row.meter.percent { Text(verbatim: copy.format("p31.friend.percent", copy.number(percent))).monospacedDigit() }
                            if row.meter.done == nil && row.meter.percent == nil { Text(verbatim: "—") }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: Theme.Space.s1) {
                            Text(verbatim: row.title).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                            if let at = row.meter.asOf { Text(verbatim: at).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                        }
                    }
                }
            }
            if model.state != .loading {
                CYPillButton("d7.friendProgress.refresh", style: .secondary, systemImage: "arrow.clockwise") { Task { await model.activate() } }
            }
        } header: { Text("friendProgress", tableName: "NativeChannelProgress") }
        .font(Theme.Font.body)
        .privacySensitive().accessibilityIdentifier("friendProgress.card")
        .task { await model.activate() }
        .onDisappear { model.invalidate() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.activate() } } else { model.invalidate() } }
        .tint(Theme.Color.accent(in: domain))
    }
}

/// Stable card ownership across unrelated parent rerenders; private facts are never disk-cached.
@MainActor struct NativeFriendProgressCardHost: View {
    @State private var model: NativeFriendProgressCard
    init(model: NativeFriendProgressCard) { _model = State(initialValue: model) }
    var body: some View { NativeFriendProgressCardView(model: model) }
}
