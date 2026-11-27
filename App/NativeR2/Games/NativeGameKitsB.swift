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

    /// The one prominent action. Camera, branch, hidden and music keep their actions in the
    /// kit (multi-step capture, a confirmation dialog, a tap on the scene, playback only).
    var nativeKitSubmitB: NativeGameSubmit? {
        switch kind {
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
        case .blindTaste:
            guard raw["solved"].bool != true, !projection.complete else { return nil }
            return nativeSubmit("SUBMIT_BLIND_TASTE", ["key": .string(selected.first ?? "")], valid: !selected.isEmpty)
        default:
            return nil
        }
    }

    // MARK: hidden (tap the spot on the scene; the server judges the point)

    @ViewBuilder var nativeHiddenObjectB: some View {
        let found = Set((raw["foundIds"].array ?? []).compactMap(\.text))
        let targets = PlayKitOption.read(raw["targets"])
        if !targets.isEmpty {
            Section {
                ForEach(targets) { target in
                    let done = found.contains(target.id) || target.raw["found"].bool == true
                    Label {
                        Text(verbatim: target.label)
                    } icon: {
                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    }
                    .accessibilityAddTraits(done ? .isSelected : [])
                }
            } header: {
                Text("nativeR2.gamesB.hidden.targets")
            }
        }
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
        } footer: {
            Text("playkit.hidden.hint")
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
