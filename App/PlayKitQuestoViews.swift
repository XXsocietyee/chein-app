import SwiftUI

/// Write outlet for the UG kits. A nil hangman closure is replaced by the advanced SUBMIT_HANGMAN
/// review. A nil accusation closure is replaced by prepare("SUBMIT_QA") when UG-03 is publishable.
typealias PlayKitHangmanWrite = ([String: PlayWireValue]) -> Void
typealias PlayKitAccusationWrite = (String) -> Void

// MARK: - UG-01 hangman (pages/play/components/playkit-hangman)

/// Cells sit centred above a system-keyboard field. Whatever is typed fills the editable cells
/// in order; tapping a cell focuses the field. The server alone judges the word.
@MainActor struct PlayKitHangmanView: View {
    let projection: PlayKitHangmanProjection
    var enabled = true
    /// Station question and place name fill an empty kit title. Pass text fills empty solved feedback.
    var stationQuestion: String? = nil
    var stationName: String? = nil
    var stationPassText: String? = nil
    var submit: PlayKitHangmanWrite? = nil
    var close: (() -> Void)? = nil
    /// Raw kit segment, for the reference picture. The projection is still the source of the board.
    var segment: PlayWireValue = .null
    var nodeID: Int? = nil
    @State private var text = ""
    @State private var pool: LetterPoolState?
    @State private var typed: [Int: String] = [:]
    @State private var popped: Int?
    @State private var sent = false
    @State private var wrong = false
    @State private var unavailable = false
    @State private var loaded = false
    /// UG-01 whole-word answer: one field for the full word, sent as `{input}`. The cells keep the server state.
    @State private var wholeWord = false
    @State private var word = ""
    @FocusState private var focused: Bool
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.playGameStage) private var stage
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: CYSpacing.xxl) {
            if let stage { PlayGameStageHeader(stage: stage) }
            Spacer(minLength: CYSpacing.xxl)
            if !shownTitle.isEmpty {
                Text(verbatim: shownTitle).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playkit.hangman.title")
            }
            // MP order: 怎么填 (server howto, else the MP default line) and 看不清？查看资料图 sit under the title,
            // above the board, in every input mode while unsolved.
            if !projection.solved {
                VStack(spacing: CYSpacing.sm) {
                    PlayKitHowToButton(text: projection.howTo ?? appLocalized("playkit.hangman.howToDefault", locale: locale))
                    if let source = PlayKitReferenceImage.source(in: segment) {
                        PlayKitReferenceButton(source: source, alt: PlayKitReferenceImage.alt(in: segment), nodeID: nodeID, kit: "hangman")
                    }
                }
            }
            if projection.inputMode != .pool { board }
            if projection.inputMode == .pool, projection.poolMalformed {
                ContentUnavailableView("playkit.configurationInvalid", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("playkit.hangman.invalid")
            } else if projection.inputMode == .pool, !projection.solved {
                poolSection
            } else if !projection.solved && wholeWord {
                TextField("playkit.hangman.wholePlaceholder", text: Binding(get: { word }, set: {
                    word = String(PlayKitHangmanProjection.codePoints($0).prefix(PlayKitHangmanProjection.wholeWordLimit).joined())
                    wrong = false; unavailable = false
                }))
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.done).onSubmit(send)
                    .cyText(.body)
                    .padding(.horizontal, CYSpacing.lg).frame(minHeight: 48)
                    .background(Capsule().fill(CYColor.bgElevated))
                    .overlay(Capsule().strokeBorder(wrong ? CYColor.dangerText : CYColor.borderSubtle))
                    .frame(maxWidth: 320)
                    .disabled(!enabled)
                    .accessibilityLabel(Text("playkit.hangman.wholeField"))
                    .accessibilityIdentifier("playkit.hangman.wholeField")
                wrongLine
                modeSwitch
            } else if !projection.solved {
                TextField("playkit.hangman.placeholder", text: Binding(get: { text }, set: { input($0) }))
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .submitLabel(.done).onSubmit(send)
                    .cyText(.body)
                    .padding(.horizontal, CYSpacing.lg).frame(minHeight: 48)
                    .background(Capsule().fill(CYColor.bgElevated))
                    .overlay(Capsule().strokeBorder(wrong ? CYColor.dangerText : CYColor.borderSubtle))
                    .frame(maxWidth: 280)
                    .disabled(!enabled)
                    .accessibilityLabel(Text("playkit.hangman.field"))
                    .accessibilityIdentifier("playkit.hangman.field")
                wrongLine
                modeSwitch
            } else {
                Text(verbatim: projection.display.isEmpty ? "—" : projection.display)
                    .cyText(.cardTitle).foregroundStyle(CYNight.verify)
                    .accessibilityIdentifier("playkit.hangman.display")
                if !shownFeedback.isEmpty {
                    Text(verbatim: shownFeedback).cyText(.body).foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("playkit.hangman.feedback")
                }
            }
            Spacer(minLength: CYSpacing.xxl)
            if unavailable {
                Text("playkit.questo.unavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center).accessibilityIdentifier("playkit.hangman.unavailable")
            }
            if projection.inputMode != .pool || projection.solved { cta }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            load()
            PlayStageAnalytics.track(analytics, .stageEnter, nodeID: nodeID, kit: "hangman")
        }
        .onChange(of: projection) { _, next in
            if next.inputMode == .pool {
                if let fresh = LetterPoolState(hangman: next) {
                    pool = pool.map { fresh.rebased(keeping: $0) } ?? fresh
                }
                guard sent else { return }
                sent = false
                if !next.solved { wrong = true }
                return
            }
            // Server came back unsolved after this screen sent: the whole guess was wrong, start over.
            guard sent else { return }
            sent = false
            UIKitHapticsDriver.ensureInstalled()
            if !next.solved {
                wrong = true; text = ""; typed = [:]; word = ""
                HapticsService.shared.play(.wrongAnswer)
            } else {
                HapticsService.shared.play(.rewardOrMedal)
            }
        }
        .cyDomainScreen(.game)
    }

    private var shownTitle: String { projection.stationTitle(question: stationQuestion, placeName: stationName) }
    private var shownFeedback: String { projection.stationFeedback(passText: stationPassText) }

    /// MP `wrongFeedback`: the server's `lastFeedback` for an unsolved board, else the default line.
    private var wrongReply: String? {
        guard !projection.solved, let reply = segment["lastFeedback"].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reply.isEmpty else { return nil }
        return reply
    }

    private var wrongLine: some View {
        Group {
            if wrong, let reply = wrongReply { Text(verbatim: reply).accessibilityIdentifier("playkit.hangman.wrong") }
            else if wrong { Text("playkit.hangman.wrong").accessibilityIdentifier("playkit.hangman.wrong") }
            else { Text(verbatim: " ").accessibilityHidden(true) }
        }
        .cyText(.meta).foregroundStyle(CYColor.dangerText)
    }

    /// Cells or the whole word; switching keeps what was typed in each.
    private var modeSwitch: some View {
        Button(wholeWord ? "playkit.hangman.useCells" : "playkit.hangman.useWholeWord") {
            wholeWord.toggle(); wrong = false; unavailable = false
        }
        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
        .disabled(!enabled)
        .accessibilityIdentifier("playkit.hangman.mode")
    }

    private var board: some View {
        PlayKitCenteredFlow(spacing: CYSpacing.md) {
            ForEach(projection.groups(typed: typed)) { group in
                if let separator = group.separator {
                    Text(verbatim: separator).cyText(.cardTitle).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                } else {
                    HStack(spacing: CYSpacing.xs) { ForEach(group.cells) { cell($0) } }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(projection.solved ? Text("playkit.hangman.answer \(projection.display)") : Text("playkit.hangman.placeholder"))
        .accessibilityIdentifier("playkit.hangman.board")
    }

    private func cell(_ cell: PlayKitHangmanCell) -> some View {
        let given = cell.slot.kind == .prefilled
        let active = focused && !projection.solved && cell.order == min(typed.count, projection.blankCount - 1)
        return Button { if !given && !projection.solved && enabled { focused = true } } label: {
            Text(verbatim: cell.character)
                .font(.system(.title, design: .serif).weight(.bold))
                .foregroundStyle(CYColor.textPrimary)
                .frame(width: 34, height: 44)
                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                    .fill(given ? CYColor.bgRaised : CYColor.bgElevated))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous)
                    .strokeBorder(projection.solved ? CYNight.verify : (active ? CYColor.textPrimary : CYColor.borderStrong), lineWidth: active ? 2 : 1))
                .offset(y: active && !reduceMotion ? -2 : 0)
                .scaleEffect(popped == cell.slot.index && !reduceMotion ? 1.12 : 1)
        }
        .buttonStyle(.plain)
        .disabled(given || projection.solved)
        .accessibilityLabel(cell.character.isEmpty
            ? Text("playkit.hangman.cellEmpty \(cell.slot.index + 1)")
            : Text("playkit.hangman.cell \(cell.slot.index + 1) \(cell.character)"))
        .accessibilityIdentifier("playkit.hangman.cell.\(cell.slot.index)")
    }

    @ViewBuilder private var cta: some View {
        if projection.solved {
            if let close {
                CYPillButton("playkit.hangman.continue", action: close).accessibilityIdentifier("playkit.hangman.continue")
            }
        } else {
            CYPillButton("playkit.hangman.submit", action: send)
                .disabled(!enabled || currentPayload == nil)
                .accessibilityIdentifier("playkit.submit.hangman")
        }
    }

    @ViewBuilder private var poolSection: some View {
        if projection.poolRemoved > 0 {
            Text("playkit.letterPool.removed \(projection.poolRemoved)").font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("playkit.hangman.poolRemoved")
        }
        if let binding = Binding($pool) {
            PlayKitLetterPoolInput(state: binding, enabled: enabled && !projection.solved, identifierPrefix: "playkit.hangman",
                                   onEdit: { wrong = false; unavailable = false })
        }
        if let reply = PlayKitWrongReply.text(segment: segment) {
            Text(verbatim: reply).font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("playkit.qa.wrongReply")
        }
        if wrong { Text("playkit.hangman.notYet").font(.footnote).accessibilityIdentifier("playkit.hangman.notYet") }
        if let howTo = projection.howTo { PlayKitHowToButton(text: howTo) }
        PlayKitLetterPoolActions(enabled: enabled, canClear: pool?.hasPlacedCandidates == true,
            canSubmit: pool?.isComplete == true && pool?.hasPlacedCandidates == true,
            identifierPrefix: "playkit.hangman", submitIdentifier: "playkit.submit.hangman",
            clear: { pool?.clearAll(); wrong = false },
            submit: send)
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        text = projection.initialText
        typed = projection.distribute(text)
        if let fresh = LetterPoolState(hangman: projection) { pool = fresh }
    }

    private func input(_ value: String) {
        let limited = String(PlayKitHangmanProjection.codePoints(value).prefix(max(1, projection.blankCount)).joined())
        let next = projection.distribute(limited)
        // Only a newly filled cell pops; deleting does not.
        let changed = next.keys.filter { next[$0] != typed[$0] }.max()
        text = limited; typed = next; wrong = false; unavailable = false
        guard let changed else { return }
        if !reduceMotion {
            withAnimation(QuestifyMotion.release) { popped = changed }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(220))
                if popped == changed { withAnimation(QuestifyMotion.content) { popped = nil } }
            }
        }
    }

    private var currentPayload: [String: PlayWireValue]? {
        if projection.inputMode == .pool {
            guard let pool, pool.isComplete, pool.hasPlacedCandidates else { return nil }
            return pool.hangmanPayload
        }
        return wholeWord ? PlayKitHangmanProjection.wholeWordPayload(word) : projection.payload(typed: typed)
    }

    private func send() {
        guard enabled, !projection.solved, let payload = currentPayload else { return }
        guard let submit else { unavailable = true; return }
        sent = true
        submit(payload)
    }
}

