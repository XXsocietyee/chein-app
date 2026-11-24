import SwiftUI

private struct PlayGameStageKey: EnvironmentKey { static let defaultValue: PlayGameStage? = nil }

extension EnvironmentValues {
    /// The station a game is played at. The play host sets this once it knows the route.
    /// A kit opened without it shows no story header.
    var playGameStage: PlayGameStage? {
        get { self[PlayGameStageKey.self] }
        set { self[PlayGameStageKey.self] = newValue }
    }
}

/// 「第N站 · 站名」 with its chapter, then the station's lead line.
@MainActor struct PlayGameStageHeader: View {
    let stage: PlayGameStage
    var body: some View {
        if !stage.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if stage.ordinal != nil || stage.stationName != nil || stage.chapterTitle != nil {
                    VStack(alignment: .leading, spacing: 2) {
                        stationLine.font(.subheadline.weight(.semibold)).foregroundStyle(.tint)
                        if let chapter = stage.chapterTitle {
                            Text(verbatim: chapter).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isHeader)
                }
                if let lead = stage.lead {
                    Text(verbatim: lead).font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("playGame.stage.lead")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("playGame.stage.header")
        }
    }
    @ViewBuilder private var stationLine: some View {
        switch (stage.ordinal, stage.stationName) {
        case let (ordinal?, name?): Text("playGame.stage.station \(ordinal) \(name)")
        case let (ordinal?, nil): Text("playGame.stage.stationNumber \(ordinal)")
        case let (nil, name?): Text(verbatim: name)
        case (nil, nil): EmptyView()
        }
    }
}

/// The finished game, told in the story's voice. Pass and fail labels stay beside it.
@MainActor struct PlayGameResultLine: View {
    let outcome: PlayGameOutcome
    var open = false
    var body: some View {
        Label {
            Text(LocalizedStringKey(outcome.key(open: open))).font(.body)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).foregroundStyle(outcome == .passed ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
        }
        .accessibilityIdentifier("playkit.result.story")
    }
    private var symbol: String {
        switch outcome {
        case .passed: return "checkmark.circle.fill"
        case .notPassed: return "arrow.uturn.backward.circle"
        case .recorded: return "bookmark.circle"
        case .noVerdict: return "ellipsis.circle"
        }
    }
}

/// Fixed 4:3 frame so a loading picture does not push the controls.
@MainActor struct PlayGameImagePlaceholder: View {
    let titleKey: LocalizedStringKey
    var systemImage = "photo"
    var loading = false
    var body: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.quaternary)
            .aspectRatio(4.0 / 3.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                VStack(spacing: 8) {
                    if loading { ProgressView() } else { Image(systemName: systemImage).font(.title2).foregroundStyle(.secondary) }
                    Text(titleKey).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.padding()
            }
            .accessibilityElement(children: .combine)
    }
}

/// CG-01-P2-5: the author's fill note, under a word puzzle.
@MainActor struct PlayKitHowToButton: View {
    let text: String
    var identifier = "playkit.hangman.howTo"
    @State private var open = false
    var body: some View {
        Button { open = true } label: { Label("playkit.hangman.howTo", systemImage: "questionmark.circle") }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(identifier)
            .sheet(isPresented: $open) {
                NavigationStack {
                    ScrollView {
                        Text(verbatim: text).font(.body).frame(maxWidth: .infinity, alignment: .leading).padding()
                            .accessibilityIdentifier(identifier + ".text")
                    }
                    .navigationTitle(Text("playkit.hangman.howTo"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("playkit.close") { open = false } } }
                }
                .presentationDetents([.medium, .large])
            }
    }
}

/// Reference picture. Alt text is the accessibility label. Retry remounts the load.
@MainActor struct PlayKitReferenceButton: View {
    let source: String
    var alt: String? = nil
    var approvedHosts: Set<String> = []
    var nodeID: Int? = nil
    var kit: String? = nil
    @State private var open = false
    var body: some View {
        Button { open = true } label: { Label("playkit.reference.open", systemImage: "photo") }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("playkit.reference.open")
            .sheet(isPresented: $open) {
                PlayKitReferenceSheet(source: source, alt: alt, approvedHosts: approvedHosts, nodeID: nodeID, kit: kit)
            }
    }
}

@MainActor private struct PlayKitReferenceSheet: View {
    let source: String
    let alt: String?
    let approvedHosts: Set<String>
    let nodeID: Int?
    let kit: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analyticsEventClient) private var analytics
    var body: some View {
        NavigationStack {
            ScrollView {
                PlayKitArtwork(source: source, approvedHosts: approvedHosts, alt: alt)
                    .padding()
                    .accessibilityIdentifier("playkit.reference.image")
            }
            .navigationTitle(Text("playkit.reference.open"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("playkit.close") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
        .onAppear { PlayStageAnalytics.track(analytics, .materialView, nodeID: nodeID, kit: kit) }
    }
}

/// Issue categories. Hidden while the stage-analytics gate is off, so a closed gate is not a dead button.
@MainActor struct PlayKitIssueReportMenu: View {
    var nodeID: Int? = nil
    var kit: String? = nil
    @Environment(\.analyticsEventClient) private var analytics
    var body: some View {
        if PlayStageAnalyticsGate.enabled {
            Menu("playkit.issue.open") {
                ForEach(PlayStageIssueKind.allCases, id: \.self) { kind in
                    Button(LocalizedStringKey(kind.labelKey)) {
                        PlayStageAnalytics.track(analytics, .stageIssueReport, nodeID: nodeID, kit: kit, issueKind: kind)
                    }
                }
            }
            .accessibilityIdentifier("playkit.issue.open")
        }
    }
}

/// Read-only pairs already chosen, drawn above the match pickers.
@MainActor struct PlayGameMatchDiagram: View {
    let lines: [PlayGameMatchLine]
    let left: [String]
    let right: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines, id: \.self) { line in
                if left.indices.contains(line.left), right.indices.contains(line.right) {
                    Text(verbatim: left[line.left] + " — " + right[line.right]).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("playkit.match.lines")
    }
}
