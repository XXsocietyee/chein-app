import SwiftUI

// Template 2 · Sort & match (sort, classify, match, bingo, silentorder).
// Apple reference: Reminders / Settings → Control Center (reorder with drag handles),
// Settings-style menu pickers for pairing, Fitness Awards grid for bingo.
extension PlayKitScreen {

    var nativeItems: [PlayKitOption] { PlayKitOption.read(raw["items"]) }
    var nativeLeft: [PlayKitOption] { PlayKitOption.read(raw["left"]) }
    var nativeRight: [PlayKitOption] { PlayKitOption.read(raw["right"]) }
    var nativeBins: [PlayKitOption] { PlayKitOption.read(raw["bins"]) }

    /// The draft order; a new item list from the server replaces it.
    var nativeSortIDs: [String] {
        let ids = nativeItems.map(\.id)
        return nativeOrder.count == ids.count && Set(nativeOrder) == Set(ids) ? nativeOrder : ids
    }

    /// Only pairs between items the server currently sends; stale picks drop out.
    var nativeCleanPlacement: [String: String] {
        if kind == .match {
            let left = Set(nativeLeft.map(\.id)), right = Set(nativeRight.map(\.id))
            return nativePlacement.filter { left.contains($0.key) && right.contains($0.value) }
        }
        let items = Set(nativeItems.map(\.id)), bins = Set(nativeBins.map(\.id))
        return nativePlacement.filter { items.contains($0.key) && bins.contains($0.value) }
    }

    var nativeReasoningAction: String { kind == .sort ? "SUBMIT_SORT" : kind == .match ? "SUBMIT_MATCH" : "SUBMIT_CLASSIFY" }

    var nativeReasoningPayload: [String: PlayWireValue] {
        if kind == .sort { return ["order": .array(nativeSortIDs.map(PlayWireValue.string))] }
        let placement = nativeCleanPlacement
        if kind == .match {
            return ["pairs": .array(nativeLeft.compactMap { item in placement[item.id].map { .array([.string(item.id), .string($0)]) } })]
        }
        return ["placement": .object(placement.mapValues(PlayWireValue.string))]
    }

    var nativeReasoningSubmit: NativeGameSubmit? {
        guard !projection.complete else { return nil }
        let payload = nativeReasoningPayload
        let title = kind == .sort ? "playkit.sort.submit" : kind == .match ? "playkit.match.submit" : "playkit.classify.submit"
        return nativeSubmit(nativeReasoningAction, payload, valid: nativeValid(nativeReasoningAction, payload),
                            title: Text(LocalizedStringKey(title)))
    }

    func nativeReasoningEdited() {
        reasoningFeedback.markEdited(projection)
        dirty = true
    }

    @ViewBuilder var nativeReasoning: some View {
        switch kind {
        case .sort: nativeSortSection
        case .match: nativeMatchSection
        default: nativeClassifySections
        }
        if let cap = raw["maxAttempts"].integer, cap > 0 {
            Section {
                if let attempts = raw["attempts"].integer, attempts > 0 {
                    LabeledContent { Text(verbatim: String(attempts)).monospacedDigit() } label: { Text("playkit.attempts") }
                }
                LabeledContent { Text(verbatim: String(cap)).monospacedDigit() } label: { Text("playkit.attemptLimit") }
            }
        } else if let attempts = raw["attempts"].integer, attempts > 0 {
            Section {
                LabeledContent { Text(verbatim: String(attempts)).monospacedDigit() } label: { Text("playkit.attempts") }
            }
        }
    }

