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
                    // MP `cf__big`: 正面还是反面？ before the flip, 翻着… while the server answers.
                    Text(context.busy ? "playkit.coin.waiting" : "playkit.coin.idle").font(.body).foregroundStyle(.secondary)
                } else {
                    faceLabel(key).font(.title.bold())
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
            // The flip itself is the shell's bottom button (`nativeKitSubmitB`); a shake does the same.
            .cyOnShake(enabled: context.enabled) { flip() }
            .sensoryFeedback(.impact, trigger: flips)
            .sensoryFeedback(.success, trigger: key, condition: CYHapticTransition.nonEmpty)
        } header: {
            // MP `cf__k`: the server `kicker`, default 抛一次，认结果.
            if let kicker = raw["kicker"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !kicker.isEmpty {
                Text(verbatim: kicker)
            } else {
                Text("playkit.coin.kicker")
            }
        } footer: {
            if context.enabled { Label("playkit.coin.shakeHint", systemImage: "iphone.gen3.radiowaves.left.and.right") }
        }
        Section {
            ForEach(["heads", "tails"], id: \.self) { face in
                LabeledContent {
                    Text(verbatim: raw[face]["action"].text ?? "").foregroundStyle(.secondary)
                } label: {
                    Label { faceLabel(face) } icon: { Image(systemName: Self.symbol(face)) }
                }
                .foregroundStyle(face == key ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
            }
        }
    }
    /// MP `headsLabel` / `tailsLabel`: the merchant's face name, default 正面 / 反面.
    private func faceLabel(_ face: String) -> Text {
        let label = raw[face]["label"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !label.isEmpty { return Text(verbatim: label) }
        return Text(face == "heads" ? "playkit.coin.heads" : "playkit.coin.tails")
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
    private var kicker: String? {
        let text = raw["kicker"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
    var body: some View {
        if raw["mode"].text == "d20" { d20Body } else { d6Body }
    }

    // MP `dz`: kicker → dice → sum → sub line (task / 摇到 N / two-dice total) → hint. No face list (MP: merchant data).
    @ViewBuilder private var d6Body: some View {
        let values = (raw["pips"].array ?? []).compactMap(\.integer).filter { (1...6).contains($0) }
        let count = raw["diceCount"].integer == 2 ? 2 : 1
        Section {
            // One row: shake and haptics must attach once, not once per List row.
            VStack(spacing: 12) {
                HStack(spacing: 16) {
                    if values.isEmpty {
                        ForEach(0..<count, id: \.self) { _ in
                            Image(systemName: "square")
                                .resizable().scaledToFit().frame(width: symbolSize, height: symbolSize)
                                .foregroundStyle(.secondary)
                                .symbolEffect(.pulse, isActive: context.busy)
                        }
                    } else {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            Image(systemName: "die.face.\(value).fill")
                                .resizable().scaledToFit().frame(width: symbolSize, height: symbolSize)
                                .foregroundStyle(.tint)
                                .contentTransition(.symbolEffect(.replace))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .accessibilityHidden(true)
                if !values.isEmpty {
                    Text(verbatim: String(values.reduce(0, +)))
                        .font(.largeTitle.bold()).monospacedDigit()
                        .contentTransition(.numericText())
                        .accessibilityIdentifier("playkit.dice.total")
                }
                subLine(values).font(.body).multilineTextAlignment(.center)
                    .foregroundStyle(values.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("playkit.dice.face")
            // The roll itself is the shell's bottom button (`nativeKitSubmitB`); a shake does the same.
            .cyOnShake(enabled: context.enabled) { roll() }
            .sensoryFeedback(.impact, trigger: rolls)
            .sensoryFeedback(.success, trigger: values, condition: CYHapticTransition.nonEmpty)
        } header: {
            // MP `dz__k`: the server `kicker`, default 掷到几就做第几件事.
            if let kicker { Text(verbatim: kicker) } else { Text("playkit.dice.kicker") }
        } footer: {
            // MP `dz__hint`: 摇一摇手机 before the roll, 再摇一次 after it.
            if context.enabled {
                Label(values.isEmpty ? LocalizedStringKey("playkit.coin.shakeHint") : LocalizedStringKey("playkit.dice.again"), systemImage: "iphone.gen3.radiowaves.left.and.right")
            }
        }
    }
    /// MP `sub`: one die → the merchant task for that face, else 摇到 N; two dice → only the total counts.
    private func subLine(_ values: [Int]) -> Text {
        if values.isEmpty { return Text("playkit.dice.idle") }
        if values.count == 1, let pip = values.first {
            let faces = raw["faces"].array ?? []
            if faces.indices.contains(pip - 1), let task = faces[pip - 1].text?.trimmingCharacters(in: .whitespacesAndNewlines), !task.isEmpty {
                return Text(verbatim: task)
            }
            return Text("playkit.dice.rolled \(pip)")
        }
        return Text("playkit.dice.sumLine \(values.map(String.init).joined(separator: " + "))")
    }

    // MP `d20`: kicker → meta (掷法 · DC · 加值) → die → outcome (total + result text, 检定成功 / 失败). No shake (MP).
    @ViewBuilder private var d20Body: some View {
        let values = (raw["pips"].array ?? []).compactMap(\.integer)
        let rolled = raw["rolled"].bool == true
        Section {
            LabeledContent("playkit.d20.rollMode") { rollModeLabel }
            if let dc = raw["dc"].integer {
                LabeledContent("playkit.dice.target") { Text(verbatim: String(dc)).monospacedDigit() }
            }
            let modifier = raw["modifier"].integer ?? 0
            LabeledContent("playkit.d20.modifier") {
                Text(verbatim: modifier >= 0 ? "+\(modifier)" : String(modifier)).monospacedDigit()
            }
        } header: {
            if let kicker { Text(verbatim: kicker) } else { Text("playkit.d20.kicker") }
        }
        Section {
            VStack(spacing: 12) {
                if values.isEmpty {
                    Image(systemName: "dice")
                        .resizable().scaledToFit().frame(width: symbolSize, height: symbolSize)
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse, isActive: context.busy)
                        .accessibilityHidden(true)
                } else {
                    HStack(spacing: 16) {
                        ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                            Text(verbatim: String(value))
                                .cyText(.dataXL)
                                .monospacedDigit()
                                .foregroundStyle(value == raw["kept"].integer || values.count == 1 ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                if rolled, let total = context.projection.diceTotal {
                    LabeledContent("playkit.dice.total") {
                        Text(verbatim: String(total)).font(.title2.bold()).monospacedDigit().contentTransition(.numericText())
                    }
                    .accessibilityIdentifier("playkit.dice.total")
                    if let success = raw["success"].bool {
                        Label(success ? LocalizedStringKey("playkit.d20.success") : LocalizedStringKey("playkit.d20.failure"),
                              systemImage: success ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(success ? Color.green : Color.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let action = raw["action"].text, !action.isEmpty {
                        Text(verbatim: action).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .sensoryFeedback(.success, trigger: values, condition: CYHapticTransition.nonEmpty)
        }
    }
    private var rollModeLabel: Text {
        switch raw["rollMode"].text {
        case "advantage": return Text("playkit.d20.advantage")
        case "disadvantage": return Text("playkit.d20.disadvantage")
        default: return Text("playkit.d20.normal")
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
            // MP `dk__card`: every drawn card is tagged 这一关 (title + body); the newest one is the current task.
            ForEach(Array(cards.enumerated()), id: \.offset) { index, card in
                VStack(alignment: .leading, spacing: 4) {
                    Label("playkit.random.thisRound", systemImage: index == cards.count - 1 ? "sparkles" : "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(index == cards.count - 1 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    if let label = card["label"].text { Text(verbatim: label).font(.headline) }
                    if let content = card["content"].text { Text(verbatim: content).font(.body).foregroundStyle(.secondary) }
                }
                .accessibilityElement(children: .combine)
            }
            // MP: the rest of the deck stays face down (「?」 · 还没翻开); the server never sends what is inside.
            if count > cards.count {
                ForEach(cards.count..<count, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 4) {
                        Label("playkit.random.faceDown", systemImage: "rectangle.portrait")
                            .font(.footnote).foregroundStyle(.secondary)
                        Text(verbatim: "?").font(.headline).foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("playkit.random.faceDown"))
                }
            }
        } header: {
            if let name = raw["deckName"].text { Text(verbatim: name) }
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
                            .cyText(.dataXL)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(maxWidth: .infinity)
                    } label: {
                        Text(verbatim: "D20")
                    }
                    .accessibilityIdentifier("journey.check.d20")
                    .sensoryFeedback(.success, trigger: model.receipt?.success == true, condition: CYHapticTransition.turnedOn)
                    .sensoryFeedback(.warning, trigger: model.receipt?.success == false, condition: CYHapticTransition.turnedOn)
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
                        .sensoryFeedback(.impact, trigger: rolls)
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
