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

    /// MP sort / match / classify show no attempt rows (a capped kit keeps the HUD 还能错 pill) and no how-to line;
    /// the judged outcome is one feedback line in place, overall only (the server never says which row is off).
    @ViewBuilder var nativeReasoning: some View {
        switch kind {
        case .sort: nativeSortSection
        case .match: nativeMatchSection
        default: nativeClassifySections
        }
    }

    var nativeReasoningPassed: Bool { (raw["attempts"].integer ?? 0) > 0 && raw["passed"].bool == true }

    /// MP `so__fb` / `ma__fb` / `cf__fb`: only after a judged submit.
    var nativeReasoningFeedback: (key: LocalizedStringKey, ok: Bool)? {
        guard (raw["attempts"].integer ?? 0) > 0, let passed = raw["passed"].bool else { return nil }
        switch kind {
        case .sort:
            if passed { return ("playkit.sort.fb.ok", true) }
            let key = raw["finished"].bool == true ? "playkit.sort.fb.exhausted" : "playkit.sort.fb.retry"
            return (LocalizedStringKey(key), false)
        case .match:
            if passed { return ("playkit.match.fb.ok", true) }
            return ("playkit.match.fb.retry", false)
        default:
            if passed { return ("playkit.classify.fb.ok", true) }
            return ("playkit.classify.fb.retry", false)
        }
    }

    @ViewBuilder var nativeReasoningFeedbackLine: some View {
        if let feedback = nativeReasoningFeedback {
            Label {
                Text(feedback.key)
            } icon: {
                Image(systemName: feedback.ok ? "checkmark.circle.fill" : "arrow.uturn.backward.circle")
                    .foregroundStyle(feedback.ok ? Color.green : Color.orange)
            }
            .font(.subheadline)
            .accessibilityIdentifier("playkit.reasoning.feedback")
        }
    }

    /// MP `playkit-sort`: prompt (shell header) → numbered rows (picture when the item has one; all rows turn green only
    /// once the whole order passed, never per row) → one feedback line → 就这个顺序 on the bottom bar. No how-to line and no
    /// attempt rows (MP shows neither; a capped kit keeps the HUD 还能错 pill). System drag handles + VoiceOver move actions.
    @ViewBuilder var nativeSortSection: some View {
        let ids = nativeSortIDs
        let items = nativeItems
        let passed = nativeReasoningPassed
        Section {
            ForEach(Array(ids.enumerated()), id: \.element) { index, id in
                let item = items.first { $0.id == id }
                HStack(spacing: 12) {
                    Text(verbatim: String(index + 1))
                        .font(.title3.weight(.bold).italic())
                        .monospacedDigit()
                        .foregroundStyle(passed ? Color.green : Color.secondary)
                    if let image = item?.raw["img"].text, !image.isEmpty {
                        PlayKitArtwork(source: image, approvedHosts: approvedArtworkHosts)
                            .frame(width: 48, height: 48)
                            .clipShape(.rect(cornerRadius: CYRadius.sm))
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: item?.label ?? id)
                        .fixedSize(horizontal: false, vertical: true)
                    if passed {
                        Spacer(minLength: 0)
                        Image(systemName: "checkmark").foregroundStyle(.green).accessibilityHidden(true)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("playkit.sort.rowLabel \(index + 1) \(item?.label ?? id)"))
                .accessibilityAction(named: Text("playkit.sort.up")) { nativeMove(index, by: -1) }
                .accessibilityAction(named: Text("playkit.sort.down")) { nativeMove(index, by: 1) }
                .accessibilityIdentifier("playkit.sort.row." + id)
            }
            .onMove { from, to in
                guard enabled, !passed else { return }
                var next = nativeSortIDs
                next.move(fromOffsets: from, toOffset: to)
                nativeOrder = next
                nativeReasoningEdited()
            }
        } footer: {
            nativeReasoningFeedbackLine
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
                .disabled(!enabled || nativeReasoningPassed)
                .tint(nativeReasoningPassed ? Color.green : nil)
                .accessibilityIdentifier("playkit.match.row." + item.id)
            }
        } footer: {
            nativeReasoningFeedbackLine
        }
    }

    /// MP `playkit-classify` order: the card stack (未分类, N / total) → every bin with its count and its placed items
    /// (swipe to take one back, MP 点小标签拿回来) → 还有 N 条没分 → feedback → 分好了 (bottom bar).
    @ViewBuilder var nativeClassifySections: some View {
        let placement = nativeCleanPlacement
        let items = nativeItems
        let unsorted = items.filter { placement[$0.id] == nil }
        let passed = nativeReasoningPassed
        if !unsorted.isEmpty {
            Section {
                ForEach(unsorted) { item in nativeClassifyRow(item) }
            } header: {
                HStack {
                    Text("nativeGames.classify.unsorted")
                    Spacer()
                    Text(verbatim: "\(items.count - unsorted.count + 1) / \(items.count)").monospacedDigit()
                }
            }
        }
        ForEach(nativeBins) { bin in
            let placed = items.filter { placement[$0.id] == bin.id }
            Section {
                ForEach(placed) { item in
                    nativeClassifyRow(item)
                        .tint(passed ? Color.green : nil)
                        .swipeActions(edge: .trailing) {
                            Button("nativeGames.classify.takeBack") {
                                var next = nativeCleanPlacement
                                next.removeValue(forKey: item.id)
                                nativePlacement = next
                                nativeReasoningEdited()
                            }
                            .disabled(!enabled || passed)
                        }
                }
            } header: {
                HStack {
                    Text(verbatim: bin.label)
                    Spacer()
                    Text(verbatim: String(placed.count)).monospacedDigit()
                }
                .accessibilityElement(children: .combine)
            }
        }
        if !unsorted.isEmpty || nativeReasoningFeedback != nil {
            Section {
                EmptyView()
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    if !unsorted.isEmpty {
                        Text("playkit.classify.left \(unsorted.count)")
                            .accessibilityIdentifier("playkit.classify.remaining")
                    }
                    nativeReasoningFeedbackLine
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
        .disabled(!enabled || nativeReasoningPassed)
        .accessibilityIdentifier("playkit.classify.row." + item.id)
    }

    // MARK: bingo (read only: cells light up from play elsewhere)

    /// MP `playkit-bingo` under the shell title: ribbon only once earned (九格全亮 · full reward, else 连成一条线 · line
    /// reward) → 3 × 3 board (name · how, scan / play / done glyph, completed lines tinted) → 已完成 n / 9 → tap an unlit
    /// cell for how it lights (知道了). The MP shows no how-to line under the title ("删除提示语").
    @ViewBuilder var nativeBingo: some View {
        let board = PlayKitBingoBoard(raw)
        let full = board.filled.count >= 9
        let fullReward = raw["fullReward"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lineReward = raw["lineReward"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if full, !fullReward.isEmpty {
            Section {
                Label { Text("playkit.bingo.fullBanner \(fullReward)") } icon: { Image(systemName: "gift.fill") }
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier("playkit.bingo.fullBanner")
            }
        } else if !full, !board.completedLines.isEmpty, !lineReward.isEmpty {
            Section {
                Label { Text("playkit.bingo.lineBanner \(lineReward)") } icon: { Image(systemName: "gift.fill") }
                    .foregroundStyle(.tint)
                    .accessibilityIdentifier("playkit.bingo.lineBanner")
            }
        }
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { index in nativeBingoCell(board, index: index) }
            }
            Text("playkit.bingo.filledCount \(board.filled.count)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("playkit.bingo.filledCount")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: board.completedLines.count + (full ? 1 : 0)) { old, new in new > old }
    }

    /// MP cell: how it lights (default 走到即亮); a scan cell (how mentions 扫码) shows the QR glyph, others the play glyph.
    func nativeBingoHow(_ board: PlayKitBingoBoard, index: Int) -> String? {
        let how = board.instruction(at: index).trimmingCharacters(in: .whitespacesAndNewlines)
        return how.isEmpty ? nil : how
    }

    func nativeBingoIsScan(_ board: PlayKitBingoBoard, index: Int) -> Bool {
        let how = board.instruction(at: index)
        return how.contains("扫码") || how.localizedCaseInsensitiveContains("scan")
    }

    /// An unlit cell explains itself in place (sheet with 知道了); a lit cell is done and opens nothing (MP `onCell`).
    @ViewBuilder func nativeBingoCell(_ board: PlayKitBingoBoard, index: Int) -> some View {
        let filled = board.filled.contains(index)
        let inLine = board.linePositions.contains(index)
        let scan = nativeBingoIsScan(board, index: index)
        let how = nativeBingoHow(board, index: index)
        let button = Button { if !filled { nativeIndex = index } } label: {
            VStack(spacing: 4) {
                Image(systemName: filled ? "checkmark" : (scan ? "qrcode.viewfinder" : "play.fill")).imageScale(.large)
                Text(verbatim: board.title(at: index)).font(.footnote.weight(.semibold)).lineLimit(3).multilineTextAlignment(.center)
                Group {
                    if let how { Text(verbatim: how) } else { Text("playkit.bingo.howDefault") }
                }
                .font(.caption).lineLimit(2).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
        .tint(inLine ? Color.pink : nil)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: board.title(at: index)))
        .accessibilityValue(filled ? Text("nativeGames.bingo.filled") : (how.map { Text(verbatim: $0) } ?? Text("playkit.bingo.howDefault")))
        .accessibilityAddTraits(filled ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("playkit.bingo.cell.\(index)")
        .sheet(isPresented: Binding(get: { nativeIndex == index }, set: { if !$0 { nativeIndex = nil } })) {
            NavigationStack {
                List {
                    Section {
                        if scan { Text("playkit.bingo.panel.scan") }
                        else if let how { Text("playkit.bingo.panel.play \(how)") }
                        else { Text("playkit.bingo.panel.playDefault") }
                    }
                }
                .navigationTitle(Text(verbatim: board.title(at: index)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) { Button("playkit.bingo.panel.ok") { nativeIndex = nil } }
                }
            }
            .presentationDetents([.medium])
        }
        if filled { button.buttonStyle(.borderedProminent) } else { button.buttonStyle(.bordered) }
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
                ContentUnavailableView("playkit.silent.generating", systemImage: "qrcode")
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
                    Text("playkit.silent.performing").font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("playkitLegacy.silent.performed \(String(format: "%02d:%02d", seconds / 60, seconds % 60))"))
            }
            if gaveUp {
                Label("playkitLegacy.silent.stopped", systemImage: "stop.circle")
            } else {
                // MP `so__giveup` 认输说话: the clock runs from the moment the page shows (no start step).
                Button(role: .destructive) { confirmGiveUp = true } label: {
                    Label("playkitLegacy.silent.giveUp", systemImage: "arrow.right").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!active || startedAt == nil)
                .accessibilityIdentifier("playkit.silentOrder.giveUp")
            }
        }
        .confirmationDialog(Text("playkitLegacy.silent.giveUp"), isPresented: $confirmGiveUp, titleVisibility: .visible) {
            Button("playkitLegacy.silent.giveUp", role: .destructive) { giveUp() }
            Button("playkit.cancel", role: .cancel) {}
        }
        .onAppear { elapsed = max(0, segment["elapsedSeconds"].integer ?? 0); resume() }
        .onChange(of: active) { _, value in if value { resume() } else { stop() } }
        .onChange(of: scenePhase) { _, value in if value == .active { resume() } else { stop() } }
        .onDisappear { stop() }
    }

    private func giveUp() {
        var transition = PlayKitSilentOrderGiveUp(running: startedAt != nil, gaveUp: gaveUp)
        transition.giveUp()
        stop()
        gaveUp = transition.gaveUp
        onDirty()
    }

    private func resume() {
        guard active, !gaveUp, startedAt == nil, scenePhase == .active else { return }
        startedAt = ProcessInfo.processInfo.systemUptime
    }

    private func stop() {
        if let startedAt { elapsed += Int(max(0, ProcessInfo.processInfo.systemUptime - startedAt)); self.startedAt = nil }
    }
}
