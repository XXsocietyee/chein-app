import SwiftUI

// Native r2 games, template C (design backlog P1 · L6 G-001 / G-002 / G-003).
// The five kinds that still fell back to the legacy forms (true/false, image guess, jigsaw,
// scratch card, compare) and the UG-03 accusation now draw inside `NativeGameShell`.
// Same write paths and payloads as `PlayKitNewGameForms`, `PlayCompareView` and
// `PlayKitAccusationView` (SUBMIT_TRUE_FALSE, SUBMIT_IMAGE_GUESS, SUBMIT_JIGSAW,
// SUBMIT_SCRATCH_CARD, SUBMIT_COMPARE, SUBMIT_QA accusation); only the drawing changes.
// Apple references: Settings selection lists (true/false, compare), Photos grid (jigsaw),
// Wallet pass reveal (scratch), Contacts card + confirmation dialog (accusation).
enum NativeGameKitsC {
    static let kinds: Set<PlayKitScreenKind> = [.trueFalse, .imageGuess, .jigsaw, .scratchCard, .compare]
}

extension PlayKitScreen {
    // MARK: Dispatch (NativeGameScreenHost.nativeControls routes these kinds here)

    @ViewBuilder var nativeControlsC: some View {
        switch kind {
        case .trueFalse: nativeTrueFalse
        case .imageGuess: nativeImageGuess
        case .jigsaw:
            NativeGameJigsawKit(segment: raw, approvedHosts: approvedArtworkHosts, enabled: enabled,
                busy: model.phase == "submitting", onDirty: { dirty = true }, requestReview: nativePrepare,
                publish: { nativeChildSubmit = $0 })
                .id(runtimeIdentity)
        case .scratchCard:
            NativeGameScratchKit(segment: raw, revealed: projection.complete, enabled: enabled,
                busy: model.phase == "submitting", approvedHosts: approvedArtworkHosts, requestReview: nativePrepare,
                publish: { nativeChildSubmit = $0 })
                .id(runtimeIdentity)
        case .compare:
            NativeGameCompareKit(segment: raw, revision: runtimeIdentity, enabled: enabled,
                busy: model.phase == "submitting", currentRevision: { runtimeIdentity },
                onDirty: { dirty = true }, requestReview: nativePrepare,
                publish: { nativeChildSubmit = $0 })
                .id(childReset)
        default: EmptyView()
        }
    }

    /// Bottom-bar action for the template C kits whose draft lives on the screen.
    var nativeKitSubmitC: NativeGameSubmit? {
        guard !projection.complete else { return nil }
        switch kind {
        case .trueFalse:
            return nativeSubmit("SUBMIT_TRUE_FALSE", ["answer": .bool(selected.contains("true"))],
                                valid: selected.contains("true") || selected.contains("false"))
        case .imageGuess:
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return nativeSubmit("SUBMIT_IMAGE_GUESS", ["guess": .string(trimmed)], valid: !trimmed.isEmpty)
        default:
            return nil
        }
    }

    // MARK: true / false (Settings-style two-row selection)

    @ViewBuilder var nativeTrueFalse: some View {
        if let image = raw["imageUrl"].text, !image.isEmpty {
            Section { PlayKitArtwork(source: image, approvedHosts: approvedArtworkHosts).frame(maxWidth: .infinity) }
        }
        Section {
            nativeTrueFalseRow(id: "true", key: "playkit.trueFalse.true", systemImage: "checkmark.circle")
            nativeTrueFalseRow(id: "false", key: "playkit.trueFalse.false", systemImage: "xmark.circle")
        }
        .sensoryFeedback(.selection, trigger: selected)
        if projection.complete, let explanation = raw["explanation"].text, !explanation.isEmpty {
            Section {
                Text(verbatim: explanation).fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("playkit.trueFalse.explanation")
            }
            .accessibilityIdentifier("playkit.trueFalse.explanation")
        }
    }

