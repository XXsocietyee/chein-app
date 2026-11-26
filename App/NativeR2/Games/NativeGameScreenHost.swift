import SwiftUI

/// Kits drawn through `NativeGameShell` while `NativeR2Flags.games` is on.
/// Half A (this file's lane): templates 1–3. Half B adds templates 4–6 in `templateB`.
enum NativeGameKits {
    static let templateA: Set<PlayKitScreenKind> = [
        // 1 Answer
        .qa, .typeIn, .predict, .estimate, .pricePair, .diyName, .note, .profile,
        // 2 Sort & match
        .sort, .classify, .match, .bingo, .silentOrder,
        // 3 Sensors & timing
        .compass, .walk, .steps, .ballShake, .shout, .quietHold, .reaction, .stopwatch, .countdown, .timeWindow, .slowTask
    ]
    /// Templates 4–6 (camera, chance, story choice). Filled by the other half.
    static var templateB: Set<PlayKitScreenKind> { [] }
    static func covers(_ kind: PlayKitScreenKind) -> Bool { templateA.contains(kind) || templateB.contains(kind) }
    /// Kits drawn by a child view that publishes its own bottom-bar action.
    static let childKinds: Set<PlayKitScreenKind> = [.reaction, .countdown, .stopwatch, .typeIn, .ballShake, .quietHold, .compass, .shout]
    /// Kits whose server reply to a wrong typed answer shows under the controls.
    static let wrongReplyKinds: Set<PlayKitScreenKind> = [.qa, .typeIn]
}

/// The shell wiring for `PlayKitScreen`. Same `prepare` → review → write path, same
/// `PlayGameOutcome` rules and retry gate; only the drawing changes.
extension PlayKitScreen {
    var usesNativeGame: Bool {
        NativeR2Flags.games && NativeGameKits.covers(kind) && accusationProjection == nil
    }

    var nativeGameContainer: some View {
        NativeGameShell(
            title: nativeGameTitle,
            style: presentation == .inline ? .embedded : .list,
            reorderable: kind == .sort && enabled,
            close: presentation == .sheet ? { if dirty { leaveReview = true } else { dismiss() } } : nil,
            progress: nativeProgress,
            wrongReply: nativeWrongReply,
            submit: nativeBottomAction,
            help: nativeHelp,
            analyticsNodeID: model.state?.nodeID,
            analyticsKit: kind.rawValue,
            identifier: "playkit.screen." + kind.rawValue,
            resultPresented: $nativeResultShown,
            resultActions: nativeResultActions,
            controls: {
                nativeHeaderSections
                nativeStatusSections
                if model.isCurrent && raw.object != nil { nativeControls }
            },
            outcome: { nativeOutcome })
        .refreshable {
            if model.pending == nil && model.isCurrent && model.phase != "submitting" { await model.refreshAuthoritative() }
        }
        .onChange(of: nativeResultIdentity) { _, next in
            guard next != nil, nativeExpectResult, presentation != .inline else { return }
            nativeExpectResult = false
            nativeResultShown = true
        }
        .sensoryFeedback(.success, trigger: projection.reportedPass == true) { old, next in !old && next }
    }

    /// 「第 N 关 · 玩法」; without a station number, the kit name alone.
    var nativeGameTitle: Text {
        let name = appLocalized(String.LocalizationValue(stringLiteral: "playkit.kind." + kind.rawValue), locale: .current)
        if let ordinal = stage?.ordinal { return Text("nativeGames.title \(ordinal) \(name)") }
        return Text(verbatim: name)
    }

    var nativeWrongReply: String? {
        guard NativeGameKits.wrongReplyKinds.contains(kind), model.isCurrent else { return nil }
        if kind == .qa, raw["letterPool"] != .null { return nil }
        return PlayKitWrongReply.text(segment: raw)
    }

