import SwiftUI

// Native r2 games-b, Template 5: Chance (one big symbol plus one button).
// Apple reference: Clock > Timer (one large value, one prominent button) and SF Symbols effects.
// The server decides every outcome (FLIP_COIN, ROLL_DICE, DRAW, SUBMIT_PREDICT, check roll / reroll / settle);
// the symbol only plays out the server's answer. Shake to trigger stays `cyOnShake` (no permission).

/// Big symbol size that follows Dynamic Type (no fixed point size).
private struct ChanceSymbolSize {
    static let base: CGFloat = 96
}

// MARK: - coinflip

@MainActor struct ChanceCoinFlipKit: View {
    let context: GamesBKitContext
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = ChanceSymbolSize.base
    @State private var flips = 0
    private var raw: PlayWireValue { context.segment }
    private var faceKey: String {
        let side = (raw["side"].text ?? "").uppercased()
        if ["HEADS", "H", "正面"].contains(side) { return "heads" }
        if ["TAILS", "T", "反面"].contains(side) { return "tails" }
        return ""
    }
    private static func symbol(_ face: String) -> String {
        switch face {
        case "heads": return "sun.max.circle.fill"
        case "tails": return "moon.circle.fill"
        default: return "circle.dashed"
        }
    }
    var body: some View {
        let key = faceKey
        Section {
            VStack(spacing: 12) {
                Image(systemName: Self.symbol(key))
                    .resizable().scaledToFit().frame(width: symbolSize, height: symbolSize)
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.pulse, isActive: context.busy)
                    .accessibilityHidden(true)
                if key.isEmpty {
                    Text("playkit.coin.waiting").font(.body).foregroundStyle(.secondary)
                } else {
                    Text(verbatim: raw[key]["label"].text ?? (raw["side"].text ?? "")).font(.title.bold())
                        .accessibilityIdentifier("playkit.coin.result")
                    if let action = raw[key]["action"].text, !action.isEmpty {
                        Text(verbatim: action).font(.body).multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("playkit.coin.face")
        } header: {
            Text("playkit.coin.kicker")
        }
        Section {
            ForEach(["heads", "tails"], id: \.self) { face in
                LabeledContent {
                    Text(verbatim: raw[face]["action"].text ?? "").foregroundStyle(.secondary)
                } label: {
                    Label { Text(verbatim: raw[face]["label"].text ?? "") } icon: { Image(systemName: Self.symbol(face)) }
                }
                .foregroundStyle(face == key ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
        }
        Section {
            Button {
                flip()
            } label: {
                Label("playkit.coin.flip", systemImage: "circle.circle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!context.enabled)
            .cyOnShake(enabled: context.enabled) { flip() }
            .sensoryFeedback(.impact, trigger: flips)
            .sensoryFeedback(.success, trigger: key) { old, next in !next.isEmpty && old != next }
            .accessibilityIdentifier("playkit.coin.flip")
        } footer: {
            if context.enabled { Label("playkit.coin.shakeHint", systemImage: "iphone.gen3.radiowaves.left.and.right") }
        }
    }
    private func flip() {
        guard context.enabled else { return }
        flips += 1
        context.submit("FLIP_COIN")
    }
}

// MARK: - diceroll

@MainActor struct ChanceDiceRollKit: View {
    let context: GamesBKitContext
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = ChanceSymbolSize.base
    @State private var rolls = 0
    private var raw: PlayWireValue { context.segment }
    var body: some View {
        let values = (raw["pips"].array ?? []).compactMap(\.integer)
        let d20 = raw["mode"].text == "d20"
        Section {
            if values.isEmpty {
                ContentUnavailableView("playkit.dice.waiting", systemImage: "dice")
                    .symbolEffect(.pulse, isActive: context.busy)
                    .accessibilityIdentifier("playkit.dice.waiting")
            } else if d20 {
                GroupBox {
                    HStack(spacing: 16) {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            Text(verbatim: String(value))
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(maxWidth: .infinity)
                } label: {
                    Text(verbatim: "D20")
                }
            } else {
                HStack(spacing: 16) {
                    ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                        if (1...6).contains(value) {
                            Image(systemName: "die.face.\(value).fill")
                                .resizable().scaledToFit().frame(width: symbolSize, height: symbolSize)
                                .foregroundStyle(.tint)
                                .contentTransition(.symbolEffect(.replace))
                                .accessibilityLabel(Text(verbatim: String(value)))
                        } else {
                            Text(verbatim: String(value)).font(.largeTitle.bold()).monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            if let action = raw["action"].text, !action.isEmpty { Text(verbatim: action) }
            if !d20, values.count == 1, let pip = values.first, let faces = raw["faces"].array,
               faces.indices.contains(pip - 1), let task = faces[pip - 1].text {
                Text(verbatim: task)
            }
        } header: {
            if !d20 { Text("playkit.dice.kicker") }
        }
        Section {
            if let total = context.projection.diceTotal {
                LabeledContent("playkit.dice.total") {
                    Text(verbatim: String(total)).font(.title2.bold()).monospacedDigit().contentTransition(.numericText())
                }
                .accessibilityIdentifier("playkit.dice.total")
                if values.count > 1 {
                    Text("playkit.dice.sumLine \(values.map(String.init).joined(separator: " + "))")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            if let kept = raw["kept"].integer { LabeledContent("playkit.dice.kept") { Text(verbatim: String(kept)).monospacedDigit() } }
            if d20, let dc = raw["dc"].integer { LabeledContent("playkit.dice.target") { Text(verbatim: String(dc)).monospacedDigit() } }
            if d20, context.projection.complete, let success = raw["success"].bool {
                Label(success ? "playkit.result.passed" : "playkit.result.notPassed",
                      systemImage: success ? "checkmark.circle" : "info.circle")
            }
        }
        Section {
            Button {
                roll()
            } label: {
                Label("playkit.dice.roll", systemImage: "dice").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!context.enabled)
            .cyOnShake(enabled: context.enabled) { roll() }
            .sensoryFeedback(.impact, trigger: rolls)
            .sensoryFeedback(.success, trigger: values) { old, next in !next.isEmpty && old != next }
            .accessibilityIdentifier("playkit.dice.roll")
        } footer: {
            if context.enabled { Label("playkit.coin.shakeHint", systemImage: "iphone.gen3.radiowaves.left.and.right") }
        }
    }
    private func roll() {
        guard context.enabled else { return }
        rolls += 1
        context.submit("ROLL_DICE")
    }
}

// MARK: - random

@MainActor struct ChanceRandomKit: View {
    let context: GamesBKitContext
    @State private var shownDraw: Int?
    private var raw: PlayWireValue { context.segment }
    private var drawn: [PlayWireValue] { raw["drawn"].array ?? [] }
    var body: some View {
        let count = raw["drawCount"].integer ?? 0
        let cards = drawn
        Section {
            if count == 0, cards.isEmpty {
                ContentUnavailableView("playkit.unavailable", systemImage: "rectangle.stack")
                    .accessibilityIdentifier("playkit.random.empty")
            }
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                VStack(alignment: .leading, spacing: 4) {
                    if index == cards.count - 1 {
                        Label("playkit.random.thisRound", systemImage: "sparkles").font(.footnote).foregroundStyle(.tint)
                    }
                    if let label = card["label"].text { Text(verbatim: label).font(.headline) }
                    if let content = card["content"].text { Text(verbatim: content).font(.body).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .combine)
            }
            if count > cards.count {
                LabeledContent("playkit.random.remaining") { Text(verbatim: String(count - cards.count)).monospacedDigit() }
            }
        } header: {
            if let name = raw["deckName"].text { Text(verbatim: name) }
        }
        Section {
            Button {
                context.submit("DRAW")
            } label: {
                Label("playkit.random.draw", systemImage: "rectangle.stack").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!context.enabled || count <= cards.count)
            .sensoryFeedback(.success, trigger: cards.count) { old, next in next > old }
            .accessibilityIdentifier("playkit.random.draw")
        }
        .onChange(of: cards.count) { old, next in
            // The server answered a draw: show the new card as a medium sheet (MP detail card).
            if next > old { shownDraw = next - 1 }
        }
        .sheet(isPresented: Binding(get: { shownDraw != nil }, set: { if !$0 { shownDraw = nil } })) {
            NavigationStack {
                List {
                    if let index = shownDraw, drawn.indices.contains(index) {
                        let card = drawn[index]
                        Section {
                            if let label = card["label"].text { Text(verbatim: label).font(.title2.bold()) }
                            if let content = card["content"].text { Text(verbatim: content).font(.body) }
                        }
                    }
                }
                .navigationTitle(Text("playkit.random.thisRound"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("nativeR2.gamesB.random.keep") { shownDraw = nil }
                            .accessibilityIdentifier("nativeR2.gamesB.random.keep")
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - predict

@MainActor struct ChancePredictKit: View {
    let context: GamesBKitContext
    @State private var confirming = false
    private var raw: PlayWireValue { context.segment }
    private var pick: Binding<String> {
        Binding(get: { context.selection.wrappedValue.first ?? "" },
                set: { context.selection.wrappedValue = $0.isEmpty ? [] : [$0]; context.markDirty() })
    }
    private func label(_ id: String) -> String { context.projection.options.first { $0.id == id }?.label ?? id }
    var body: some View {
        if let mine = raw["myOptionKey"].text, !mine.isEmpty {
            Section {
                LabeledContent {
                    Text(verbatim: label(mine))
                } label: {
                    Label("playkit.predict.mine", systemImage: "lock.fill")
                }
                .accessibilityIdentifier("playkit.predict.sealed")
            }
        } else {
            Section {
                Picker(selection: pick) {
                    ForEach(context.projection.options) { option in
                        Text(verbatim: option.label).tag(option.id)
                    }
                } label: {
                    Text("nativeR2.gamesB.predict.pick")
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(!context.enabled)
            } footer: {
                Text("nativeR2.gamesB.predict.lockedOnceSet")
            }
            Section {
                Button {
                    confirming = true
                } label: {
                    Text("nativeR2.gamesB.predict.commit").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!context.enabled || pick.wrappedValue.isEmpty)
                .accessibilityIdentifier("playkit.submit.predict")
            }
            .confirmationDialog("nativeR2.gamesB.predict.lockedOnceSet", isPresented: $confirming, titleVisibility: .visible) {
                Button("nativeR2.gamesB.predict.commit") {
                    context.submit("SUBMIT_PREDICT", ["optionKey": .string(pick.wrappedValue)])
                }
                Button("playkit.cancel", role: .cancel) {}
            } message: {
                Text(verbatim: label(pick.wrappedValue))
            }
        }
        Section {
            if let status = raw["settleStatus"].integer {
                if status == 2 {
                    Label("playkit.predict.voided", systemImage: "arrow.uturn.backward.circle")
                } else if status == 1 {
                    let won = raw["won"].bool == true
                    Label(won ? "playkit.predict.won" : "playkit.predict.lost", systemImage: won ? "checkmark.seal.fill" : "xmark.seal")
                    let answer = raw["settledOption"].text ?? ""
                    LabeledContent("playkit.predict.answer") { Text(verbatim: label(answer)) }
                } else {
                    Label("playkit.predict.wait", systemImage: "hourglass")
                }
            }
            if let days = raw["revealDays"].integer, days >= 0 {
                LabeledContent("playkit.predict.revealDays") { Text(verbatim: String(days)).monospacedDigit() }
            }
            if let hour = raw["revealHour"].integer, (0...23).contains(hour) {
                LabeledContent("playkit.predict.revealHour") { Text(verbatim: String(hour)).monospacedDigit() }
            }
        }
    }
}

// MARK: - journey-check

/// Native replacement for `PlayJourneyCheckView`. Same `JourneyCheckCoordinator` calls
/// (`prepare(.roll / .reroll / .settle)`, `close`, `reopen`); the hold-to-charge button,
/// the canvas D20, the tier strip and the hand-drawn DC track are replaced by system controls.
/// Lives inside the story `List`, so every block is a `Section`.
@MainActor struct ChanceJourneyCheckView: View {
    @Bindable var model: JourneyCheckCoordinator
    let nodeDone: Bool
    @State private var rolls = 0
    var body: some View {
        Group {
            JourneyRoleViewSection(model: model.roleContent)
            if model.visible, let problem = model.problem {
                Section {
                    Text(verbatim: problem.skill).font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("journey.check.stage")
                    if let lit = JourneyCheckTier(raw: problem.tier) {
                        ForEach(JourneyCheckTier.allCases, id: \.self) { tier in
                            Label(LocalizedStringKey("journey.tier." + tier.rawValue),
                                  systemImage: tier == lit ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(tier == lit ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                .accessibilityAddTraits(tier == lit ? .isSelected : [])
                        }
                    } else {
                        LabeledContent("journey.tier.label") { Text(verbatim: problem.tier) }
                    }
                    if problem.advantage { Label("journey.advantage", systemImage: "plus.circle") }
                    if problem.disadvantage { Label("journey.disadvantage", systemImage: "minus.circle") }
                } header: {
                    Label("journey.check.title", systemImage: "dice.fill")
                }
                if !problem.mods.isEmpty { Section { modifiers(problem.mods) } }
                Section {
                    GroupBox {
                        Text(verbatim: model.receipt?.total.map(String.init) ?? "—")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                    } label: {
                        Text(verbatim: "D20")
                    }
                    .accessibilityIdentifier("journey.check.d20")
                    if let receipt = model.receipt {
                        if !receipt.dice.isEmpty {
                            LabeledContent("journey.dice") {
                                Text(verbatim: receipt.dice.map(String.init).joined(separator: " · ")).monospacedDigit()
                            }
                        }
                        number("journey.kept", receipt.kept)
                        number("journey.dc", receipt.dc)
                        if let dc = receipt.dc, let total = receipt.total {
                            Gauge(value: Double(min(max(total, 0), 20)), in: 0...20) {
                                Text("journey.dc")
                            } currentValueLabel: {
                                Text(verbatim: "\(total) / \(dc)").monospacedDigit()
                            }
                            .accessibilityLabel(Text("journey.track \(total) \(dc)"))
                        }
                        if let success = receipt.success {
                            Label(success ? "journey.success" : "journey.failure",
                                  systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        }
                        if !receipt.nat.isEmpty { Text(verbatim: receipt.nat).font(.footnote) }
                        number("journey.hp", receipt.hp)
                        number("journey.luck", receipt.luck)
                    }
                }
                if let receipt = model.receipt {
                    if !receipt.mods.isEmpty { Section { modifiers(receipt.mods) } }
                    if receipt.settled || receipt.exhausted {
                        Section {
                            if receipt.settled, let success = receipt.success {
                                Label(success ? "journey.settled.passed" : "journey.settled.missed",
                                      systemImage: success ? "checkmark.seal.fill" : "xmark.seal")
                                    .font(.headline)
                                    .accessibilityIdentifier("journey.check.settledVerdict")
                            }
                            if receipt.exhausted { Text("journey.exhausted").foregroundStyle(.secondary) }
                            if receipt.settled {
                                if !receipt.text.isEmpty { Text(verbatim: receipt.text) }
                                if !receipt.failCostLabel.isEmpty { LabeledContent("journey.cost") { Text(verbatim: receipt.failCostLabel) } }
                            }
                        }
                    }
                }
                Section {
                    if model.unknown {
                        Text("journey.unknown")
                        Button("journey.recover") { try? model.prepare(.settle, recoverUnknown: true) }
                            .buttonStyle(.bordered)
                            .disabled(!model.canRecover)
                            .accessibilityIdentifier("journey.check.recover")
                    } else if model.receipt == nil {
                        // MP 「按住摇骰」 becomes one tap (Apple's primary action); a shake also rolls.
                        Button {
                            roll()
                        } label: {
                            Label("journey.roll", systemImage: "dice").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.acting || !model.available)
                        .cyOnShake(enabled: !model.acting && model.available) { roll() }
                        .accessibilityIdentifier("journey.check.roll")
                    } else if model.receipt?.settled == false {
                        if model.receipt?.canReroll == true {
                            Button("journey.reroll") { try? model.prepare(.reroll) }
                                .buttonStyle(.bordered)
                                .controlSize(.large)
                                .disabled(model.acting || !model.available)
                                .accessibilityIdentifier("journey.check.reroll")
                        }
                        Button {
                            try? model.prepare(.settle)
                        } label: {
                            Text("journey.settle").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(model.acting || !model.available)
                        .accessibilityIdentifier("journey.check.settle")
                    }
                    if model.acting { ProgressView("journey.working") }
                    if !model.available { Text("journey.disabled").foregroundStyle(.secondary) }
                    Button("journey.close") { model.close() }
                        .buttonStyle(.borderless)
                        .accessibilityIdentifier("journey.check.close")
                } footer: {
                    if let issue = model.issue {
                        Label { Text(verbatim: issue) } icon: { Image(systemName: "exclamationmark.triangle") }
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("journey.check.error")
                    }
                }
                .sensoryFeedback(.impact, trigger: rolls)
                .sensoryFeedback(.success, trigger: model.receipt?.success) { _, next in next == true }
                .sensoryFeedback(.warning, trigger: model.receipt?.success) { _, next in next == false }
            } else if model.problem != nil && !model.nodeDone {
                Button("journey.check.title") { model.reopen() }.accessibilityIdentifier("journey.check.reopen")
            }
        }
    }
    private func roll() {
        guard !model.acting, model.available else { return }
        rolls += 1
        try? model.prepare(.roll)
    }
    @ViewBuilder private func number(_ key: LocalizedStringKey, _ value: Int?) -> some View {
        if let value { LabeledContent(key) { Text(verbatim: String(value)).monospacedDigit() } }
    }
    private func modifiers(_ mods: [JourneyCheckMod]) -> some View {
        ForEach(Array(mods.enumerated()), id: \.offset) { _, mod in
            LabeledContent {
                if let value = mod.value { Text(verbatim: value >= 0 ? "+\(value)" : "\(value)").monospacedDigit() }
            } label: {
                Label {
                    Text(verbatim: mod.label)
                    Text(mod.active ? "journey.active" : "journey.inactive")
                } icon: {
                    Image(systemName: mod.active ? "checkmark.circle.fill" : "circle")
                }
            }
        }
    }
}