    private func nativeTrueFalseRow(id: String, key: String, systemImage: String) -> some View {
        let on = selected.contains(id)
        return Button {
            selected = [id]
            dirty = true
        } label: {
            HStack {
                Label(LocalizedStringKey(key), systemImage: systemImage).foregroundStyle(.primary)
                Spacer(minLength: 0)
                if on { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint).accessibilityHidden(true) }
            }
            .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playkit.trueFalse." + id)
    }

    // MARK: image guess (picture, reveal gauge, clue list, one text field)

    @ViewBuilder var nativeImageGuess: some View {
        let revealPercent = max(0, min(100, raw["revealPercent"].integer ?? (projection.complete ? 100 : 35)))
        let revealLevel = raw["revealLevel"].integer ?? 0
        let totalClues = raw["totalClues"].integer ?? 0
        // The blur is the game itself (the picture clears as clues are revealed), not decoration.
        let blurRadius: CGFloat = projection.complete ? 0 : CGFloat(max(0, 100 - revealPercent)) * 0.16
        Section {
            PlayKitArtwork(source: raw["imageUrl"].text, approvedHosts: approvedArtworkHosts)
                .blur(radius: blurRadius)
                .clipped()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("playkit.imageGuess.artworkLabel"))
                .accessibilityIdentifier("playkit.imageGuess.artwork")
            ProgressView(value: Double(revealPercent), total: 100) {
                Text(verbatim: appLocalized("playkit.imageGuess.revealPct \(revealPercent)", locale: .current))
                    .contentTransition(.numericText())
            }
            .accessibilityIdentifier("playkit.imageGuess.revealPct")
            if totalClues > 0 {
                Text("playkit.imageGuess.cluesCount \(revealLevel) \(totalClues)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("playkit.imageGuess.cluesCount")
            }
        }
        let clues = (raw["revealedClues"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !clues.isEmpty || (totalClues > revealLevel && enabled) {
            Section {
                ForEach(Array(clues.enumerated()), id: \.offset) { index, clue in
                    Label {
                        Text(verbatim: clue).fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "\(min(index + 1, 50)).circle")
                    }
                }
                if totalClues > revealLevel && enabled {
                    Button {
                        prepare("SUBMIT_IMAGE_GUESS", ["action": .string("REVEAL_STEP")])
                    } label: {
                        Label("playkit.imageGuess.revealNext", systemImage: "eye")
                    }
                    .accessibilityIdentifier("playkit.imageGuess.revealNext")
                }
            } header: {
                Text("nativeGames.imageGuess.clues")
            }
            .accessibilityIdentifier("playkit.imageGuess.clues")
        }
        if !projection.complete {
            Section {
                TextField("playkit.imageGuess.guessPlaceholder", text: textBinding(limit: 200))
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .onSubmit {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard enabled, !trimmed.isEmpty else { return }
                        nativePrepare("SUBMIT_IMAGE_GUESS", ["guess": .string(trimmed)])
                    }
                    .disabled(!enabled)
                    .accessibilityIdentifier("playkit.imageGuess.input")
            }
        } else if let answer = raw["answer"].text, !answer.isEmpty {
            Section {
                LabeledContent {
                    Text(verbatim: answer)
                } label: {
                    Text("playkit.qa.revealedAnswer")
                }
                .accessibilityIdentifier("playkit.imageGuess.answer")
            }
        }
    }

    // MARK: UG-03 accusation (G-002: inside the shell instead of its own full-screen layout)

    @ViewBuilder var nativeAccusation: some View {
        if let accusation = accusationProjection {
            NativeGameAccusationKit(projection: accusation, approvedHosts: approvedArtworkHosts, enabled: enabled,
                busy: model.phase == "submitting", accuse: accusationWrite,
                close: presentation == .inline ? nil : { dismiss() },
                publish: { nativeChildSubmit = $0 })
        }
    }
}

// MARK: - Jigsaw (tap two tiles to swap; Photos-style grid)

@MainActor struct NativeGameJigsawKit: View {
    let segment: PlayWireValue
    let approvedHosts: Set<String>
    let enabled: Bool
    let busy: Bool
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest
    let publish: (NativeGameSubmit?) -> Void
    @State private var order: [Int] = []
    @State private var pickedIndex: Int?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: Int { max(2, min(4, segment["rows"].integer ?? 2)) }
    private var cols: Int { max(2, min(4, segment["cols"].integer ?? 2)) }
    private var total: Int { rows * cols }
    private var serverOrder: [Int] {
        let incoming = (segment["order"].array ?? []).compactMap(\.integer)
        if incoming.count == total && Set(incoming) == Set(0..<total) { return incoming }
        return Array(0..<total)
    }
    private var isValidOrder: Bool { order.count == total && Set(order) == Set(0..<total) }
    private var solved: Bool { segment["solved"].bool == true }
    private var publishKey: String { "\(enabled)|\(busy)|\(isValidOrder)|\(solved)" }