    /// Profile asks one question at a time: "第 n/N 题".
    var nativeProgress: NativeGameProgress? {
        guard kind == .profile, !projection.complete else { return nil }
        let total = nativeProfileQuestions.count + (raw["avatar"]["enabled"].bool == true ? 1 : 0)
        guard total > 1 else { return nil }
        return NativeGameProgress(current: min(profileStep, total - 1) + 1, total: total)
    }

    var nativeShowsContinue: Bool {
        PlayGameOutcome.showsContinue(complete: projection.complete, pending: model.pending != nil, phase: model.phase)
    }

    /// The single prominent button: continue once the game is over, otherwise the kit's own action.
    var nativeBottomAction: NativeGameSubmit? {
        if presentation != .inline, nativeShowsContinue {
            return NativeGameSubmit(title: Text("playkit.story.continue"), enabled: true,
                                    identifier: "playkit.story.continue", action: { dismiss() })
        }
        if let kitSubmit = nativeKitSubmit { return kitSubmit }
        // A remounted child republishes on appear; nothing stale shows once the kit is hidden.
        return model.isCurrent && raw.object != nil && NativeGameKits.childKinds.contains(kind) ? nativeChildSubmit : nil
    }

    var nativeResultActions: NativeGameResultActions {
        NativeGameResultActions(
            canRetry: PlayGameOutcome.resolve(projection) == .notPassed && !projection.complete && model.canInteract,
            canContinue: presentation != .inline && nativeShowsContinue,
            retry: { if [.qa, .pricePair, .predict].contains(kind) { selected = [] } },
            continueStory: { dismiss() })
    }

    /// Changes only when the server reports a new verdict, attempt or completion.
    var nativeResultIdentity: String? {
        PlayGameOutcome.resolve(projection).map { "\($0.rawValue):\(raw["attempts"].integer ?? -1):\(projection.complete)" }
    }

    /// Same write path as `prepare`; also marks that the next server verdict opens the result sheet.
    func nativePrepare(_ action: String, _ payload: [String: PlayWireValue] = [:], _ completion: @escaping () -> Void = {}) {
        nativeExpectResult = true
        prepare(action, payload, completion)
    }

    func nativeSubmit(_ action: String, _ payload: [String: PlayWireValue], valid: Bool,
                      title: Text = Text("playkit.review"), identifier: String? = nil) -> NativeGameSubmit {
        NativeGameSubmit(title: title, enabled: enabled && valid, busy: model.phase == "submitting",
                         identifier: identifier ?? "playkit.submit." + kind.rawValue,
                         action: { nativePrepare(action, payload) })
    }

    func nativeValid(_ action: String, _ payload: [String: PlayWireValue]) -> Bool {
        (try? PlayKitInputContract.validate(kind: kind.rawValue, action: action, payload: payload, segment: raw)) != nil
    }

