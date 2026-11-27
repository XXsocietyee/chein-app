import SwiftUI

extension PlayKitScreen {
    @ViewBuilder var coinFace: some View {
        let side = (raw["side"].text ?? "").uppercased()
        let key = ["HEADS", "H", "正面"].contains(side) ? "heads" : ["TAILS", "T", "反面"].contains(side) ? "tails" : ""
        Text("playkit.coin.kicker").cyText(.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        Image(systemName: key.isEmpty ? "circle.dashed" : "circle.inset.filled").resizable().scaledToFit().frame(width: 100, height: 100).frame(maxWidth: .infinity).accessibilityHidden(true)
        if !key.isEmpty {
            Text(verbatim: raw[key]["label"].text ?? side).cyText(.pageTitle).frame(maxWidth: .infinity)
            if let action = raw[key]["action"].text, !action.isEmpty { Text(verbatim: action) }
        } else { Text("playkit.coin.waiting") }
        HStack(alignment: .top) {
            ForEach(["heads", "tails"], id: \.self) { face in
                VStack(alignment: .leading) {
                    Text(verbatim: raw[face]["label"].text ?? "").cyText(.cardTitle)
                    if let action = raw[face]["action"].text { Text(verbatim: action) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        CYPillButton("playkit.coin.flip", systemImage: "circle.circle") {
            UIKitHapticsDriver.ensureInstalled()
            HapticsService.shared.play(.diceRoll)
            prepare("FLIP_COIN")
        }.disabled(!enabled)
            // 摇一摇抛硬币: same action as the button, which stays as the fallback.
            .cyOnShake(enabled: enabled) {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.diceRoll)
                prepare("FLIP_COIN")
            }
            .cyHapticEvent(.diceLand, trigger: key) { old, next in !next.isEmpty && old != next }
        if enabled { shakeHint("playkit.coin.shakeHint") }
    }
    @ViewBuilder var diceFaces: some View {
        let values = (raw["pips"].array ?? []).compactMap(\.integer)
        let d20 = raw["mode"].text == "d20"
        if !d20 { Text("playkit.dice.kicker").cyText(.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
        HStack {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                if !d20 && (1...6).contains(value) { Image(systemName: "die.face.\(value).fill").resizable().scaledToFit().frame(width: 72, height: 72).accessibilityLabel(Text(verbatim: String(value))) }
                else { Text(verbatim: String(value)).cyText(.dataXL).padding().background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16)) }
            }
        }.frame(maxWidth: .infinity)
        if values.isEmpty {
            ContentUnavailableView("playkit.dice.waiting", systemImage: "dice")
                .accessibilityIdentifier("playkit.dice.waiting")
        }
        if let action = raw["action"].text, !action.isEmpty { Text(verbatim: action) }
        if let total = projection.diceTotal {
            // Big total, then "5 + 4" under it, as the mini-program shows after a roll.
            VStack(spacing: CYSpacing.xs) {
                Text(verbatim: String(total)).cyText(.display).monospacedDigit()
                    .accessibilityLabel(Text("playkit.dice.total")).accessibilityValue(Text(verbatim: String(total)))
                    .accessibilityIdentifier("playkit.dice.total")
                if values.count > 1 {
                    Text("playkit.dice.sumLine \(values.map(String.init).joined(separator: " + "))").cyText(.meta).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity)
        }
        if let kept = raw["kept"].integer { LabeledContent("playkit.dice.kept") { Text(verbatim: String(kept)) } }
        if d20, let dc = raw["dc"].integer { LabeledContent("playkit.dice.target") { Text(verbatim: String(dc)) } }
        if d20, projection.complete, let success = raw["success"].bool { Text(success ? "playkit.result.passed" : "playkit.result.notPassed") }
        if !d20, values.count == 1, let pip = values.first, let faces = raw["faces"].array, faces.indices.contains(pip - 1), let task = faces[pip - 1].text { Text(verbatim: task) }
        CYPillButton("playkit.dice.roll", systemImage: "dice") {
            UIKitHapticsDriver.ensureInstalled()
            HapticsService.shared.play(.diceRoll)
            prepare("ROLL_DICE")
        }.disabled(!enabled)
            .cyOnShake(enabled: enabled) {
                UIKitHapticsDriver.ensureInstalled()
                HapticsService.shared.play(.diceRoll)
                prepare("ROLL_DICE")
            }
            .cyHapticEvent(.diceLand, trigger: values) { old, next in !next.isEmpty && old != next }
        if enabled { shakeHint("playkit.coin.shakeHint") }
    }
    func shakeHint(_ key: LocalizedStringKey) -> some View {
        Label(key, systemImage: "iphone.gen3.radiowaves.left.and.right").cyText(.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }
    @ViewBuilder var randomDeck: some View {
        if let name = raw["deckName"].text { Text(verbatim: name).cyText(.meta).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
        let drawn = raw["drawn"].array ?? [], count = raw["drawCount"].integer ?? 0
        ForEach(Array(drawn.enumerated()), id: \.offset) { index, card in
            VStack(alignment: .leading, spacing: 12) {
                if index == drawn.count - 1 { CYStatusChip("playkit.random.thisRound", tone: .neutral).singleLine() }
                else { Text(verbatim: "\(index + 1)").cyText(.meta) }
                if let label = card["label"].text { Text(verbatim: label).cyText(.sheetTitle) }
                if let content = card["content"].text { Text(verbatim: content) }
            }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        if count == 0, drawn.isEmpty {
            ContentUnavailableView("playkit.unavailable", systemImage: "rectangle.stack")
                .accessibilityIdentifier("playkit.random.empty")
        }
        if count > drawn.count {
            Image(systemName: "rectangle.stack").resizable().scaledToFit().frame(width: 80, height: 80).frame(maxWidth: .infinity).accessibilityHidden(true)
            LabeledContent("playkit.random.remaining") { Text(verbatim: String(count - drawn.count)) }
        }
        CYPillButton("playkit.random.draw") { prepare("DRAW") }.disabled(!enabled || count <= drawn.count)
    }
    @ViewBuilder var dailySignForm: some View {
        PlayKitDailySignTicket(segment: raw)
        artwork(raw["photoUrl"].text)
        let limit = PlayKitShortMessageLimit.resolve(raw["textMax"])
        TextField("playkit.daily.message", text: textBinding(limit: limit), axis: .vertical).textFieldStyle(.roundedBorder).disabled(!enabled)
        Text("playkit.daily.audience").cyText(.bodyCompact)
        submitButton("CLAIM_DAILY_SIGN", payload: ["text": .string(text), "photoUrl": .string(avatarURL)], valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    @ViewBuilder var walkProgress: some View {
        let goal = raw["goal"].integer.flatMap { $0 > 0 ? $0 : nil }
        if let steps = raw["todaySteps"].integer, steps >= 0 {
            // Mini-program walk screen: a lantern "还差 N 步" hero, the bar with "a / b · p%", then stat tiles.
            VStack(spacing: CYSpacing.sm) {
                if let goal {
                    Text("playkit.walk.remainingLabel").cyText(.meta)
                    Text(verbatim: max(0, goal - steps).formatted()).cyText(.display).monospacedDigit()
                        .accessibilityIdentifier("playkit.walk.remaining")
                    Text("playkit.walk.stepsUnit").cyText(.meta)
                    ProgressView(value: Double(min(steps, goal)), total: Double(goal)).tint(CYNight.lantern)
                        .accessibilityLabel(Text("playkit.walk.progress"))
                    Text(verbatim: "\(steps.formatted()) / \(goal.formatted()) · \(min(100, steps * 100 / goal))%")
                        .cyText(.caption).monospacedDigit()
                } else {
                    Text(verbatim: steps.formatted()).cyText(.display).monospacedDigit()
                }
            }
            .foregroundStyle(CYNight.lantern)
            .frame(maxWidth: .infinity).padding(CYSpacing.lg)
            .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(CYNight.lantern.opacity(0.35)))
            HStack(spacing: CYSpacing.sm) {
                walkTile("playkit.walk.goal", goal.map { $0.formatted() } ?? "—")
                walkTile("playkit.walk.walked", steps.formatted())
                walkTile("playkit.walk.co2", raw["co2Kg"].double.map { String(format: "%.2f kg", $0) } ?? "—")
            }
        } else {
            Text("playkit.walk.noReading")
            if let goal { LabeledContent("playkit.walk.goal") { Text(verbatim: goal.formatted()) } }
        }
        // No native pedometer value substitutes for the service's WeChat encrypted proof, so there is
        // no sync button here; the reason is stated once.
        CYStatusChip("playkit.walk.providerGate", tone: .neutral, systemImage: "figure.walk")
            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
    func walkTile(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(title).cyText(.caption).foregroundStyle(.secondary)
            Text(verbatim: value).cyText(.numericBody).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(CYSpacing.md)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder var bingoBoard: some View {
        let board = PlayKitBingoBoard(raw)
        // Reward banner above the board: "连成一条线 · <lineReward>".
        if let line = raw["lineReward"].text, !line.isEmpty {
            Text("playkit.bingo.lineBanner \(line)").cyText(.cardTitle)
                .frame(maxWidth: .infinity).padding(CYSpacing.md)
                .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(CYNight.tilePink))
                .accessibilityIdentifier("playkit.bingo.lineBanner")
        }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top), count: 3), spacing: 12) {
            ForEach(0..<9, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(verbatim: String(index + 1)).cyText(.meta)
                        Spacer()
                        Image(systemName: board.filled.contains(index) ? "checkmark.circle.fill" : "circle")
                    }
                    Text(verbatim: board.title(at: index)).cyText(.cardTitle).fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: board.instruction(at: index)).cyText(.meta).fixedSize(horizontal: false, vertical: true)
                    if board.linePositions.contains(index) { Text("playkit.bingo.inLine").cyText(.meta) }
                }.padding(10).frame(maxWidth: .infinity, minHeight: 130, alignment: .topLeading)
                    .background(board.filled.contains(index) ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .combine)
                    .accessibilityValue(Text(board.filled.contains(index) ? "playkit.bingo.filled" : "playkit.bingo.empty"))
            }
        }
        Text("playkit.bingo.filledCount \(board.filled.count)").cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
            .frame(maxWidth: .infinity).accessibilityIdentifier("playkit.bingo.filledCount")
        Text("playkit.bingo.footnote").cyText(.body).foregroundStyle(.secondary).frame(maxWidth: .infinity)
        LabeledContent("playkit.bingo.lines") { Text(verbatim: String(board.completedLines.count)) }
        if let full = raw["fullReward"].text, !full.isEmpty { LabeledContent("playkit.bingo.fullReward") { Text(verbatim: full) } }
    }
}

/// The thermal "today's city sign" ticket: header with date, departure address and serial,
/// signer and time left, then the line left for you. Missing fields read as an em dash.
@MainActor struct PlayKitDailySignTicket: View {
    let segment: PlayWireValue
    @State private var lineRevealed = false
    @Environment(\.locale) private var locale
    private func value(_ key: String) -> String {
        let text = (segment[key].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "—" : text
    }
    private var divider: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay(Line().stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.separator))
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                Text("playkit.daily.ticketTitle").cyText(.cardTitle)
                Spacer()
                Text(verbatim: value("dateLabel")).cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
            }
            divider
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("playkit.daily.departure").cyText(.caption).foregroundStyle(.secondary)
                    Text(verbatim: value("address")).cyText(.bodyMedium)
                }
                Spacer(minLength: CYSpacing.md)
                VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                    Text("playkit.daily.serial").cyText(.caption).foregroundStyle(.secondary)
                    Text(verbatim: value("serialLabel")).cyText(.dataXL).monospacedDigit()
                    Text("playkit.daily.serialHint").cyText(.caption).foregroundStyle(.secondary)
                }
            }
            divider
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("playkit.daily.signer").cyText(.caption).foregroundStyle(.secondary)
                    Text(verbatim: value("signer")).cyText(.bodyMedium)
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("playkit.daily.leftAt").cyText(.caption).foregroundStyle(.secondary)
                    Text(verbatim: value("leftAt")).cyText(.bodyMedium).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
            divider
            Text("playkit.daily.lineForYou").cyText(.caption).foregroundStyle(.secondary)
            let lines = (segment["lines"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
            CYScratchCard(
                coverLabel: appLocalized("playkit.daily.lineForYou", locale: locale),
                threshold: 0.45,
                revealed: lineRevealed || lines.isEmpty,
                onReveal: { _ in lineRevealed = true }
            ) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if lines.isEmpty { Text(verbatim: "—") }
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in Text(verbatim: line).cyText(.bodyMedium) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(CYSpacing.lg)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityIdentifier("playkit.dailySign.ticket")
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { var path = Path(); path.move(to: CGPoint(x: 0, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return path }
    }
}