    var body: some View {
        Section {
            Text("playkit.jigsaw.instructions").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: cols), spacing: 4) {
                ForEach(Array(order.enumerated()), id: \.element) { position, piece in
                    tile(piece: piece, position: position)
                }
            }
            .padding(.vertical, 4)
            .accessibilityIdentifier("playkit.jigsaw.grid")
            if let moves = segment["moves"].integer, moves > 0 {
                LabeledContent {
                    Text(verbatim: String(moves)).monospacedDigit().contentTransition(.numericText())
                } label: {
                    Text("playkit.attempts")
                }
            }
        }
        .sensoryFeedback(.selection, trigger: pickedIndex)
        .sensoryFeedback(.impact(weight: .light), trigger: order)
        .sensoryFeedback(.success, trigger: solved) { old, next in !old && next }
        .onAppear { if order.isEmpty { order = serverOrder } }
        .onChange(of: serverOrder) { _, incoming in order = incoming; pickedIndex = nil }
        .onChange(of: publishKey, initial: true) { _, _ in publish(primaryAction) }
    }

    private func tile(piece: Int, position: Int) -> some View {
        let picked = pickedIndex == position
        return Button { tap(position) } label: {
            tileArtwork(piece: piece)
                .frame(maxWidth: .infinity, minHeight: 72)
                .background(.fill.tertiary)
                .overlay(alignment: .topLeading) {
                    Text(verbatim: "\(piece + 1)")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.background, in: Capsule())
                        .padding(4)
                        .accessibilityHidden(true)
                }
                .overlay {
                    if picked { Rectangle().strokeBorder(.tint, lineWidth: 3).accessibilityHidden(true) }
                }
                .clipped()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text("playkit.jigsaw.tileLabel \(piece + 1) \(position + 1)"))
        .accessibilityAddTraits(picked ? .isSelected : [])
        .accessibilityIdentifier("playkit.jigsaw.tile.\(position)")
    }

    @ViewBuilder private func tileArtwork(piece: Int) -> some View {
        if let url = segment["imageUrl"].text, !url.isEmpty {
            let srcRow = piece / cols
            let srcCol = piece % cols
            GeometryReader { proxy in
                PlayKitArtwork(source: url, approvedHosts: approvedHosts)
                    .frame(width: proxy.size.width * CGFloat(cols), height: proxy.size.height * CGFloat(rows))
                    .offset(x: -CGFloat(srcCol) * proxy.size.width, y: -CGFloat(srcRow) * proxy.size.height)
            }
            .clipped()
        } else {
            Text(verbatim: "\(piece + 1)").font(.title2.monospacedDigit()).foregroundStyle(.secondary)
        }
    }

    private func tap(_ index: Int) {
        guard enabled, order.indices.contains(index) else { return }
        if let first = pickedIndex, first != index, order.indices.contains(first) {
            withAnimation(reduceMotion ? nil : .snappy) { order.swapAt(first, index) }
            pickedIndex = nil
            onDirty()
        } else {
            pickedIndex = pickedIndex == index ? nil : index
        }
    }

    private var primaryAction: NativeGameSubmit? {
        guard !solved else { return nil }
        let submitted = order
        return NativeGameSubmit(title: Text("playkit.jigsaw.submit"), enabled: enabled && isValidOrder, busy: busy,
                                identifier: "playkit.submit.jigsaw",
                                action: { requestReview("SUBMIT_JIGSAW", ["order": .array(submitted.map(PlayWireValue.int))], {}) })
    }
}

