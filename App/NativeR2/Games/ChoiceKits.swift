import SwiftUI
import UIKit

// Native r2 games-b, Template 6: Story choice & progress.
// Apple reference: Books reader (text first, choices as plain list rows), Music Now Playing
// (compact play / pause), Fitness Awards grid (bingo). Same actions and payloads as before.

// MARK: - branch

@MainActor struct ChoiceBranchKit: View {
    let context: GamesBKitContext
    var cast: CastStoryContext? = nil
    @State private var confirming = false
    private var raw: PlayWireValue { context.segment }
    private var pick: Binding<String> {
        Binding(get: { context.selection.wrappedValue.first ?? "" },
                set: { context.selection.wrappedValue = $0.isEmpty ? [] : [$0]; context.markDirty() })
    }
    private var picked: PlayKitOption? { context.projection.options.first { $0.id == pick.wrappedValue } }
    private static func subtitle(_ option: PlayKitOption) -> String? {
        for key in ["desc", "subtitle", "hint", "sub"] {
            if let text = option.raw[key].text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        }
        return nil
    }
    var body: some View {
        Section {
            if let echo = CastBranchEcho(branch: raw) {
                CastBranchEchoLabel(echo: echo, config: cast?.config)
            }
            if let title = raw["currentStep"]["title"].text {
                Text(verbatim: title).font(.headline).accessibilityAddTraits(.isHeader)
            }
            if let body = raw["currentStep"]["body"].text {
                Text(verbatim: body).font(.body)
            }
        }
        let options = context.projection.options
        if options.isEmpty, !context.projection.complete {
            ContentUnavailableView("playkit.branch.waiting", systemImage: "arrow.triangle.branch")
                .accessibilityIdentifier("playkit.branch.waiting")
        }
        if !options.isEmpty {
            Section {
                Picker(selection: pick) {
                    ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: "\(index + 1) · \(option.label)")
                            if let sub = Self.subtitle(option) {
                                Text(verbatim: sub).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("playkit.branch.option." + option.id)
                        .tag(option.id)
                    }
                } label: {
                    Text("nativeR2.gamesB.branch.choose")
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(!context.enabled)
            } footer: {
                Text("nativeR2.gamesB.branch.noWrong")
            }
            Section {
                Button {
                    confirming = true
                } label: {
                    Text("nativeR2.gamesB.branch.confirm").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!context.enabled || picked == nil)
                .accessibilityIdentifier("playkit.submit.branch")
            }
            .confirmationDialog("nativeR2.gamesB.branch.confirmTitle", isPresented: $confirming, titleVisibility: .visible) {
                Button("nativeR2.gamesB.branch.confirm") {
                    guard let option = picked else { return }
                    context.submit("CHOOSE", ["optionId": .string(option.id)])
                }
                Button("playkit.cancel", role: .cancel) {}
            } message: {
                Text(verbatim: picked?.label ?? "")
            }
        }
        if context.projection.complete {
            Section { Label("playkit.branch.ended", systemImage: "book.closed") }
        }
    }
}

// MARK: - musiccorner

@MainActor struct ChoiceMusicCornerKit: View {
    let context: GamesBKitContext
    let mediaScope: UUID
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    private var raw: PlayWireValue { context.segment }
    var body: some View {
        Section {
            if raw["arrived"].bool == true {
                Label("playkitLegacy.music.arrived", systemImage: "mappin")
                    .accessibilityIdentifier("playkit.musicCorner.arrived")
            }
            if let track = raw["trackName"].text {
                LabeledContent {
                    if let seconds = raw["durationSeconds"].integer, seconds > 0 {
                        Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60)).monospacedDigit()
                            .accessibilityLabel(Text("playkitLegacy.music.duration"))
                    }
                } label: {
                    Label { Text(verbatim: track).font(.headline) } icon: { Image(systemName: "music.note") }
                }
            } else if let seconds = raw["durationSeconds"].integer, seconds > 0 {
                LabeledContent("playkitLegacy.music.duration") {
                    Text(verbatim: String(format: "%d:%02d", seconds / 60, seconds % 60)).monospacedDigit()
                }
            }
            // Existing playback code (play / pause, progress, load failure + retry).
            PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
        }
    }
}

// MARK: - dailysign