/// Shared letter-pool input: answer slots on top, candidates below.
/// Tapping a candidate fills the first empty slot. Tapping a filled slot returns it.
@MainActor struct PlayKitLetterPoolInput: View {
    @Binding var state: LetterPoolState
    let enabled: Bool
    let identifierPrefix: String
    let onEdit: () -> Void
    @ScaledMetric(relativeTo: .title2) private var cell: CGFloat = 44
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("playkit.letterPool.instructions").font(.subheadline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cell), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(state.slots) { slot in
                    let value = state.text(of: slot)
                    if slot.isFillable {
                        Button {
                            if state.clear(slotID: slot.id) { onEdit() }
                        } label: { PlayKitLetterSlotFace(text: value, fixed: false, cell: cell) }
                        .buttonStyle(.plain)
                        .disabled(!enabled || slot.poolIndex == nil)
                        .accessibilityLabel(value.map { Text(verbatim: $0) } ?? Text("playkit.letterPool.emptySlot"))
                        .accessibilityHint(slot.poolIndex == nil ? Text(verbatim: "") : Text("playkit.letterPool.returnHint"))
                        .accessibilityIdentifier(identifierPrefix + ".slot." + String(slot.id))
                    } else {
                        PlayKitLetterSlotFace(text: value, fixed: true, cell: cell)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(verbatim: value ?? ""))
                            .accessibilityIdentifier(identifierPrefix + ".fixed." + String(slot.id))
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("playkit.letterPool.answerRow"))
            Text("playkit.letterPool.candidates").font(.footnote).foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: cell), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(Array(state.pool.enumerated()), id: \.offset) { index, character in
                    let used = state.isUsed(index)
                    Button {
                        if state.pick(index) { onEdit() }
                    } label: {
                        Text(verbatim: character).font(.title2.weight(.semibold))
                            .frame(minWidth: cell, minHeight: cell)
                    }
                    // N-KIT-QUESTO (r10): system bordered keys (MP playkit-qa letter pool).
                    .buttonStyle(.bordered).controlSize(.small)
                    .opacity(used ? 0.35 : 1)
                    .disabled(!enabled || used || state.isComplete)
                    .accessibilityLabel(Text("playkit.letterPool.candidate \(character)"))
                    .accessibilityValue(used ? Text("playkit.letterPool.used") : Text(verbatim: ""))
                    .accessibilityIdentifier(identifierPrefix + ".candidate." + String(index))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("playkit.letterPool.candidates"))
        }
    }
}