// MARK: - Scratch card (Wallet-style reveal; the bottom bar reveals without scratching)

@MainActor struct NativeGameScratchKit: View {
    let segment: PlayWireValue
    let revealed: Bool
    let enabled: Bool
    let busy: Bool
    let approvedHosts: Set<String>
    let requestReview: PlayKitReviewRequest
    let publish: (NativeGameSubmit?) -> Void
    @State private var tracker: CYScratchProgressTracker
    @State private var lastDragPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(segment: PlayWireValue, revealed: Bool, enabled: Bool, busy: Bool, approvedHosts: Set<String>,
         requestReview: @escaping PlayKitReviewRequest, publish: @escaping (NativeGameSubmit?) -> Void) {
        self.segment = segment; self.revealed = revealed; self.enabled = enabled; self.busy = busy
        self.approvedHosts = approvedHosts; self.requestReview = requestReview; self.publish = publish
        _tracker = State(initialValue: CYScratchProgressTracker(threshold: CYScratchProgressTracker.clampThreshold(segment["threshold"].double)))
    }

    private var threshold: Double { CYScratchProgressTracker.clampThreshold(segment["threshold"].double) }
    private var isRevealed: Bool { revealed || tracker.revealed }
    private var coverLabel: String? { segment["coverLabel"].text.flatMap { $0.isEmpty ? nil : $0 } }
    private var publishKey: String { "\(enabled)|\(busy)|\(isRevealed)" }

