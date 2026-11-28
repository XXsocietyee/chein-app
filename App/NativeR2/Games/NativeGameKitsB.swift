import SwiftUI

/// Native r2 games, half B: templates 4–6 (camera, chance, story choice) plus hidden and
/// blindtaste, which the games-a shell leaves to this half. `NativeGameKits.templateB`
/// reads this set; the shell's dispatch and bottom bar fall through to the members below.
/// predict and bingo are drawn by half A. album and journey-check are not `PlayKitScreen`
/// kinds: they switch at their own hosts (`PlayAdvancedView`, `PlayExperienceView`).
enum NativeGameKitsB {
    static let kinds: Set<PlayKitScreenKind> = [
        // 4 Camera
        .photoCheck, .scan,
        // 5 Chance
        .coinFlip, .diceRoll, .random,
        // 6 Story choice
        .branch, .musicCorner, .dailySign,
        // Template 1 kits handed to this half by games-a
        .hiddenObject, .blindTaste
    ]
}

extension PlayKitScreen {
    // MARK: Dispatch (NativeGameScreenHost.nativeControls falls through to this)

    @ViewBuilder var nativeControlsB: some View {
        switch kind {
        case .photoCheck: cameraPhotoCheckForm
        case .scan: cameraScanForm
        case .coinFlip: ChanceCoinFlipKit(context: gamesBContext)
        case .diceRoll: ChanceDiceRollKit(context: gamesBContext)
        case .random: ChanceRandomKit(context: gamesBContext)
        case .branch: ChoiceBranchKit(context: gamesBContext, cast: castContext)
        case .musicCorner: ChoiceMusicCornerKit(context: gamesBContext, mediaScope: mediaScope, makeAudio: makeAudio)
        case .dailySign: ChoiceDailySignKit(context: gamesBContext, stage: $profileStep)
        case .hiddenObject: nativeHiddenObjectB
        case .blindTaste: ChoiceBlindTasteKit(context: gamesBContext, stage: $profileStep)
        default: EmptyView()
        }
    }

    // MARK: Bottom bar (NativeGameScreenHost.nativeKitSubmit falls through to this)