@MainActor struct ChoiceDailySignKit: View {
    let context: GamesBKitContext
    /// `PlayKitScreen.avatarURL`, sent as `photoUrl` exactly as before.
    var photoURL: String = ""
    @State private var revealed = false
    @State private var shareImage: Image?
    @Environment(\.displayScale) private var displayScale
    private var raw: PlayWireValue { context.segment }
    private var lines: [String] { (raw["lines"].array ?? []).compactMap(\.text).filter { !$0.isEmpty } }
    private func value(_ key: String) -> String {
        let text = (raw[key].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "—" : text
    }
    private var isRevealed: Bool { revealed || lines.isEmpty }
    var body: some View {
        Section {
            GroupBox {
                ticketRows
            } label: {
                Label("playkit.daily.ticketTitle", systemImage: "ticket")
            }
            .accessibilityIdentifier("playkit.dailySign.ticket")
        }
        Section {
            if isRevealed {
                if lines.isEmpty { Text(verbatim: "—") }
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).font(.body).transition(.opacity)
                }
            } else {
                Button {
                    withAnimation { revealed = true }
                } label: {
                    Label("nativeR2.gamesB.daily.reveal", systemImage: "eye")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("nativeR2.gamesB.daily.reveal")
            }
        } header: {
            Text("playkit.daily.lineForYou")
        }
        .sensoryFeedback(.success, trigger: revealed) { _, next in next }
        if let photo = raw["photoUrl"].text, !photo.isEmpty {
            Section { PlayKitArtwork(source: photo, approvedHosts: context.approvedHosts) }
        }
        // Kept (owner question 3 is open): the message the app already sends with CLAIM_DAILY_SIGN.
        Section {
            TextField("playkit.daily.message", text: context.text, axis: .vertical)
                .lineLimit(1...4)
                .submitLabel(.done)
                .disabled(!context.enabled)
        } footer: {
            Text("playkit.daily.audience")
        }
        Section {
            Button {
                context.submit("CLAIM_DAILY_SIGN", ["text": .string(context.text.wrappedValue), "photoUrl": .string(photoURL)])
            } label: {
                Text("nativeR2.gamesB.daily.accept").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!context.enabled || context.text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("playkit.submit.dailySign")
            if isRevealed, let rendered = shareImage {
                ShareLink(item: rendered, preview: SharePreview(Text("playkit.daily.ticketTitle"), image: rendered)) {
                    Label("nativeR2.gamesB.daily.save", systemImage: "square.and.arrow.down")
                }
                .accessibilityIdentifier("nativeR2.gamesB.daily.save")
            }
        }
        .onChange(of: isRevealed, initial: true) { _, next in if next { renderShareImage() } }
    }
    private var ticketRows: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("nativeR2.gamesB.daily.date") { Text(verbatim: value("dateLabel")).monospacedDigit() }
            LabeledContent("playkit.daily.departure") { Text(verbatim: value("address")) }
            LabeledContent("playkit.daily.serial") { Text(verbatim: value("serialLabel")).monospacedDigit() }
            Divider()
            LabeledContent("playkit.daily.signer") { Text(verbatim: value("signer")) }
            LabeledContent("playkit.daily.leftAt") { Text(verbatim: value("leftAt")).monospacedDigit() }
        }
    }
    /// The share sheet's "Save Image" replaces the MP canvas poster; it carries the same ticket text.
    private func renderShareImage() {
        let snapshot = VStack(alignment: .leading, spacing: 12) {
            Text("playkit.daily.ticketTitle").font(.headline)
            ticketRows
            Divider()
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(verbatim: line).font(.body) }
        }
        .padding()
        .frame(width: 360)
        .background(Color(uiColor: .systemBackground))
        let renderer = ImageRenderer(content: snapshot)
        renderer.scale = displayScale
        if let image = renderer.uiImage { shareImage = Image(uiImage: image) }
    }
}

// MARK: - bingo

@MainActor struct ChoiceBingoKit: View {
    let context: GamesBKitContext
    @State private var detail: Int?
    private var raw: PlayWireValue { context.segment }
    var body: some View {
        let board = PlayKitBingoBoard(raw)
        Section {
            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                ForEach(0..<3, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            cell(board, index: row * 3 + column)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            if let line = raw["lineReward"].text, !line.isEmpty {
                Text("playkit.bingo.lineBanner \(line)").accessibilityIdentifier("playkit.bingo.lineBanner")
            }
        } footer: {
            Text("playkit.bingo.footnote")
        }
        Section {
            LabeledContent("playkit.bingo.lines") { Text(verbatim: String(board.completedLines.count)).monospacedDigit() }
            Text("playkit.bingo.filledCount \(board.filled.count)").monospacedDigit().foregroundStyle(.secondary)
                .accessibilityIdentifier("playkit.bingo.filledCount")
            if let full = raw["fullReward"].text, !full.isEmpty { LabeledContent("playkit.bingo.fullReward") { Text(verbatim: full) } }
        }
    }
    private func cell(_ board: PlayKitBingoBoard, index: Int) -> some View {
        let done = board.filled.contains(index)
        return Button {
            detail = index
        } label: {
            Label {
                Text(verbatim: board.title(at: index)).font(.footnote).lineLimit(3).multilineTextAlignment(.center)
            } icon: {
                Image(systemName: done ? "checkmark.seal.fill" : "seal")
            }
            .labelStyle(.titleAndIcon)
            .frame(maxWidth: .infinity, minHeight: 64)
        }
        .buttonStyle(.bordered)
        .tint(done ? Color.accentColor : Color.secondary)
        .accessibilityValue(Text(done ? "playkit.bingo.filled" : "playkit.bingo.empty"))
        .accessibilityIdentifier("playkit.bingo.cell.\(index)")
        .popover(isPresented: Binding(get: { detail == index }, set: { if !$0 { detail = nil } })) {
            NavigationStack {
                List {
                    Section {
                        Label {
                            Text(verbatim: board.title(at: index)).font(.headline)
                        } icon: {
                            Image(systemName: done ? "checkmark.seal.fill" : "seal")
                        }
                        Text(verbatim: board.instruction(at: index))
                        Text(done ? "playkit.bingo.filled" : "playkit.bingo.empty").foregroundStyle(.secondary)
                        if board.linePositions.contains(index) { Label("playkit.bingo.inLine", systemImage: "line.diagonal") }
                    }
                }
                .navigationTitle(Text(verbatim: "\(index + 1)"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("nativeR2.gamesB.bingo.done") { detail = nil } }
                }
            }
            .presentationDetents([.medium])
        }
    }
}