    var body: some View {
        Section {
            ZStack {
                prize
                    .frame(maxWidth: .infinity, minHeight: 140)
                if !isRevealed {
                    cover.transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .smooth, value: isRevealed)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(isRevealed ? Text("playkit.scratch.revealedPlaceholder")
                                : Text(verbatim: coverLabel ?? appLocalized("playkit.scratch.coverPrompt", locale: .current)))
            .accessibilityIdentifier("playkit.scratchCard.surface")
        }
        .sensoryFeedback(.success, trigger: isRevealed) { old, next in !old && next }
        // Motion r2 R3: a selection tick per quarter scratched.
        .sensoryFeedback(.selection, trigger: Int(tracker.progress * 4)) { old, next in NativeR2Flags.motion2 && next > old }
        .onChange(of: publishKey, initial: true) { _, _ in publish(primaryAction) }
    }

    @ViewBuilder private var prize: some View {
        VStack(spacing: 8) {
            if let prizeText = segment["prizeText"].text, !prizeText.isEmpty {
                Text(verbatim: prizeText).font(.title3.bold()).multilineTextAlignment(.center)
                    .accessibilityIdentifier("playkit.scratchCard.prize")
            } else {
                Text("playkit.scratch.revealedPlaceholder").foregroundStyle(.secondary)
                    .accessibilityIdentifier("playkit.scratchCard.placeholder")
            }
            if let url = segment["revealImageUrl"].text, !url.isEmpty {
                PlayKitArtwork(source: url, approvedHosts: approvedHosts)
            }
        }
        .motionR2HoloSheen(active: isRevealed, cornerRadius: 12) // motion r2 R2: the prize shines once revealed
        .accessibilityHidden(!isRevealed)
    }

    private var cover: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray))
                context.blendMode = .destinationOut
                let scaleX = size.width / max(1, tracker.width)
                let scaleY = size.height / max(1, tracker.height)
                for stroke in tracker.segments {
                    var path = Path()
                    path.move(to: CGPoint(x: stroke.from.x * scaleX, y: stroke.from.y * scaleY))
                    path.addLine(to: CGPoint(x: stroke.to.x * scaleX, y: stroke.to.y * scaleY))
                    context.stroke(path, with: .color(.black),
                                   style: StrokeStyle(lineWidth: stroke.radius * 2 * max(scaleX, scaleY), lineCap: .round, lineJoin: .round))
                }
            }
            .compositingGroup()
            .overlay {
                Label {
                    Text(verbatim: coverLabel ?? appLocalized("playkit.scratch.coverPrompt", locale: .current))
                } icon: {
                    Image(systemName: "hand.draw")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .opacity(tracker.progress > 0.25 ? 0.35 : 1)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard enabled else { return }
                        let from = lastDragPoint ?? value.startLocation
                        lastDragPoint = value.location
                        let scaleX = tracker.width / max(1, proxy.size.width)
                        let scaleY = tracker.height / max(1, proxy.size.height)
                        let p1 = CYScratchProgressTracker.Point(x: from.x * scaleX, y: from.y * scaleY)
                        let p2 = CYScratchProgressTracker.Point(x: value.location.x * scaleX, y: value.location.y * scaleY)
                        if tracker.stamp(from: p1, to: p2, radius: 22) {
                            requestReview("SUBMIT_SCRATCH_CARD", ["progress": .number(max(threshold, tracker.progress))], {})
                        }
                    }
                    .onEnded { _ in lastDragPoint = nil }
            )
        }
        .frame(minHeight: 140)
        .accessibilityHidden(true)
    }

    private var primaryAction: NativeGameSubmit? {
        guard !isRevealed else { return nil }
        return NativeGameSubmit(title: Text("playkit.scratch.revealDirect"), enabled: enabled, busy: busy,
                                identifier: "playkit.scratchCard.revealDirect",
                                action: {
                                    if tracker.revealAll() {
                                        requestReview("SUBMIT_SCRATCH_CARD", ["progress": .number(1.0)], {})
                                    }
                                })
    }
}

// MARK: - Compare (two timelines as Settings-style selection lists)

@MainActor struct NativeGameCompareKit: View {
    let segment: PlayWireValue
    let revision: String
    let enabled: Bool
    let busy: Bool
    let currentRevision: () -> String
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest
    let publish: (NativeGameSubmit?) -> Void
    @State private var selection = PlayCompareSelection()
    @State private var confirmReload = false
    @State private var issue: PlayExperienceError?

    private var question: PlayCompareQuestion? { try? PlayCompareQuestion(segment) }
    private var stale: Bool { selection.revision != revision }
    private var publishKey: String { "\(enabled)|\(busy)|\(stale)|\(question?.finished ?? true)|\(selection.marked.count)" }

    var body: some View {
        Group {
            if let question {
                statusSection(question)
                side(question.left, question: question)
                side(question.right, question: question)
            } else {
                Section { Text("playkit.compare.invalid") }
            }
        }
        .onAppear { if selection.revision == nil, let question { selection.restore(question, revision: revision) } }
        .onChange(of: publishKey, initial: true) { _, _ in publish(primaryAction) }
        .sensoryFeedback(.selection, trigger: selection.marked)
        .confirmationDialog(Text("playkit.compare.reloadQuestion"), isPresented: $confirmReload, titleVisibility: .visible) {
            Button("playkit.compare.reload", role: .destructive) {
                if let question { selection.restore(question, revision: revision); issue = nil }
            }
            .accessibilityIdentifier("playkit.compare.reload.confirm")
            Button("playkit.cancel", role: .cancel) {}
        }
    }