    func nativeToggle(_ id: String, multi: Bool) {
        if multi { if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } }
        else { selected = [id] }
        dirty = true
    }

    // MARK: Header and status

    @ViewBuilder var nativeHeaderSections: some View {
        if let gameStage = stage, !gameStage.isEmpty {
            Section { PlayGameStageHeader(stage: gameStage) }
        }
        Section {
            if let eyebrow = raw["eyebrow"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !eyebrow.isEmpty, eyebrow != projection.title {
                Text(verbatim: eyebrow).font(.footnote).foregroundStyle(.secondary)
                    .accessibilityIdentifier("playkit.eyebrow." + kind.rawValue)
            }
            if !projection.title.isEmpty {
                Text(verbatim: projection.title).font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(["lead", "prompt", "hint", "sub"], id: \.self) { key in
                if let value = raw[key].text, !value.isEmpty {
                    Text(verbatim: value).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            }
            if let source = PlayKitReferenceImage.source(in: raw) {
                PlayKitReferenceButton(source: source, alt: PlayKitReferenceImage.alt(in: raw),
                    approvedHosts: approvedArtworkHosts, nodeID: model.state?.nodeID, kit: kind.rawValue)
            }
            nativeTriesRow
            PlayKitIssueReportMenu(nodeID: model.state?.nodeID, kit: kind.rawValue)
        }
    }

    /// 「还能错 N 次」 for capped kits, otherwise the attempt count.
    @ViewBuilder var nativeTriesRow: some View {
        let used = raw["attempts"].integer ?? raw["tries"].integer
        if let cap = raw["maxTries"].integer ?? raw["maxAttempts"].integer, cap > 0 {
            LabeledContent {
                Text(verbatim: "\(max(0, cap - (used ?? 0))) / \(cap)").monospacedDigit()
            } label: {
                Text("playkit.triesLeft")
            }
            .accessibilityIdentifier("playkit.triesLeft")
        } else if let used, ![PlayKitScreenKind.typeIn, .sort, .match, .classify].contains(kind) {
            LabeledContent {
                Text(verbatim: String(used)).monospacedDigit()
            } label: {
                Text("playkit.attempts")
            }
        }
    }

    @ViewBuilder var nativeStatusSections: some View {
        if let screenIssue = issue {
            Section { Label { PlayExperienceIssueView(issue: screenIssue) } icon: { Image(systemName: "exclamationmark.triangle") } }
        }
        if let modelIssue = model.issue {
            Section { Label { PlayExperienceIssueView(issue: modelIssue) } icon: { Image(systemName: "exclamationmark.triangle") } }
        }
        if !model.isCurrent {
            Section {
                ContentUnavailableView {
                    Label("nativeGames.sessionChanged.title", systemImage: "arrow.triangle.2.circlepath")
                } description: {
                    Text("playkit.sessionChanged")
                }
            }
        } else if raw.object == nil {
            Section {
                ContentUnavailableView {
                    Label("playkit.unavailable", systemImage: "rectangle.slash")
                } description: {
                    Text("nativeGames.unavailable.pull")
                }
            }
        }
        Section {
            if model.phase == "loading" { ProgressView("playkit.sending") }
            if model.phase == "unknown" {
                Button("playkit.reconcile") { Task { await model.recover() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("playkit." + kind.rawValue + ".reconcile")
            }
            if model.phase == "retryable" {
                Button("playkit.retryExact") { Task { await model.retryExact() } }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("playkit." + kind.rawValue + ".retryExact")
            }
            if presentation == .inline, model.pending == nil, model.isCurrent, model.phase != "submitting" {
                Button("playkit.refresh") { Task { await model.refreshAuthoritative() } }
                    .accessibilityIdentifier("playkit." + kind.rawValue + ".refresh")
            }
            CYScreenOfflineWriteBanner(routes: ["/api/play/advanced/action"], session: offlineWriteSession.session)
        } footer: {
            if model.pending != nil { Text("playkit.pendingBoundary") }
        }
    }

    // MARK: Kit dispatch

    @ViewBuilder var nativeControls: some View {
        switch kind {
        case .qa: nativeQA
        case .predict: nativePredict
        case .estimate: nativeEstimate
        case .pricePair: nativePricePair
        case .diyName: nativeDiyName
        case .note: nativeNote
        case .profile: nativeProfile
        case .sort, .match, .classify: nativeReasoning
        case .bingo: nativeBingo
        case .silentOrder: nativeSilentOrder
        case .walk: nativeWalk
        case .slowTask: nativeSlowTask
        case .steps:
            Section { NativeStepsHostView(advanced: model, segment: raw) }
        case .timeWindow:
            Section { NativeTimeWindowHostView(advanced: model, segment: raw) }
        case .reaction, .countdown, .stopwatch, .typeIn:
            NativeGameTimedKit(kind: kind, segment: raw, enabled: enabled, active: model.isCurrent,
                onDirty: { dirty = true }, requestReview: nativePrepare,
                revisionIdentity: runtimeIdentity, currentRevisionIdentity: { model.state.map { "\($0.sessionID):\($0.version)" } ?? "" },
                publish: { nativeChildSubmit = $0 })
                .id(childReset)
        case .ballShake, .quietHold, .compass, .shout:
            NativeGameSensorKit(kind: kind, segment: raw, enabled: enabled, active: model.isCurrent,
                onDirty: { dirty = true }, requestReview: nativePrepare,
                revisionIdentity: runtimeIdentity, currentRevisionIdentity: { model.state.map { "\($0.sessionID):\($0.version)" } ?? "" },
                makeSensorProvider: makeSensorProvider,
                publish: { nativeChildSubmit = $0 })
                .id(childReset)
        default: EmptyView()
        }
    }

    /// Bottom-bar action for kits whose draft lives on the screen (not in a child view).
    var nativeKitSubmit: NativeGameSubmit? {
        guard raw.object != nil, model.isCurrent else { return nil }
        switch kind {
        case .qa: return nativeQASubmit
        case .predict:
            if let mine = raw["myOptionKey"].text, !mine.isEmpty { return nil }
            return nativeSubmit("SUBMIT_PREDICT", ["optionKey": .string(selected.first ?? "")], valid: !selected.isEmpty)
        case .estimate: return nativeEstimateSubmit
        case .pricePair:
            guard !projection.complete else { return nil }
            return nativeSubmit("SUBMIT_PRICE_PAIR", ["pickId": .string(selected.first ?? "")], valid: !selected.isEmpty)
        case .diyName:
            guard !projection.complete else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = raw["ctaLabel"].text.flatMap { $0.isEmpty ? nil : $0 }
            return nativeSubmit("SUBMIT_DIY_NAME", ["name": .string(trimmed)], valid: !trimmed.isEmpty,
                                title: label.map { Text(verbatim: $0) } ?? Text("playkitLegacy.name.submit"))
        case .note:
            guard !projection.complete else { return nil }
            return nativeSubmit("SUBMIT_NOTE", ["text": .string(text)], valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        case .profile: return nativeProfileSubmit
        case .sort, .match, .classify: return nativeReasoningSubmit
        case .slowTask: return nativeSlowTaskSubmit
        default: return nil
        }
    }

    // MARK: Result

    @ViewBuilder var nativeOutcome: some View {
        if reasoningFeedback.showsResult(for: projection), let outcome = PlayGameOutcome.resolve(projection) {
            Section {
                nativeVerdictLabel
                PlayGameResultLine(outcome: outcome, open: !projection.complete)
                if let feedback = projection.feedback, !feedback.isEmpty, nativeWrongReply == nil {
                    Text(verbatim: feedback).fixedSize(horizontal: false, vertical: true)
                }
                nativeOutcomeExtras
            } header: {
                Text("nativeGames.result.title")
            }
            .accessibilityIdentifier("nativeGames.result")
        }
    }

    @ViewBuilder var nativeVerdictLabel: some View {
        if PlayKitNoRightAnswer.applies(kind: kind, segment: raw) && projection.reportedPass != nil {
            Label("playkit.story.recorded", systemImage: "bookmark.circle")
        } else if let passed = projection.reportedPass {
            Label(passed ? "playkit.result.passed" : "playkit.result.notPassed", systemImage: passed ? "checkmark.circle" : "info.circle")
        } else if projection.complete {
            Label("playkit.result.recorded", systemImage: "checkmark.circle")
        }
    }

    @ViewBuilder var nativeOutcomeExtras: some View {
        if kind == .qa, let answer = raw["answerId"].text, !answer.isEmpty, projection.complete {
            LabeledContent {
                Text(verbatim: projection.options.first { $0.id == answer }?.label ?? answer)
            } label: {
                Text("playkit.qa.revealedAnswer")
            }
        }
        if kind == .typeIn, let result = projection.typeInResultKey {
            Text(LocalizedStringKey(result)).accessibilityIdentifier("playkit.type.result")
        }
        if [PlayKitScreenKind.sort, .match, .classify].contains(kind), (raw["attempts"].integer ?? 0) > 0,
           let resultKey = projection.reasoningResultKey {
            Text(LocalizedStringKey(resultKey)).accessibilityIdentifier("playkit.reasoning.result")
        }
    }
}