    /// The one prominent action. Camera and hidden keep their actions in the kit (multi-step capture, a tap on
    /// the scene); music plays in the kit and 继续 sits here; branch confirms its pick here (MP 确认选择).
    var nativeKitSubmitB: NativeGameSubmit? {
        switch kind {
        case .branch:
            // MP: 确认选择 only with more than one option and before the end step; a single option confirms on tap.
            let options = projection.options
            guard !projection.complete, raw["currentStep"]["terminal"].bool != true, options.count > 1 else { return nil }
            let choice = selected.first ?? ""
            return nativeSubmit("CHOOSE", ["optionId": .string(choice)], valid: options.contains { $0.id == choice },
                                title: Text("playkit.branch.confirmPick"), identifier: "playkit.submit.branch")
        case .coinFlip:
            return NativeGameSubmit(title: Text("playkit.coin.flip"), enabled: enabled, busy: model.phase == "submitting",
                                    identifier: "playkit.coin.flip", action: { nativePrepare("FLIP_COIN") })
        case .diceRoll:
            // MP: 掷骰子 for d6, 掷 D20 for the D20 check.
            let d20 = raw["mode"].text == "d20"
            return NativeGameSubmit(title: Text(d20 ? LocalizedStringKey("playkit.d20.roll") : LocalizedStringKey("playkit.dice.roll")), enabled: enabled, busy: model.phase == "submitting",
                                    identifier: "playkit.dice.roll", action: { nativePrepare("ROLL_DICE") })
        case .random:
            let remaining = (raw["drawCount"].integer ?? 0) - (raw["drawn"].array ?? []).count
            return NativeGameSubmit(title: Text("playkit.random.draw"), enabled: enabled && remaining > 0, busy: model.phase == "submitting",
                                    identifier: "playkit.random.draw", action: { nativePrepare("DRAW") })
        case .dailySign:
            // MP ds__cta: 收下这张签 once the line is revealed; after the claim 出发 closes the kit (not inline).
            if projection.complete {
                guard presentation != .inline else { return nil }
                return NativeGameSubmit(title: Text("playx.opening.depart"), enabled: true,
                                        identifier: "playkit.dailySign.go", action: { dismiss() })
            }
            let lines = (raw["lines"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
            let revealed = profileStep >= 1 || lines.isEmpty
            return nativeSubmit("CLAIM_DAILY_SIGN", ["text": .string(text), "photoUrl": .string(avatarURL)],
                                valid: revealed && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                title: Text("nativeR2.gamesB.daily.accept"))
        case .musicCorner:
            // MP 继续: the music corner is never judged, so it can always be left (walk-through A25).
            guard presentation != .inline else { return nil }
            return NativeGameSubmit(title: Text("playkit.music.continue"), enabled: true,
                                    identifier: "playkit.musicCorner.continue", action: { dismiss() })
        case .blindTaste:
            // MP: 确认选择 only on the answer step (领小样 and 闭眼 have their own buttons in the kit).
            guard raw["solved"].bool != true, !projection.complete,
                  ChoiceBlindTasteKit.stage(raw, local: profileStep) == 2 else { return nil }
            return nativeSubmit("SUBMIT_BLIND_TASTE", ["key": .string(selected.first ?? "")], valid: !selected.isEmpty,
                                title: Text("playkit.branch.confirmPick"))
        default:
            return nil
        }
    }

    // MARK: hidden (tap the spot on the scene; the server judges the point)

    /// MP `playkit-hidden`: title (shell) → scene (tap to find; found dots stay) → target chips (found marked) → n / total.
    @ViewBuilder var nativeHiddenObjectB: some View {
        let found = Set((raw["foundIds"].array ?? []).compactMap(\.text))
        let targets = PlayKitOption.read(raw["targets"])
        let foundCount = targets.isEmpty ? found.count : targets.filter { found.contains($0.id) || $0.raw["found"].bool == true }.count
        let total = max(raw["total"].integer ?? 0, targets.count)
        Section {
            if let url = QuestifyCardArtwork.safeURL(raw["imageUrl"].text), let host = url.host, approvedArtworkHosts.contains(host) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFit().overlay {
                            // The overlay follows the fitted image's actual rectangle, not its outer container.
                            GeometryReader { geometry in
                                Color.clear.contentShape(Rectangle())
                                    .gesture(SpatialTapGesture().onEnded { event in
                                        guard enabled, let point = PlayKitInputContract.imagePoint(x: Double(event.location.x), y: Double(event.location.y), viewWidth: Double(geometry.size.width), viewHeight: Double(geometry.size.height), imageWidth: Double(geometry.size.width), imageHeight: Double(geometry.size.height)) else { return }
                                        nativePrepare("SUBMIT_HIDDEN_OBJECT", ["x": .number(point.0), "y": .number(point.1)])
                                    })
                                // MP `hd__dot`: a found target stays marked where it was found (server x / y in %).
                                ForEach(hiddenFoundDots) { dot in
                                    Circle()
                                        .strokeBorder(.white, lineWidth: 3)
                                        .background(Circle().fill(Color.green.opacity(0.6)))
                                        .frame(width: 28, height: 28)
                                        .position(x: geometry.size.width * dot.x / 100, y: geometry.size.height * dot.y / 100)
                                        .accessibilityHidden(true)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .accessibilityLabel(Text("playkit.hidden.scene"))
                        .accessibilityHint(Text("playkit.hidden.hint"))
                        .accessibilityAction(named: Text("playkit.hidden.center")) {
                            if enabled { nativePrepare("SUBMIT_HIDDEN_OBJECT", ["x": .number(0.5), "y": .number(0.5)]) }
                        }
                    } else if phase.error != nil {
                        ContentUnavailableView {
                            Label("playkit.imageUnavailable", systemImage: "photo.badge.exclamationmark")
                        } actions: {
                            Button("playkit.imageRetry") { childReset = UUID() }
                                .buttonStyle(.bordered)
                        }
                    } else {
                        ProgressView("playkit.hidden.scenePending").frame(maxWidth: .infinity, minHeight: 200)
                    }
                }
                .id(childReset)
                .accessibilityIdentifier("playkit.hidden.scene")
            } else {
                ContentUnavailableView("playkit.hidden.scenePending", systemImage: "photo")
            }
        }
        if !targets.isEmpty || total > 0 {
            Section {
                ForEach(targets.filter { !$0.label.isEmpty }) { target in
                    let done = found.contains(target.id) || target.raw["found"].bool == true
                    Label {
                        Text(verbatim: target.label)
                    } icon: {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    }
                    .foregroundStyle(done ? Color.green : Color.primary)
                    .accessibilityAddTraits(done ? .isSelected : [])
                }
                Text(verbatim: "\(foundCount) / \(total)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("playkit.hidden.progress \(foundCount) \(total)"))
                    .accessibilityIdentifier("playkit.hidden.progress")
            } header: {
                Text("nativeR2.gamesB.hidden.targets")
            }
        }
    }

    struct HiddenFoundDot: Identifiable { let id: String; let x: Double; let y: Double }

    var hiddenFoundDots: [HiddenFoundDot] {
        let found = Set((raw["foundIds"].array ?? []).compactMap(\.text))
        return PlayKitOption.read(raw["targets"]).compactMap { target in
            guard found.contains(target.id) || target.raw["found"].bool == true,
                  let x = target.raw["x"].double, let y = target.raw["y"].double,
                  (0...100).contains(x), (0...100).contains(y) else { return nil }
            return HiddenFoundDot(id: target.id, x: x, y: y)
        }
    }
}

// MARK: - blindtaste

/// MP `playkit-blindtaste`: kicker · title · three steps lit up to the current one · cups (letters only) +
/// 小样拿到了 → 闭上眼 (the screen goes dark, 3 s count, opening early = peeked) → 刚才那杯是哪一种？ rows + 确认选择.
/// The step lives in `PlayKitScreen.profileStep` (reset with the kit) so the shell's bottom bar shows 确认选择 only on
/// the answer step. Submit (`SUBMIT_BLIND_TASTE {key}`) stays the shell's bottom button.
@MainActor struct ChoiceBlindTasteKit: View {
    let context: GamesBKitContext
    @Binding var stage: Int
    @State private var eyesClosed = false
    @State private var peeked = false
    private var raw: PlayWireValue { context.segment }

    /// MP `startStage`: an answered or judged kit opens on the answer step.
    static func stage(_ raw: PlayWireValue, local: Int) -> Int {
        if raw["solved"].bool == true || (raw["attempts"].integer ?? 0) > 0 { return 2 }
        if let key = raw["selectedKey"].text, !key.isEmpty { return 2 }
        return min(max(local, 0), 2)
    }
    private var current: Int { Self.stage(raw, local: stage) }
    private var pick: Binding<String> {
        Binding(get: { context.selection.wrappedValue.first ?? "" },
                set: { context.selection.wrappedValue = $0.isEmpty ? [] : [$0]; context.markDirty() })
    }
    private var stepsSentence: String? {
        if let steps = raw["steps"].text, !steps.isEmpty { return steps }
        let joined = (raw["steps"].array ?? []).compactMap(\.text).joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
    private static let stepKeys = ["playkitLegacy.blind.step1", "playkitLegacy.blind.step2", "playkitLegacy.blind.step3"]

    var body: some View {
        Section {
            if context.projection.title.isEmpty {
                Text("playkit.blind.title").font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(Self.stepKeys.enumerated()), id: \.offset) { index, key in
                Label(LocalizedStringKey(key), systemImage: index <= current ? "\(index + 1).circle.fill" : "\(index + 1).circle")
                    .foregroundStyle(index <= current ? Color.primary : Color.secondary)
            }
        } footer: {
            if let sentence = stepsSentence { Text(verbatim: sentence) }
        }
        if current < 2 { samples }
        if current == 2 { answers }
        if raw["solved"].bool == true {
            Section { Label("playkit.result.passed", systemImage: "checkmark.circle") }
        } else if (raw["attempts"].integer ?? 0) > 0 {
            Section { Label("playkitLegacy.blind.tryAgain", systemImage: "arrow.clockwise") }
        }
    }

    /// MP `bt__cups`: one cup per option, only its letter on it (a blind tasting never names the cup).
    @ViewBuilder private var samples: some View {
        Section {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { cups }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 12) { cups }
            }
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
            if current == 0 {
                Button {
                    stage = 1
                } label: {
                    Text("playkit.blind.got").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!context.enabled)
                .sensoryFeedback(.impact(weight: .light), trigger: stage)
                .accessibilityIdentifier("playkit.blindTaste.got")
            } else {
                Button {
                    peeked = false
                    eyesClosed = true
                } label: {
                    Label("playkit.blind.closeEyes", systemImage: "eye.slash").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!context.enabled)
                .accessibilityIdentifier("playkit.blindTaste.closeEyes")
                .fullScreenCover(isPresented: $eyesClosed) {
                    BlindTasteEyesClosedView { tasted in
                        eyesClosed = false
                        if tasted { stage = 2 } else { peeked = true }
                    }
                }
                if peeked {
                    Label("playkit.blind.peeked", systemImage: "eye")
                        .font(.footnote).foregroundStyle(CYColor.warningText)
                }
            }
        }
    }

    private var cups: some View {
        ForEach(context.projection.options) { option in
            VStack(spacing: 4) {
                Image(systemName: "cup.and.saucer.fill").font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
                Text(verbatim: option.id).font(.headline)
            }
        }
    }

    /// MP `bt__opts`: 刚才那杯是哪一种？ then one row per option (letter + name); pick, change, then 确认选择.
    @ViewBuilder private var answers: some View {
        Section {
            Picker(selection: pick) {
                ForEach(context.projection.options) { option in
                    Text(verbatim: "\(option.id) · \(option.label)")
                        .accessibilityIdentifier("playkit.blindTaste.option." + option.id)
                        .tag(option.id)
                }
            } label: {
                Text("playkitLegacy.blind.question")
            }
            .pickerStyle(.inline)
            .labelsHidden()
            .disabled(!context.enabled)
        } header: {
            Text("playkitLegacy.blind.question")
        } footer: {
            if let xp = raw["xpLabel"].text, !xp.isEmpty { Text(verbatim: xp) }
        }
    }
}

/// MP `bt__dark`: the screen goes black, a breathing ring counts 3 → 好. Opening before the count ends is a peek.
/// MP holds a press; native closes and opens with a tap (the MP's own screen-reader path, `onEyesTap`).
@MainActor struct BlindTasteEyesClosedView: View {
    let onOpen: (Bool) -> Void
    @State private var closedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let tasteSeconds = 3

    var body: some View {
        TimelineView(.periodic(from: closedAt, by: 1)) { timeline in
            let left = max(0, Self.tasteSeconds - Int(timeline.date.timeIntervalSince(closedAt)))
            VStack(spacing: 24) {
                ZStack {
                    Circle().strokeBorder(.white.opacity(0.35), lineWidth: 2)
                        .scaleEffect(reduceMotion ? 1 : (left % 2 == 0 ? 1.08 : 0.92))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 1), value: left)
                    if left > 0 {
                        Text(verbatim: "\(left)").font(.largeTitle.bold()).monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    } else {
                        Text("playkit.blind.ready").font(.largeTitle.bold())
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 120, height: 120)
                Text(left > 0 ? LocalizedStringKey("playkit.blind.dontPeek") : LocalizedStringKey("playkit.blind.openEyes"))
                    .font(.headline).foregroundStyle(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
            .contentShape(Rectangle())
            .onTapGesture { onOpen(left == 0) }
            .sensoryFeedback(.impact(weight: .medium), trigger: left == 0)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onOpen(left == 0) }
        }
        .ignoresSafeArea()
        .statusBarHidden()
        .onAppear { closedAt = Date() }
    }
}