    @ViewBuilder private func statusSection(_ question: PlayCompareQuestion) -> some View {
        Section {
            Text("playkit.compare.instructions").foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let remaining = question.remainingAttempts {
                LabeledContent {
                    Text(verbatim: String(remaining)).monospacedDigit().contentTransition(.numericText())
                } label: { Text("playkit.compare.remaining") }
            } else {
                Text("playkit.compare.unlimited").foregroundStyle(.secondary)
            }
            LabeledContent {
                Text(verbatim: String(question.attempts)).monospacedDigit().contentTransition(.numericText())
            } label: { Text("playkit.compare.attempts") }
            if question.attempts > 0 {
                Label(question.lastCorrect ? LocalizedStringKey("playkit.compare.correct") : LocalizedStringKey("playkit.compare.incorrect"),
                      systemImage: question.lastCorrect ? "checkmark.circle" : "xmark.circle")
                    .foregroundStyle(question.lastCorrect ? Color.green : Color.red)
                    .accessibilityIdentifier("playkit.compare.receipt")
            }
            if !question.finished {
                LabeledContent {
                    Text(verbatim: String(selection.marked.count)).monospacedDigit().contentTransition(.numericText())
                } label: { Text("playkit.compare.marked") }
            }
            if let issue {
                Label { PlayExperienceIssueView(issue: issue) } icon: { Image(systemName: "exclamationmark.triangle") }
            }
        } footer: {
            if !question.finished && stale {
                VStack(alignment: .leading, spacing: 8) {
                    Text("playkit.compare.changed")
                    Button("playkit.compare.reload") { confirmReload = true }
                        .disabled(!enabled)
                        .accessibilityIdentifier("playkit.compare.reload")
                }
            }
        }
    }

    private func side(_ side: PlayCompareQuestion.Side, question: PlayCompareQuestion) -> some View {
        Section {
            ForEach(side.items) { item in
                let on = selection.marked.contains(item.id)
                Button {
                    selection.toggle(item.id, question: question, revision: currentRevision())
                    onDirty()
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: item.time).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                            Text(verbatim: item.text).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if on { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint).accessibilityHidden(true) }
                    }
                    .contentShape(Rectangle())
                }
                .disabled(!enabled || stale || question.finished)
                .accessibilityLabel(Text(verbatim: side.label + ", " + item.time + ", " + item.text))
                .accessibilityValue(Text(on ? LocalizedStringKey("playkit.compare.selected") : LocalizedStringKey("playkit.compare.unselected")))
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityIdentifier("playkit.compare.item." + item.id)
            }
        } header: {
            Text(verbatim: side.label)
        }
    }

    private var primaryAction: NativeGameSubmit? {
        guard let question, !question.finished else { return nil }
        return NativeGameSubmit(title: Text("playkit.compare.submit"), enabled: enabled && !stale, busy: busy,
                                identifier: "playkit.submit.compare",
                                action: {
                                    do {
                                        let payload = try selection.payload(question, revision: currentRevision())
                                        requestReview("SUBMIT_COMPARE", payload, {})
                                        issue = nil
                                    } catch { issue = error as? PlayExperienceError ?? .invalidAction }
                                })
    }
}

// MARK: - Accusation (clue board, one suspect at a time, accuse with a confirmation dialog)

@MainActor struct NativeGameAccusationKit: View {
    let projection: PlayKitAccusationProjection
    let approvedHosts: Set<String>
    let enabled: Bool
    let busy: Bool
    let accuse: PlayKitAccusationWrite?
    let close: (() -> Void)?
    let publish: (NativeGameSubmit?) -> Void
    @State private var current = 0
    @State private var confirmOpen = false
    @State private var openClue: PlayKitAccusationProjection.Clue?
    @State private var unavailable = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var suspect: PlayKitAccusationProjection.Suspect? {
        projection.suspects.indices.contains(current) ? projection.suspects[current] : nil
    }
    private var publishKey: String {
        "\(enabled)|\(busy)|\(current)|\(projection.showsEnding)|\(projection.pending)|\(projection.suspects.count)"
    }
    private var won: Bool { projection.outcome == .solved || projection.outcome == .early }