@MainActor struct PlayKitLetterPoolActions: View {
    let enabled: Bool
    let canClear: Bool
    let canSubmit: Bool
    let identifierPrefix: String
    let submitIdentifier: String
    let clear: () -> Void
    let submit: () -> Void
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { clearButton; submitButton }
            VStack(alignment: .leading, spacing: 12) { clearButton; submitButton }
        }
    }
    private var clearButton: some View {
        Button("playkit.letterPool.clear", systemImage: "delete.left", action: clear)
            .buttonStyle(.bordered).disabled(!enabled || !canClear)
            .accessibilityIdentifier(identifierPrefix + ".clear")
    }
    private var submitButton: some View {
        Button("playkit.letterPool.submit", action: submit)
            .buttonStyle(.borderedProminent).controlSize(.large)
            .disabled(!enabled || !canSubmit)
            .accessibilityIdentifier(submitIdentifier)
    }
}

@MainActor struct PlayKitLetterSlotFace: View {
    let text: String?
    let fixed: Bool
    let cell: CGFloat
    var body: some View {
        Text(verbatim: text ?? " ")
            .font(.title2.weight(fixed ? .regular : .semibold))
            .foregroundStyle(fixed ? HierarchicalShapeStyle.secondary : HierarchicalShapeStyle.primary)
            .frame(minWidth: cell, minHeight: cell)
            .background {
                if !fixed {
                    RoundedRectangle(cornerRadius: CYRadius.card).strokeBorder(text == nil ? Color.secondary : Color.accentColor, lineWidth: text == nil ? 1 : 2)
                }
            }
    }
}

