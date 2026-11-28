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
        case .dailySign: ChoiceDailySignKit(context: gamesBContext)
        case .hiddenObject: nativeHiddenObjectB
        case .blindTaste: ChoiceBlindTasteKit(context: gamesBContext)
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
            guard !projection.complete else { return nil }
            return nativeSubmit("CLAIM_DAILY_SIGN", ["text": .string(text), "photoUrl": .string(avatarURL)],
                                valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                title: Text("nativeR2.gamesB.daily.accept"))
        case .musicCorner:
            // MP 继续: the music corner is never judged, so it can always be left (walk-through A25).
            guard presentation != .inline else { return nil }
            return NativeGameSubmit(title: Text("playkit.music.continue"), enabled: true,
                                    identifier: "playkit.musicCorner.continue", action: { dismiss() })
        case .blindTaste:
            guard raw["solved"].bool != true, !projection.complete else { return nil }
            return nativeSubmit("SUBMIT_BLIND_TASTE", ["key": .string(selected.first ?? "")], valid: !selected.isEmpty)
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

/// Collect, taste with eyes closed, answer: three numbered rows, then an inline picker.
/// Submit (`SUBMIT_BLIND_TASTE {key}`) is the shell's bottom button.
@MainActor struct ChoiceBlindTasteKit: View {
    let context: GamesBKitContext
    private var raw: PlayWireValue { context.segment }
    private var pick: Binding<String> {
        Binding(get: { context.selection.wrappedValue.first ?? "" },
                set: { context.selection.wrappedValue = $0.isEmpty ? [] : [$0]; context.markDirty() })
    }
    private var stepsSentence: String? {
        if let steps = raw["steps"].text, !steps.isEmpty { return steps }
        let joined = (raw["steps"].array ?? []).compactMap(\.text).joined(separator: ", ")
        return joined.isEmpty ? nil : joined
    }
    var body: some View {
        Section {
            ForEach(Array(["playkitLegacy.blind.step1", "playkitLegacy.blind.step2", "playkitLegacy.blind.step3"].enumerated()), id: \.offset) { index, key in
                Label(LocalizedStringKey(key), systemImage: "\(index + 1).circle")
            }
        } footer: {
            if let sentence = stepsSentence { Text(verbatim: sentence) }
        }
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
        if raw["solved"].bool == true {
            Section { Label("playkit.result.passed", systemImage: "checkmark.circle") }
        } else if (raw["attempts"].integer ?? 0) > 0 {
            Section { Label("playkitLegacy.blind.tryAgain", systemImage: "arrow.clockwise") }
        }
    }
}