    var body: some View {
        Group {
            if projection.showsEnding { ending } else { investigation }
        }
        .onChange(of: projection.suspects.count) { _, count in current = min(current, max(0, count - 1)) }
        .onChange(of: publishKey, initial: true) { _, _ in publish(primaryAction) }
        .sensoryFeedback(.error, trigger: projection.wrongAttempt) { old, next in !old && next }
        .sensoryFeedback(.success, trigger: won) { old, next in !old && next }
        .confirmationDialog(confirmTitle, isPresented: $confirmOpen, titleVisibility: .visible, presenting: suspect) { target in
            Button("playkit.accusation.confirm", role: .destructive) {
                guard let accuse else {
                    unavailable = true
                    IslandCenter.shared.status(.key("playkit.questo.unavailable"), tone: .warning)
                    return
                }
                accuse(target.id)
            }
            .accessibilityIdentifier("playkit.accusation.confirm")
            Button("playkit.accusation.thinkAgain", role: .cancel) {}
                .accessibilityIdentifier("playkit.accusation.cancel")
        } message: { target in
            Text(verbatim: (target.identity.isEmpty ? "" : target.identity + " · ") + appLocalized("playkit.accusation.final", locale: locale))
        }
        .cySheet(item: $openClue) { clue in clueSheet(clue) }
    }

    private var confirmTitle: Text {
        let name = (suspect?.name).flatMap { $0.isEmpty ? nil : $0 } ?? appLocalized("playkit.accusation.someone", locale: locale)
        return Text(verbatim: appLocalized("playkit.accusation.confirmTitle \(name)", locale: locale))
    }

    // MARK: Investigation

    @ViewBuilder private var investigation: some View {
        if projection.boardImage != nil || !projection.clues.isEmpty {
            Section {
                if let image = projection.boardImage {
                    PlayKitArtwork(source: image, approvedHosts: approvedHosts)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(projection.boardAlt.isEmpty ? Text("playkit.accusation.board") : Text(verbatim: projection.boardAlt))
                }
                ForEach(Array(projection.clues.enumerated()), id: \.element.id) { index, clue in
                    let name = clue.name.isEmpty ? appLocalized("playkit.accusation.clue", locale: locale) : clue.name
                    Button { openClue = clue } label: {
                        Label(name, systemImage: "pin")
                    }
                    .accessibilityLabel(Text("playkit.accusation.clueLabel \(name)"))
                    .accessibilityIdentifier("playkit.accusation.clue.\(index)")
                }
            } header: {
                Text("playkit.accusation.board")
            }
            .accessibilityIdentifier("playkit.accusation.board")
        }
        let introTexts: [String] = projection.intro.compactMap { block in
            if case .text(let value) = block { return value }
            return nil
        }
        if !introTexts.isEmpty {
            Section {
                ForEach(Array(introTexts.enumerated()), id: \.offset) { _, value in
                    Text(verbatim: value).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if projection.wrongAttempt {
            Section {
                Label {
                    Text(verbatim: projection.retryNote.isEmpty ? appLocalized("playkit.accusation.wrong", locale: locale) : projection.retryNote)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "xmark.circle")
                }
                .foregroundStyle(.red)
                .accessibilityIdentifier("playkit.accusation.wrong")
            }
        }
        if unavailable {
            Section {
                Label("playkit.questo.unavailable", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("playkit.accusation.unavailable")
            }
        }
        if let suspect {
            Section {
                suspectCard(suspect)
                    .id(suspect.id)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.push(from: .trailing))
                if projection.suspects.count > 1 {
                    Button(action: next) {
                        Label("playkit.accusation.next", systemImage: "chevron.right")
                    }
                    .accessibilityIdentifier("playkit.accusation.next")
                }
            } header: {
                Text("playkit.accusation.position \(current + 1) \(projection.suspects.count)")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .accessibilityIdentifier("playkit.accusation.deck")
        }
    }

    private func suspectCard(_ suspect: PlayKitAccusationProjection.Suspect) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let avatar = suspect.avatar {
                PlayKitArtwork(source: avatar, approvedHosts: approvedHosts)
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .accessibilityHidden(true)
            }
            LabeledContent {
                EmptyView()
            } label: {
                Text(verbatim: suspect.name).font(.headline)
                if !suspect.identity.isEmpty { Text(verbatim: suspect.identity) }
            }
            ForEach(Array(suspect.testimony.enumerated()), id: \.offset) { _, line in
                Label {
                    Text(verbatim: appQuoted(line, locale: locale)).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "quote.opening")
                }
                .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: suspect.identity.isEmpty ? suspect.name : appJoinedPair(suspect.name, suspect.identity, locale: locale)))
        .accessibilityValue(Text("playkit.accusation.position \(current + 1) \(projection.suspects.count)"))
    }

