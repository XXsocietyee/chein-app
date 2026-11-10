import SwiftUI

@MainActor struct NativeFriendProgressCardView: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var copy: NativeProgressPrivacyLocalization { .init(locale: locale) }
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var model: NativeFriendProgressCard
    var body: some View {
        Section {
            switch model.state {
            case .awaitingIndex: channelChip("friendIndexPending", tone: .info, systemImage: "clock")
            case .loading:
                CYSkeleton().accessibilityLabel(Text("cy.state.loading"))
            case .hidden: channelChip("hidden", tone: .neutral, systemImage: "eye.slash")
            case .unconfirmed: channelChip("unconfirmed", tone: .warning, systemImage: "questionmark")
            case .closed: channelChip("closed", tone: .neutral, systemImage: "xmark")
            case .visible(let rows):
                if rows.isEmpty { CYEmptyState(systemImage: "person.2", "friendEmpty", tableName: "NativeChannelProgress") }
                ForEach(rows) { row in progressRow(row) }
            }
            if model.state != .loading {
                CYPillButton("d7.friendProgress.refresh", style: .secondary, systemImage: "arrow.clockwise") { Task { await model.activate() } }
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("friendProgress", tableName: "NativeChannelProgress")
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .font(CYTypography.body)
        .privacySensitive().accessibilityIdentifier("friendProgress.card")
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .task { await model.activate() }
        .onDisappear { model.invalidate() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.activate() } } else { model.invalidate() } }
        .tint(palette.brand)
    }
    private func channelChip(_ key: String, tone: CYStatusTone, systemImage: String) -> some View {
        CYStatusChip(verbatim: channel(key), tone: tone, systemImage: systemImage)
    }
    private func channel(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeChannelProgress", locale: locale))
    }
    private func progressRow(_ row: NativeFriendProgressItem) -> some View {
        let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = title.isEmpty ? "—" : title
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    progressTitle(shown, asOf: row.meter.asOf)
                    progressFigures(row)
                }
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    personArt(shown)
                    progressTitle(shown, asOf: row.meter.asOf)
                    Spacer(minLength: CYSpacing.sm)
                    progressFigures(row)
                }
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
    private func progressTitle(_ title: String, asOf: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: title)
                .font(CYTypography.cardTitle)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            if let asOf {
                let stamp = asOf.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(verbatim: stamp.isEmpty ? "—" : stamp)
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    @ViewBuilder private func progressFigures(_ row: NativeFriendProgressItem) -> some View {
        let alignment: HorizontalAlignment = typeSize.isAccessibilitySize ? .leading : .trailing
        VStack(alignment: alignment, spacing: CYSpacing.xxs) {
            if let done = row.meter.done, let required = row.meter.required {
                Text(verbatim: copy.format("p31.friend.fraction", copy.number(done), copy.number(required)))
                    .font(CYTypography.numericBody)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
            }
            if let percent = row.meter.percent {
                Text(verbatim: copy.format("p31.friend.percent", copy.number(percent)))
                    .font(CYTypography.numericBody)
                    .foregroundStyle(palette.textSecondary)
                    .monospacedDigit()
            }
            if row.meter.done == nil && row.meter.percent == nil {
                Text(verbatim: "—")
                    .font(CYTypography.numericBody)
                    .foregroundStyle(palette.textTertiary)
            }
        }
    }
    private func personArt(_ seed: String) -> some View {
        Color.clear
            .frame(width: 40, height: 40)
            .overlay { CYCoverArt(seed: seed == "—" ? "friend-progress" : seed, symbol: "figure.walk", showsDebugLabel: false) }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Stable card ownership across unrelated parent rerenders; private facts are never disk-cached.
@MainActor struct NativeFriendProgressCardHost: View {
    @State private var model: NativeFriendProgressCard
    init(model: NativeFriendProgressCard) { _model = State(initialValue: model) }
    var body: some View { NativeFriendProgressCardView(model: model) }
}