    /// System drag handles (the list is in edit mode while the kit is open), plus VoiceOver move actions.
    @ViewBuilder var nativeSortSection: some View {
        let ids = nativeSortIDs
        let items = nativeItems
        Section {
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                Label {
                    Text(verbatim: items.first { $0.id == id }?.label ?? id)
                } icon: {
                    Text(verbatim: String(index + 1)).monospacedDigit().foregroundStyle(.secondary)
                }
                .accessibilityAction(named: Text("playkit.sort.up")) { nativeMove(index, by: -1) }
                .accessibilityAction(named: Text("playkit.sort.down")) { nativeMove(index, by: 1) }
                .accessibilityIdentifier("playkit.sort.row." + id)
            }
            .onMove { from, to in
                guard enabled else { return }
                var next = nativeSortIDs
                next.move(fromOffsets: from, toOffset: to)
                nativeOrder = next
                nativeReasoningEdited()
            }
        } header: {
            Text("playkit.sort.instructions")
        }
    }

    func nativeMove(_ index: Int, by delta: Int) {
        var next = nativeSortIDs
        let destination = index + delta
        guard enabled, next.indices.contains(index), next.indices.contains(destination) else { return }
        let value = next.remove(at: index)
        next.insert(value, at: destination)
        nativeOrder = next
        nativeReasoningEdited()
    }

    /// One row per left item, a menu of right items. A right item pairs once; reassigning moves it.
    @ViewBuilder var nativeMatchSection: some View {
        let placement = nativeCleanPlacement
        let right = nativeRight
        Section {
            ForEach(nativeLeft) { item in
                Picker(selection: Binding(get: { placement[item.id] ?? "" }, set: { value in
                    guard enabled, value != (nativeCleanPlacement[item.id] ?? "") else { return }
                    var next = nativeCleanPlacement
                    if value.isEmpty { next.removeValue(forKey: item.id) }
                    else { next = next.filter { $0.key == item.id || $0.value != value }; next[item.id] = value }
                    nativePlacement = next
                    nativeReasoningEdited()
                })) {
                    Text("playkit.choose").tag("")
                    ForEach(right) { option in Text(verbatim: option.label).tag(option.id) }
                } label: {
                    Text(verbatim: item.label)
                }
                .pickerStyle(.menu)
                .disabled(!enabled)
                .accessibilityIdentifier("playkit.match.row." + item.id)
            }
        } header: {
            Text("playkit.match.instructions")
        }
    }

    /// 未分类 on top; each bin is its own section. Swipe to take an item back.
    @ViewBuilder var nativeClassifySections: some View {
        let placement = nativeCleanPlacement
        let items = nativeItems
        let unsorted = items.filter { placement[$0.id] == nil }
        Section {
            ForEach(unsorted) { item in nativeClassifyRow(item) }
        } header: {
            Text("nativeGames.classify.unsorted")
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("playkit.classify.instructions")
                Text("playkit.classify.remainingLine \(unsorted.count)")
                    .accessibilityIdentifier("playkit.classify.remaining")
            }
        }
        ForEach(nativeBins) { bin in
            let placed = items.filter { placement[$0.id] == bin.id }
            if !placed.isEmpty {
                Section {
                    ForEach(placed) { item in
                        nativeClassifyRow(item)
                            .swipeActions(edge: .trailing) {
                                Button("nativeGames.classify.takeBack") {
                                    var next = nativeCleanPlacement
                                    next.removeValue(forKey: item.id)
                                    nativePlacement = next
                                    nativeReasoningEdited()
                                }
                                .disabled(!enabled)
                            }
                    }
                } header: {
                    Text(verbatim: bin.label)
                }
            }
        }
    }

    func nativeClassifyRow(_ item: PlayKitOption) -> some View {
        Picker(selection: Binding(get: { nativeCleanPlacement[item.id] ?? "" }, set: { value in
            guard enabled, value != (nativeCleanPlacement[item.id] ?? "") else { return }
            var next = nativeCleanPlacement
            if value.isEmpty { next.removeValue(forKey: item.id) } else { next[item.id] = value }
            nativePlacement = next
            nativeReasoningEdited()
        })) {
            Text("playkit.choose").tag("")
            ForEach(nativeBins) { bin in Text(verbatim: bin.label).tag(bin.id) }
        } label: {
            Text(verbatim: item.label)
        }
        .pickerStyle(.menu)
        .disabled(!enabled)
        .accessibilityIdentifier("playkit.classify.row." + item.id)
    }

    // MARK: bingo (read only: cells light up from play elsewhere)

    @ViewBuilder var nativeBingo: some View {
        let board = PlayKitBingoBoard(raw)
        if let line = raw["lineReward"].text, !line.isEmpty {
            Section {
                Label { Text("playkit.bingo.lineBanner \(line)") } icon: { Image(systemName: "gift") }
                    .accessibilityIdentifier("playkit.bingo.lineBanner")
            }
        }
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in nativeBingoCell(board, index: index) }
            }
        } footer: {
            Text("playkit.bingo.footnote")
        }
        Section {
            LabeledContent { Text(verbatim: String(board.filled.count) + " / 9").monospacedDigit() } label: { Text("nativeGames.bingo.filled") }
                .accessibilityIdentifier("playkit.bingo.filledCount")
            LabeledContent { Text(verbatim: String(board.completedLines.count)).monospacedDigit() } label: { Text("playkit.bingo.lines") }
            if let full = raw["fullReward"].text, !full.isEmpty {
                LabeledContent { Text(verbatim: full) } label: { Text("playkit.bingo.fullReward") }
            }
        }
    }

    /// A cell explains itself in place: tap shows how to light it (popover; a sheet on iPhone).
    func nativeBingoCell(_ board: PlayKitBingoBoard, index: Int) -> some View {
        let filled = board.filled.contains(index)
        return Button { nativeIndex = index } label: {
            VStack(spacing: 4) {
                Image(systemName: filled ? "checkmark.seal.fill" : "seal").imageScale(.large)
                Text(verbatim: board.title(at: index)).font(.footnote).lineLimit(3).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityValue(Text(filled ? "playkit.bingo.filled" : "playkit.bingo.empty"))
        .accessibilityIdentifier("playkit.bingo.cell.\(index)")
        .popover(isPresented: Binding(get: { nativeIndex == index }, set: { if !$0 { nativeIndex = nil } })) {
            NavigationStack {
                List {
                    Section {
                        Label(filled ? "playkit.bingo.filled" : "playkit.bingo.empty",
                              systemImage: filled ? "checkmark.seal.fill" : "seal")
                        Text(verbatim: board.instruction(at: index)).fixedSize(horizontal: false, vertical: true)
                        if board.linePositions.contains(index) { Text("playkit.bingo.inLine").foregroundStyle(.secondary) }
                    }
                }
                .navigationTitle(Text(verbatim: board.title(at: index)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("nativeGames.done") { nativeIndex = nil } }
                }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: silentorder (a staff-witnessed dare; the clock is a companion, not evidence)

    @ViewBuilder var nativeSilentOrder: some View {
        if let rule = raw["rule"].text, !rule.isEmpty {
            Section { Text(verbatim: rule).font(.headline) }
        }
        Section {
            if let qr = raw["qrUrl"].text, !qr.isEmpty {
                artwork(qr).frame(maxWidth: 220).frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("playkitLegacy.silent.noWitnessCode", systemImage: "qrcode")
            }
        } footer: {
            Text("playkitLegacy.silent.qrCaption")
        }
        .accessibilityIdentifier("playkit.silentOrder.witness")
        NativeGameSilentOrderClock(segment: raw, active: model.isCurrent, onDirty: { dirty = true })
    }

    // MARK: walk (server step reading only; no pedometer substitutes for the proof)

    @ViewBuilder var nativeWalk: some View {
        let goal = raw["goal"].integer.flatMap { $0 > 0 ? $0 : nil }
        if let steps = raw["todaySteps"].integer, steps >= 0 {
            Section {
                VStack(spacing: 4) {
                    if let goal {
                        Text("playkit.walk.remainingLabel").font(.subheadline).foregroundStyle(.secondary)
                        Text(verbatim: max(0, goal - steps).formatted())
                            .cyText(.dataXL)
                            .contentTransition(.numericText(countsDown: true))
                            .accessibilityIdentifier("playkit.walk.remaining")
                        Text("playkit.walk.stepsUnit").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        Text(verbatim: steps.formatted())
                            .cyText(.dataXL)
                    }
                }
                .frame(maxWidth: .infinity)
                if let goal {
                    ProgressView(value: Double(min(steps, goal)), total: Double(goal)) {
                        Text("playkit.walk.progress")
                    } currentValueLabel: {
                        Text(verbatim: "\(steps.formatted()) / \(goal.formatted()) · \(min(100, steps * 100 / goal))%").monospacedDigit()
                    }
                }
            }
            Section {
                LabeledContent { Text(verbatim: goal.map { $0.formatted() } ?? "—").monospacedDigit() } label: { Text("playkit.walk.goal") }
                LabeledContent { Text(verbatim: steps.formatted()).monospacedDigit() } label: { Text("playkit.walk.walked") }
                LabeledContent { Text(verbatim: raw["co2Kg"].double.map { String(format: "%.2f kg", $0) } ?? "—").monospacedDigit() } label: { Text("playkit.walk.co2") }
            } footer: {
                Label("playkit.walk.providerGate", systemImage: "figure.walk")
            }
        } else {
            Section {
                Text("playkit.walk.noReading")
                if let goal {
                    LabeledContent { Text(verbatim: goal.formatted()).monospacedDigit() } label: { Text("playkit.walk.goal") }
                }
            } footer: {
                Label("playkit.walk.providerGate", systemImage: "figure.walk")
            }
        }
    }

    // MARK: slowtask (the server owns the day count; the scratch card is dropped)
    // mp-journey r3: MP `playkit-slowtask` order — eyebrow 慢一点 · 跨日任务 → title (server) → one state block
    // (startHint / clock + 还有 N 天 + waitHint / ready line / unlocked text) → footer CTA (start · 明天再来 disabled · unlock).

    private func slowText(_ key: String) -> String? {
        let value = (raw[key].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    @ViewBuilder var nativeSlowTask: some View {
        let claimed = raw["claimed"].bool == true
        Group {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("playkit.slow.eyebrow").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    if let title = slowText("title") {
                        Text(verbatim: title).font(.headline).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                if claimed {
                    if let unlockText = slowText("unlockText") {
                        Text(verbatim: unlockText).fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                            .accessibilityIdentifier("playkit.slowTask.unlockText")
                    } else {
                        Text("playkitLegacy.slow.emptyReadback")
                    }
                } else if raw["started"].bool == true {
                    if let days = raw["daysLeft"].integer, days > 0 {
                        Label { Text("playkitLegacy.slow.daysLeftCount \(days)") } icon: { Image(systemName: "clock") }
                            .font(.title2).monospacedDigit()
                            .accessibilityIdentifier("playkit.slowTask.daysLeft")
                        Text(verbatim: slowText("waitHint") ?? appLocalized("playkit.slow.waitHint", locale: Locale.current))
                            .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    } else if raw["daysLeft"].integer == 0 {
                        Label("playkit.slow.ready", systemImage: "checkmark.circle")
                    } else {
                        Text("playkit.configurationInvalid")
                    }
                } else {
                    Text(verbatim: slowText("startHint") ?? appLocalized("playkit.slow.startHint", locale: Locale.current))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sensoryFeedback(.success, trigger: claimed) { old, next in !old && next }
    }

    var nativeSlowTaskSubmit: NativeGameSubmit? {
        guard raw["claimed"].bool != true else { return nil }
        if raw["started"].bool == true {
            // MP: while days remain the footer keeps a disabled 明天再来 button instead of disappearing.
            if let days = raw["daysLeft"].integer, days > 0 {
                return nativeSubmit("CLAIM_SLOW_TASK", [:], valid: false, title: Text("playkit.slow.waitCta"),
                                    identifier: "playkit.slowTask.wait")
            }
            guard raw["daysLeft"].integer == 0 else { return nil }
            return nativeSubmit("CLAIM_SLOW_TASK", [:], valid: true,
                                title: slowText("unlockLabel").map { Text(verbatim: $0) } ?? Text("playkit.slow.unlockLabel"),
                                identifier: "playkit.slowTask.claim")
        }
        return nativeSubmit("START_SLOW_TASK", [:], valid: true,
                            title: slowText("startLabel").map { Text(verbatim: $0) } ?? Text("playkit.slow.startLabel"),
                            identifier: "playkit.slowTask.start")
    }
}

/// Silent order's companion clock. Same local behaviour as `PlayKitSilentOrderBody`: no action
/// callback, no completion, score or reward. Give up is destructive and confirmed first.
@MainActor struct NativeGameSilentOrderClock: View {
    let segment: PlayWireValue
    let active: Bool
    let onDirty: () -> Void
    @State private var startedAt: TimeInterval?
    @State private var elapsed = 0
    @State private var gaveUp = false
    @State private var confirmGiveUp = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let seconds = elapsed + (startedAt.map { Int(max(0, ProcessInfo.processInfo.systemUptime - $0)) } ?? 0)
                VStack(spacing: 4) {
                    Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                        .cyText(.dataXL)
                        .contentTransition(.numericText())
                    Text("nativeGames.silent.elapsed").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("playkitLegacy.silent.performed \(String(format: "%02d:%02d", seconds / 60, seconds % 60))"))
            }
            if gaveUp {
                Label("playkitLegacy.silent.stopped", systemImage: "stop.circle")
            } else if startedAt == nil {
                Button { startedAt = ProcessInfo.processInfo.systemUptime; onDirty() } label: {
                    Text("playkitLegacy.silent.start").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!active)
                .accessibilityIdentifier("playkit.silentOrder.start")
            } else {
                Button(role: .destructive) { confirmGiveUp = true } label: {
                    Text("playkitLegacy.silent.giveUp").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!active)
                .accessibilityIdentifier("playkit.silentOrder.giveUp")
            }
        }
        .confirmationDialog(Text("playkitLegacy.silent.giveUp"), isPresented: $confirmGiveUp, titleVisibility: .visible) {
            Button("playkitLegacy.silent.giveUp", role: .destructive) { giveUp() }
            Button("playkit.cancel", role: .cancel) {}
        }
        .onAppear { elapsed = max(0, segment["elapsedSeconds"].integer ?? 0) }
        .onChange(of: active) { _, value in if !value { stop() } }
        .onChange(of: scenePhase) { _, value in if value != .active { stop() } }
        .onDisappear { stop() }
    }

    private func giveUp() {
        var transition = PlayKitSilentOrderGiveUp(running: startedAt != nil, gaveUp: gaveUp)
        transition.giveUp()
        stop()
        gaveUp = transition.gaveUp
        onDirty()
    }

    private func stop() {
        if let startedAt { elapsed += Int(max(0, ProcessInfo.processInfo.systemUptime - startedAt)); self.startedAt = nil }
    }
}