/// TYPE question letter pool. Submit stays on the question form; this view only arranges characters.
@MainActor struct PlayKitQuestionLetterPoolView: View {
    let segment: PlayWireValue
    let revision: String
    let enabled: Bool
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest
    @State private var pool: LetterPoolState?
    @State private var loadedRevision: String?
    private var letterPool: PlayQuestionLetterPool? { try? PlayQuestionLetterPool(question: segment) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let letterPool, let binding = Binding($pool) {
                if letterPool.removed > 0 {
                    Text("playkit.letterPool.removed \(letterPool.removed)").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("playkit.letterPool.removed")
                }
                PlayKitLetterPoolInput(state: binding, enabled: enabled, identifierPrefix: "playkit.letterPool", onEdit: onDirty)
                PlayKitLetterPoolActions(enabled: enabled, canClear: binding.wrappedValue.hasPlacedCandidates,
                    canSubmit: binding.wrappedValue.isComplete,
                    identifierPrefix: "playkit.letterPool", submitIdentifier: "playkit.submit.qa",
                    clear: { pool?.clearAll(); onDirty() },
                    submit: { if let state = pool { requestReview("SUBMIT_QA", state.questionPayload, {}) } })
            } else {
                ContentUnavailableView("playkit.configurationInvalid", systemImage: "exclamationmark.triangle")
                    .accessibilityIdentifier("playkit.letterPool.invalid")
            }
        }
        .onAppear { synchronize() }
        .onChange(of: revision) { _, _ in synchronize() }
    }
    private func synchronize() {
        guard loadedRevision != revision else { return }
        loadedRevision = revision
        guard let letterPool, let fresh = LetterPoolState(question: letterPool) else { pool = nil; return }
        pool = pool.map { fresh.rebased(keeping: $0) } ?? fresh
    }
}