    private func next() {
        let count = projection.suspects.count
        guard count > 1, !confirmOpen else { return }
        withAnimation(reduceMotion ? nil : .smooth) { current = (current + 1) % count }
    }

    private func clueSheet(_ clue: PlayKitAccusationProjection.Clue) -> some View {
        NavigationStack {
            List {
                if let image = clue.image {
                    Section { PlayKitArtwork(source: image, approvedHosts: approvedHosts).frame(maxWidth: .infinity).accessibilityHidden(true) }
                }
                if !clue.text.isEmpty {
                    Section { Text(verbatim: clue.text).fixedSize(horizontal: false, vertical: true) }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text(verbatim: clue.name.isEmpty ? appLocalized("playkit.accusation.clue", locale: locale) : clue.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("playkit.accusation.collapse") { openClue = nil }
                        .accessibilityIdentifier("playkit.accusation.clueClose")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .accessibilityIdentifier("playkit.accusation.cluePanel")
    }

    // MARK: Ending (reads the server verdict only)

    @ViewBuilder private var ending: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: endingSymbol)
                    .font(.largeTitle)
                    .imageScale(.large)
                    .foregroundStyle(projection.outcome == .failed ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
                    .symbolEffect(.bounce, value: reduceMotion ? nil : projection.outcome)
                    .symbolEffect(.pulse, isActive: projection.pending && !reduceMotion)
                    .accessibilityHidden(true)
                Text(endingLabel).font(.title2.bold()).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("playkit.accusation.verdict")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            ForEach(Array(projection.screen.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let value):
                    Text(verbatim: value).fixedSize(horizontal: false, vertical: true)
                case .image(let url, let alt):
                    PlayKitArtwork(source: url, approvedHosts: approvedHosts)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel(alt.isEmpty ? Text("playkit.accusation.endingImage") : Text(verbatim: alt))
                }
            }
        }
        .accessibilityIdentifier("playkit.accusation.ending")
    }

    private var endingSymbol: String {
        switch projection.outcome {
        case .solved, .early: return "checkmark.seal"
        case .failed: return "xmark.seal"
        default: return "hourglass"
        }
    }

    private var endingLabel: LocalizedStringKey {
        if projection.pending { return "playkit.accusation.pending" }
        switch projection.outcome {
        case .solved: return "playkit.accusation.solved"
        case .early: return "playkit.accusation.early"
        case .failed: return "playkit.accusation.failed"
        default: return "playkit.accusation.pending"
        }
    }

    // MARK: Bottom bar

    private var primaryAction: NativeGameSubmit? {
        if projection.showsEnding {
            guard !projection.pending, let close else { return nil }
            return NativeGameSubmit(title: Text("playkit.hangman.continue"), enabled: true,
                                    identifier: "playkit.accusation.continue", action: close)
        }
        guard let suspect else { return nil }
        let name = suspect.name.isEmpty ? "—" : suspect.name
        return NativeGameSubmit(title: Text(verbatim: appLocalized("playkit.accusation.accuse \(name)", locale: locale)),
                                enabled: enabled, busy: busy, identifier: "playkit.accusation.accuse",
                                action: { unavailable = false; openClue = nil; confirmOpen = true })
    }
}
