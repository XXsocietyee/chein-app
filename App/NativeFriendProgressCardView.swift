import SwiftUI

@MainActor struct NativeFriendProgressCardView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var copy: NativeProgressPrivacyLocalization { .init(locale: locale) }
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var model: NativeFriendProgressCard
    var body: some View {
        Section {
            switch model.state {
            case .awaitingIndex: channelChip("friendIndexPending", tint: .accentColor, systemImage: "clock")
            case .loading:
                ProgressView().frame(maxWidth: .infinity).accessibilityLabel(Text("cy.state.loading"))
            case .hidden: channelChip("hidden", tint: .secondary, systemImage: "eye.slash")
            case .unconfirmed: channelChip("unconfirmed", tint: .orange, systemImage: "questionmark")
            case .closed: channelChip("closed", tint: .secondary, systemImage: "xmark")
            case .visible(let rows):
                if rows.isEmpty {
                    ContentUnavailableView {
                        Label { Text("friendEmpty", tableName: "NativeChannelProgress") } icon: { Image(systemName: "person.2") }
                    }
                }
                ForEach(rows) { row in progressRow(row) }
            }
            if model.state != .loading {
                Button { Task { await model.activate() } } label: {
                    Label("d7.friendProgress.refresh", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("friendProgress", tableName: "NativeChannelProgress")
                .accessibilityAddTraits(.isHeader)
        }
        .privacySensitive().accessibilityIdentifier("friendProgress.card")
        .transaction { if reduceMotion { $0.disablesAnimations = true } }
        .task { await model.activate() }
        .onDisappear { model.invalidate() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.activate() } } else { model.invalidate() } }
    }
    private func channelChip(_ key: String, tint: Color, systemImage: String) -> some View {
        Label(channel(key), systemImage: systemImage).foregroundStyle(tint)
    }
    private func channel(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NativeChannelProgress", locale: locale))
    }
    private func progressRow(_ row: NativeFriendProgressItem) -> some View {
        let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let shown = title.isEmpty ? "—" : title
        return Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading) {
                    progressTitle(shown, asOf: row.meter.asOf)
                    progressFigures(row)
                }
            } else {
                HStack {
                    Label {
                        progressTitle(shown, asOf: row.meter.asOf)
                    } icon: {
                        Image(systemName: "figure.walk").accessibilityHidden(true)
                    }
                    Spacer(minLength: 0)
                    progressFigures(row)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
    private func progressTitle(_ title: String, asOf: String?) -> some View {
        VStack(alignment: .leading) {
            Text(verbatim: title)
                .fixedSize(horizontal: false, vertical: true)
            if let asOf {
                let stamp = asOf.trimmingCharacters(in: .whitespacesAndNewlines)
                Text(verbatim: stamp.isEmpty ? "—" : stamp)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    @ViewBuilder private func progressFigures(_ row: NativeFriendProgressItem) -> some View {
        let alignment: HorizontalAlignment = typeSize.isAccessibilitySize ? .leading : .trailing
        VStack(alignment: alignment) {
            if let done = row.meter.done, let required = row.meter.required {
                Text(verbatim: copy.format("p31.friend.fraction", copy.number(done), copy.number(required)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let percent = row.meter.percent {
                Text(verbatim: copy.format("p31.friend.percent", copy.number(percent)))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if row.meter.done == nil && row.meter.percent == nil {
                Text(verbatim: "—")
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Stable card ownership across unrelated parent rerenders; private facts are never disk-cached.
@MainActor struct NativeFriendProgressCardHost: View {
    @State private var model: NativeFriendProgressCard
    init(model: NativeFriendProgressCard) { _model = State(initialValue: model) }
    var body: some View { NativeFriendProgressCardView(model: model) }
}