// MARK: - UG-03 / UG-04 accusation (pages/play/components/playkit-accusation)

/// Clue board, one suspect card at a time, "accuse X", a centred final confirmation, then an end
/// screen that only reads the server verdict.
@MainActor struct PlayKitAccusationView: View {
    let projection: PlayKitAccusationProjection
    var approvedHosts: Set<String> = []
    var enabled = true
    /// False when the host header already shows the qa title.
    var showsTitle = true
    var accuse: PlayKitAccusationWrite? = nil
    var close: (() -> Void)? = nil
    @State private var current = 0
    @State private var flipping = false
    @State private var confirmOpen = false
    @State private var openClue: Int?
    /// a11y-dt r3: the initial grows with Dynamic Type instead of clipping in a fixed 52 pt circle.
    @ScaledMetric(relativeTo: .title3) private var suspectInitial: CGFloat = 52
    @ScaledMetric(relativeTo: .largeTitle) private var confirmInitial: CGFloat = 72
    @State private var unavailable = false
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale

    private var clueShown: Binding<Bool> {
        Binding(get: { openClue != nil }, set: { shown in if !shown { openClue = nil } })
    }

    /// The three board notes of the mini-program prototype, cycled: tilt in degrees.
    private static let pinTilt: [Double] = [-4, 3, -2, 4, -3, 2]

    var body: some View {
        VStack(spacing: CYSpacing.xl) {
            if projection.showsEnding { ending }
            else {
                if showsTitle && !projection.title.isEmpty {
                    Text(verbatim: projection.title).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).fixedSize(horizontal: false, vertical: true)
                }
                if projection.boardImage != nil || !projection.clues.isEmpty { board }
                ForEach(Array(projection.intro.enumerated()), id: \.offset) { _, block in
                    if case .text(let text) = block {
                        Text(verbatim: text).cyText(.body).foregroundStyle(CYColor.textSecondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if projection.wrongAttempt {
                    Text(verbatim: projection.retryNote.isEmpty ? appLocalized("playkit.accusation.wrong", locale: locale) : projection.retryNote)
                        .cyText(.meta).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("playkit.accusation.wrong")
                }
                if !projection.suspects.isEmpty {
                    deck
                    bar
                }
            }
        }
        .frame(maxWidth: .infinity)
        // Owner rule 2: the MP confirm / clue popups are native sheets with detents, not a dimmed overlay.
        .sheet(isPresented: $confirmOpen) {
            if let suspect = suspect { confirmPanel(suspect) }
        }
        .sheet(isPresented: clueShown) {
            if let openClue, projection.clues.indices.contains(openClue) { cluePanel(projection.clues[openClue]) }
        }
        .onChange(of: projection.suspects.count) { _, count in current = min(current, max(0, count - 1)) }
        .cyHapticEvent(.wrongAnswer, trigger: projection.wrongAttempt) { old, next in !old && next }
        .cyHapticEvent(.rewardOrMedal, trigger: projection.showsEnding) { old, next in !old && next }
        .cyDomainScreen(.game)
    }

    private var suspect: PlayKitAccusationProjection.Suspect? {
        projection.suspects.indices.contains(current) ? projection.suspects[current] : nil
    }

    // Board image under pinned notes for the clues this run has earned. No clue, no note.
    private var board: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised)
            if let image = projection.boardImage {
                PlayKitArtwork(source: image, approvedHosts: approvedHosts)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .accessibilityHidden(true)
            }
            PlayKitCenteredFlow(spacing: CYSpacing.md) {
                ForEach(Array(projection.clues.enumerated()), id: \.element.id) { index, clue in
                    let name = clue.name.isEmpty ? appLocalized("playkit.accusation.clue", locale: locale) : clue.name
                    Button { openClue = index; confirmOpen = false } label: {
                        Text(verbatim: name).cyText(.label).foregroundStyle(CYColor.textPrimary)
                            .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
                            .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYColor.bgElevated))
                            .rotationEffect(.degrees(reduceMotion ? 0 : Self.pinTilt[index % Self.pinTilt.count]))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("playkit.accusation.clueLabel \(name)"))
                    .accessibilityIdentifier("playkit.accusation.clue.\(index)")
                }
            }
            .padding(CYSpacing.lg)
        }
        .frame(minHeight: 140)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(projection.boardAlt.isEmpty ? Text("playkit.accusation.board") : Text(verbatim: projection.boardAlt))
        .accessibilityIdentifier("playkit.accusation.board")
    }

    private var deck: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let suspect {
                card(suspect)
                    .id(suspect.id)
                    // N-KIT-QUESTO (r10): no 3D turn; the next suspect cross-fades (MP playkit-qa accusation deck).
                    .opacity(flipping ? 0 : 1)
                    .onTapGesture(perform: flipNext)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text(verbatim: suspect.identity.isEmpty ? suspect.name : appJoinedPair(suspect.name, suspect.identity, locale: locale)))
                    .accessibilityValue(Text("playkit.accusation.position \(current + 1) \(projection.suspects.count)"))
                    .accessibilityAddTraits(projection.suspects.count > 1 ? .isButton : [])
            }
            if projection.suspects.count > 1 {
                HStack {
                    HStack(spacing: CYSpacing.xs) {
                        ForEach(projection.suspects.indices, id: \.self) { index in
                            Circle().fill(index == current ? CYColor.textPrimary : CYColor.textTertiary).frame(width: 6, height: 6)
                        }
                    }.accessibilityHidden(true)
                    Spacer()
                    Button(action: flipNext) {
                        Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(CYColor.textInverse)
                            .frame(width: 44, height: 44).background(Circle().fill(CYColor.textPrimary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("playkit.accusation.next"))
                    .accessibilityIdentifier("playkit.accusation.next")
                }
                .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md)
            }
        }
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYColor.bgElevated))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(CYColor.borderSubtle))
        .accessibilityIdentifier("playkit.accusation.deck")
    }

    private func card(_ suspect: PlayKitAccusationProjection.Suspect) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ZStack {
                Rectangle().fill(CYColor.bgRaised)
                if let avatar = suspect.avatar { PlayKitArtwork(source: avatar, approvedHosts: approvedHosts) }
                else { Text(verbatim: suspect.initial).cyText(.display).foregroundStyle(CYColor.textTertiary) }
            }
            .frame(height: 124).frame(maxWidth: .infinity).clipped()
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: suspect.initial).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .frame(width: suspectInitial, height: suspectInitial).background(Circle().fill(CYColor.bgRaised))
                    .overlay(Circle().strokeBorder(CYColor.bgElevated, lineWidth: 3))
                    .padding(.top, -36).accessibilityHidden(true)
                Text(verbatim: suspect.name).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                if !suspect.identity.isEmpty {
                    Text(verbatim: suspect.identity).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }
                ForEach(Array(suspect.testimony.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: appQuoted(line, locale: locale)).cyText(.body).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CYSpacing.md)
                        .background(CYColor.bgRaised)
                        .overlay(alignment: .leading) { Rectangle().fill(CYNight.lanternHot).frame(width: 3) }
                }
            }
            .padding(.horizontal, CYSpacing.lg).padding(.bottom, CYSpacing.md)
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }

    private var bar: some View {
        HStack(spacing: CYSpacing.md) {
            if projection.suspects.count > 1 {
                CYPillButton("playkit.accusation.thinkAgain", style: .secondary, action: flipNext)
                    .accessibilityIdentifier("playkit.accusation.thinkAgain")
            }
            CYPillButton(verbatim: appLocalized("playkit.accusation.accuse \(suspect?.name ?? "—")", locale: locale)) {
                guard enabled, suspect != nil, !flipping else { return }
                openClue = nil; unavailable = false; confirmOpen = true
            }
            .disabled(!enabled)
            .accessibilityIdentifier("playkit.accusation.accuse")
        }
    }

    private func confirmPanel(_ suspect: PlayKitAccusationProjection.Suspect) -> some View {
        PlayKitCenteredPanel(dismiss: { confirmOpen = false }) {
            Text(verbatim: suspect.initial).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                .frame(width: confirmInitial, height: confirmInitial).background(Circle().fill(CYColor.bgRaised)).accessibilityHidden(true)
            let name = suspect.name.isEmpty ? appLocalized("playkit.accusation.someone", locale: locale) : suspect.name
            Text(verbatim: appLocalized("playkit.accusation.confirmTitle \(name)", locale: locale))
                .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
            Text(verbatim: (suspect.identity.isEmpty ? "" : suspect.identity + " · ") + appLocalized("playkit.accusation.final", locale: locale))
                .cyText(.meta).foregroundStyle(CYColor.textTertiary).multilineTextAlignment(.center)
            if unavailable {
                Text("playkit.questo.unavailable").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center).accessibilityIdentifier("playkit.accusation.unavailable")
            }
            CYPillButton("playkit.accusation.confirm") {
                guard let accuse else { unavailable = true; return }
                confirmOpen = false
                accuse(suspect.id)
            }
            .accessibilityIdentifier("playkit.accusation.confirm")
            CYPillButton("playkit.accusation.thinkAgain", style: .tertiary) { confirmOpen = false }
                .accessibilityIdentifier("playkit.accusation.cancel")
        }
        .accessibilityIdentifier("playkit.accusation.confirmPanel")
    }

    private func cluePanel(_ clue: PlayKitAccusationProjection.Clue) -> some View {
        PlayKitCenteredPanel(dismiss: { openClue = nil }) {
            Text("playkit.accusation.clue").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            if let image = clue.image {
                PlayKitArtwork(source: image, approvedHosts: approvedHosts)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .frame(maxHeight: 180).accessibilityHidden(true)
            }
            Text(verbatim: clue.name.isEmpty ? appLocalized("playkit.accusation.clue", locale: locale) : clue.name)
                .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
            if !clue.text.isEmpty {
                Text(verbatim: clue.text).cyText(.body).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            }
            CYPillButton("playkit.accusation.collapse", style: .secondary) { openClue = nil }
                .accessibilityIdentifier("playkit.accusation.clueClose")
        }
        .accessibilityIdentifier("playkit.accusation.cluePanel")
    }

    // End screen: illustration, the server verdict word, the author's ending blocks.
    private var ending: some View {
        VStack(spacing: CYSpacing.xl) {
            ZStack {
                if projection.outcome == .solved || projection.outcome == .early {
                    Circle().fill(CYNight.glow(radius: 90)).frame(width: 220, height: 220).accessibilityHidden(true)
                }
                Image(systemName: endingSymbol).font(CYTypography.display).imageScale(.large).scaleEffect(1.6)
                    .foregroundStyle(projection.outcome == .failed ? CYColor.textTertiary : CYColor.textPrimary)
                    .symbolEffect(.pulse, isActive: projection.pending && !reduceMotion)
                    .accessibilityHidden(true)
            }
            .frame(height: 220)
            Text(endingLabel).cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                .accessibilityIdentifier("playkit.accusation.verdict")
            ForEach(Array(projection.screen.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let text):
                    Text(verbatim: text).cyText(.body).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
                case .image(let url, let alt):
                    PlayKitArtwork(source: url, approvedHosts: approvedHosts)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .accessibilityLabel(alt.isEmpty ? Text("playkit.accusation.endingImage") : Text(verbatim: alt))
                }
            }
            if !projection.pending, let close {
                CYPillButton("playkit.hangman.continue", action: close).accessibilityIdentifier("playkit.accusation.continue")
            }
        }
        .transition(reduceMotion ? .identity : .move(edge: .bottom).combined(with: .opacity))
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

    /// The current card turns out on its vertical axis and the next turns in. Reduce Motion fades instead.
    private func flipNext() {
        let count = projection.suspects.count
        guard count > 1, !flipping, !confirmOpen else { return }
        let half = reduceMotion ? 0.01 : 0.24
        withAnimation(.easeIn(duration: half)) { flipping = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(half))
            current = (current + 1) % count
            withAnimation(.easeOut(duration: half)) { flipping = false }
        }
    }
}

// MARK: - Shared pieces

/// Body of an MP popup shown as a native sheet (owner rule 2): centred content, medium / large detents, the system
/// grabber and swipe-down dismiss. `dismiss` is kept for call sites; the sheet binding owns presentation.
@MainActor struct PlayKitCenteredPanel<Content: View>: View {
    let dismiss: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.md, content: content)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .accessibilityElement(children: .contain)
    }
}

/// Rows wrap between items and each row is centred, as the mini-program boards are.
struct PlayKitCenteredFlow: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let lines = rows(width: proposal.width ?? .infinity, subviews: subviews)
        let height = lines.reduce(0) { $0 + $1.height } + spacing * CGFloat(max(0, lines.count - 1))
        let widest = lines.map(\.width).max() ?? 0
        let width = proposal.width.map { $0.isFinite ? $0 : widest } ?? widest
        return CGSize(width: width, height: height)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX + max(0, (bounds.width - row.width) / 2)
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }
    private struct Row { var indices: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }
    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty && next > width { rows.append(row); row = Row() }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
