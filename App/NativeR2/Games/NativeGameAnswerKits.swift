import SwiftUI

// Template 1 · Answer (qa, predict, estimate, pricepair, diyname, note, profile).
// Apple reference: Settings / Health "Add Data" form — the question, one input, one prominent action.
// typein is drawn by `NativeGameTimedKit` (it runs against a clock).
extension PlayKitScreen {

    // MARK: qa

    @ViewBuilder var nativeQA: some View {
        let mode = (raw["mode"].text ?? "TYPE").uppercased()
        if raw["imageUrl"].text?.isEmpty == false || raw["audioUrl"].text?.isEmpty == false {
            Section {
                artwork(raw["imageUrl"].text)
                PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
            }
        }
        if mode == "SHOT" {
            Section {
                if let note = raw["shotNote"].text { Text(verbatim: note) }
                photoInput { url in nativePrepare("SUBMIT_QA", ["imageUrl": .string(url)]) }
            }
        } else if mode == "PICK" {
            let multi = raw["multi"].bool == true
            if let pictures = PlayKitImageOption.read(raw) {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(pictures) { option in nativePictureOption(option, multi: multi) }
                    }
                    .accessibilityIdentifier("playkit.qa.pictures")
                } footer: {
                    if multi { Text("playkit.qa.multiHint") }
                }
            } else {
                Section {
                    ForEach(Array(projection.options.enumerated()), id: \.element.id) { index, option in
                        let marker = PlayKitImageOption.letter(at: index)
                        nativeChoiceRow(id: option.id, label: PlayKitImageOption.stripDuplicateKey(option.label, key: marker),
                                        marker: marker, multi: multi)
                    }
                } footer: {
                    if multi { Text("playkit.qa.multiHint") }
                }
            }
        } else if raw["letterPool"] != .null {
            Section {
                PlayKitQuestionLetterPoolView(segment: raw, revision: runtimeIdentity, enabled: enabled,
                    onDirty: { dirty = true }, requestReview: nativePrepare)
                    .id(childReset)
            }
        } else {
            Section {
                TextField("playkit.qa.answer", text: textBinding())
                    .keyboardType(.default)
                    .submitLabel(.done)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(!enabled)
                    .onSubmit { nativeQATypedSubmit() }
                    .accessibilityIdentifier("playkit.qa.field")
                if let howTo = raw["howTo"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !howTo.isEmpty {
                    PlayKitHowToButton(text: howTo, identifier: "playkit.qa.howTo")
                }
            }
        }
    }

    var nativeQASubmit: NativeGameSubmit? {
        guard !projection.complete else { return nil }
        let mode = (raw["mode"].text ?? "TYPE").uppercased()
        if mode == "SHOT" || (mode != "PICK" && raw["letterPool"] != .null) { return nil }
        if mode == "PICK" {
            let payload: [String: PlayWireValue] = raw["multi"].bool == true
                ? ["optionIds": .array(selected.sorted().map(PlayWireValue.string))]
                : ["optionId": .string(selected.first ?? "")]
            return nativeSubmit("SUBMIT_QA", payload, valid: !selected.isEmpty)
        }
        return nativeSubmit("SUBMIT_QA", ["input": .string(text)],
                            valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// Return on the keyboard opens the same review as the Submit button.
    func nativeQATypedSubmit() {
        guard enabled, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        nativePrepare("SUBMIT_QA", ["input": .string(text)])
    }

    /// A Settings-style selectable row: label on the left, checkmark on the right.
    func nativeChoiceRow(id: String, label: String, marker: String? = nil, multi: Bool = false) -> some View {
        let on = selected.contains(id)
        return Button { nativeToggle(id, multi: multi) } label: {
            HStack(spacing: 12) {
                if let marker { Text(verbatim: marker).foregroundStyle(.secondary).monospaced() }
                Text(verbatim: label).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if on { Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(.tint).accessibilityHidden(true) }
            }
            .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityAddTraits(on ? .isSelected : [])
        .accessibilityIdentifier("playkit.choice." + id)
    }

    /// UG-02 picture option as a system button; the selected one is prominent.
    @ViewBuilder func nativePictureOption(_ option: PlayKitImageOption, multi: Bool) -> some View {
        let on = selected.contains(option.id)
        let button = Button { nativeToggle(option.id, multi: multi) } label: {
            VStack(spacing: 6) {
                PlayKitArtwork(source: option.image, approvedHosts: approvedArtworkHosts, alt: option.spokenDescription)
                    .frame(maxWidth: .infinity)
                Label {
                    Text(verbatim: option.key + " " + option.label).lineLimit(2)
                } icon: {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                }
                .font(.subheadline)
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("playkit.qa.pictureOption \(option.key) \(option.spokenDescription)"))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("playkit.qa.picture." + option.id)
        if on { button.buttonStyle(.borderedProminent) } else { button.buttonStyle(.bordered) }
    }

    // MARK: predict

    // MP `playkit-predict`: question → option cards (seal on the committed one) → reveal (wait / won / lost / void)
    // → hint (截止 / 揭晓 time, or 今天这一轮已经截止) → 就选这个 · 已经选了 · 不选，继续 (bottom bar).
    @ViewBuilder var nativePredict: some View {
        let mine = raw["myOptionKey"].text ?? ""
        let skipped = raw["skipped"].bool == true
        Section {
            ForEach(projection.options) { option in
                if mine.isEmpty && !skipped && raw["closed"].bool != true {
                    nativeChoiceRow(id: option.id, label: option.label, marker: option.id)
                } else {
                    LabeledContent {
                        if option.id == mine {
                            Label("playkit.predict.mine", systemImage: "seal.fill").foregroundStyle(.tint)
                        }
                    } label: {
                        Text(verbatim: option.label)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            if let question = raw["question"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty {
                Text(verbatim: question)
            }
        }
        if let reveal = nativePredictReveal(mine: mine) {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(reveal.head).font(.headline)
                    reveal.body.font(.body).foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("playkit.predict.reveal")
            }
        }
        if !skipped, raw["settleStatus"].integer == nil {
            if raw["closed"].bool == true && mine.isEmpty {
                Section { Text("playkit.predict.closedToday").foregroundStyle(.secondary) }
            } else if !mine.isEmpty, !nativePredictWaitLines.isEmpty {
                Section {
                    ForEach(Array(nativePredictWaitLines.enumerated()), id: \.offset) { _, line in
                        line.foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    /// MP `revealOf`: three different states, never one 「暂无结果」 line.
    func nativePredictReveal(mine: String) -> (head: LocalizedStringKey, body: Text)? {
        guard let status = raw["settleStatus"].integer else { return nil }
        let shopAnswers = raw["shopAnswers"].bool != false
        func label(_ key: String) -> String { projection.options.first { $0.id == key }?.label ?? key }
        switch status {
        case 2:
            return ("playkit.predict.voidHead", Text(shopAnswers ? LocalizedStringKey("playkit.predict.voidLate") : LocalizedStringKey("playkit.predict.voidNoAnswer")))
        case 1:
            let answer = label(raw["settledOption"].text ?? "")
            if raw["won"].bool == true { return ("playkit.predict.won", Text("playkit.predict.wonLine \(answer)")) }
            return ("playkit.predict.lost", Text("playkit.predict.lostLine \(answer) \(label(mine))"))
        default:
            guard shopAnswers else { return nil }
            return ("playkit.predict.wait", Text("playkit.predict.waitLine"))
        }
    }

    /// MP `waitLabelOf`: 今天 HH:00 截止 and/or 第 N 天 HH:00 由商家给出答案; nothing when the numbers are not real.
    var nativePredictWaitLines: [Text] {
        func hour(_ value: PlayWireValue) -> String? {
            guard let h = value.integer, (0...23).contains(h) else { return nil }
            return String(format: "%02d:00", h)
        }
        let close = hour(raw["closeAtHour"])
        if raw["shopAnswers"].bool == false { return close.map { [Text("playkit.predict.closeOnly \($0)")] } ?? [] }
        var reveal: Text?
        if let time = hour(raw["revealHour"]), let days = raw["revealDays"].integer, (0...30).contains(days) {
            switch days {
            case 0: reveal = Text("playkit.predict.revealToday \(time)")
            case 1: reveal = Text("playkit.predict.revealTomorrow \(time)")
            case 2: reveal = Text("playkit.predict.revealDayAfter \(time)")
            default: reveal = Text("playkit.predict.revealDay \(days) \(time)")
            }
        }
        if let close, let reveal { return [Text("playkit.predict.closeOnly \(close)"), reveal] }
        if let reveal { return [reveal] }
        if let close { return [Text("playkit.predict.closeThenShop \(close)")] }
        return []
    }

    // MARK: estimate

    // MP `playkit-estimate`: question (shell title) → reel → result (猜中了 / 差一点 / 差得有点远 · 你猜 · 实际 · 差 ·
    // author reveal) → 就这个数 (hidden once locked). The MP shows no range line; the bounds stay in the wheel.
    @ViewBuilder var nativeEstimate: some View {
        // The completed projection does not return the player's guess; no picker is shown as if it were.
        if !projection.complete {
            if let wheel = PlayKitEstimateWheel(segment: raw) {
                let unit = raw["unit"].text ?? ""
                let index = nativeEstimateIndex(wheel)
                Section {
                    Picker("playkit.estimate.value", selection: nativeEstimateBinding(wheel)) {
                        ForEach(wheel.ticks.indices, id: \.self) { tick in
                            Text(verbatim: PlayGameNumber.text(wheel.ticks[tick], unit: unit)).tag(tick)
                        }
                    }
                    .pickerStyle(.wheel)
                    .disabled(!enabled)
                    .accessibilityIdentifier("playkit.estimate.wheel")
                    // Fine nudge, one tick at a time (the wheel stays the main input).
                    Stepper(value: nativeEstimateBinding(wheel), in: 0...max(0, wheel.ticks.count - 1)) {
                        Text(verbatim: wheel.ticks.indices.contains(index) ? PlayGameNumber.text(wheel.ticks[index], unit: unit) : "—")
                            .monospacedDigit()
                    }
                    .disabled(!enabled)
                    .accessibilityIdentifier("nativeGames.estimate.stepper")
                }
            } else {
                Section { Text("playkit.configurationInvalid") }
            }
        }
        // Read only the current accepted node projection, with no cached tier.
        if model.isCurrent, !["stale", "disabled"].contains(model.phase), let resultKey = projection.estimateResultKey {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(resultKey)).font(.headline)
                        .accessibilityIdentifier("playkit.estimate.result")
                    if let detail = nativeEstimateDetail {
                        detail.font(.subheadline).foregroundStyle(.secondary).monospacedDigit()
                    }
                    if let reveal = projection.estimateReadback?.reveal {
                        Text(verbatim: reveal).font(.body)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// MP `resultLine` detail: 正好 {answer} on an exact hit, else 你猜 {guess} · 实际 {answer} · 差 {diff}.
    var nativeEstimateDetail: Text? {
        guard let readback = projection.estimateReadback, let guess = readback.guess, let answer = readback.answer,
              guess.isFinite, answer.isFinite else { return nil }
        let unit = raw["unit"].text
        let answerText = PlayGameNumber.text(answer, unit: unit)
        if readback.exact { return Text("playkit.estimate.detail.exact \(answerText)") }
        let guessText = PlayGameNumber.text(guess, unit: unit)
        guard let difference = readback.difference, difference > 0 else {
            return Text("playkit.estimate.detail.pair \(guessText) \(answerText)")
        }
        return Text("playkit.estimate.detail.diff \(guessText) \(answerText) \(PlayGameNumber.text(difference, unit: unit))")
    }

    func nativeEstimateIndex(_ wheel: PlayKitEstimateWheel) -> Int {
        let index = nativeIndex ?? wheel.initialIndex
        return min(max(0, index), max(0, wheel.ticks.count - 1))
    }

    func nativeEstimateBinding(_ wheel: PlayKitEstimateWheel) -> Binding<Int> {
        Binding(get: { nativeEstimateIndex(wheel) }, set: { next in
            guard enabled, next != nativeEstimateIndex(wheel) else { return }
            nativeIndex = next; dirty = true
        })
    }

    var nativeEstimateSubmit: NativeGameSubmit? {
        // MP: 就这个数 is hidden once the server tier is back (locked); a server reopen brings it back.
        guard !projection.complete, projection.estimateResultKey == nil, let wheel = PlayKitEstimateWheel(segment: raw) else { return nil }
        let value = wheel.value(at: nativeEstimateIndex(wheel))
        return nativeSubmit("SUBMIT_ESTIMATE", ["value": .number(value ?? 0)], valid: value != nil,
                            identifier: "playkit.submit.estimate")
    }

    // MARK: pricepair

    @ViewBuilder var nativePricePair: some View {
        // Recomputed from the current accepted state; never from a local pick or a cached receipt.
        let result = model.isCurrent && !["stale", "disabled"].contains(model.phase) ? PlayKitPricePairResult(segment: raw) : nil
        Section {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(projection.options) { option in nativePriceOption(option, result: result) }
            }
        } footer: {
            if let result, !result.passed {
                Text(result.finished ? "playkit.pricePair.ended" : "playkit.pricePair.retry")
                    .accessibilityIdentifier("playkit.pricePair.roundStatus")
            }
        }
    }

    @ViewBuilder func nativePriceOption(_ option: PlayKitOption, result: PlayKitPricePairResult?) -> some View {
        let on = selected.contains(option.id)
        let button = Button { nativeToggle(option.id, multi: false) } label: {
            VStack(alignment: .leading, spacing: 6) {
                artwork(option.raw["imageUrl"].text)
                Text(verbatim: option.label).font(.headline)
                if let note = option.raw["note"].text { Text(verbatim: note).font(.footnote) }
                if let result, result.lastPickID == option.id {
                    Label(result.passed ? "playkit.pricePair.lastCorrect" : "playkit.pricePair.lastIncorrect",
                          systemImage: result.passed ? "checkmark.circle" : "xmark.circle")
                        .font(.footnote)
                        .accessibilityIdentifier("playkit.pricePair.lastPick." + option.id)
                }
                if let result, result.answerID == option.id {
                    Label("playkit.pricePair.revealedAnswer", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .accessibilityIdentifier("playkit.pricePair.answer." + option.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .disabled(!enabled)
        .accessibilityLabel(Text(verbatim: option.label))
        .accessibilityValue(Text(on ? "playkit.pricePair.currentChoice" : "playkit.select"))
        .accessibilityAddTraits(on ? .isSelected : [])
        if on { button.buttonStyle(.borderedProminent) } else { button.buttonStyle(.bordered) }
    }

    // MARK: diyname

    @ViewBuilder var nativeDiyName: some View {
        let maxLength = max(1, raw["maxLength"].integer ?? 16)
        Section {
            // MP `dn__shot`: the photo, or a camera placeholder until one exists.
            if let photo = raw["photoUrl"].text, !photo.isEmpty {
                artwork(photo).frame(maxWidth: 120, alignment: .leading)
                    .accessibilityLabel(Text("playkitLegacy.name.photo"))
            } else {
                Image(systemName: "camera")
                    .font(.title)
                    .foregroundStyle(.secondary)
                    .frame(width: 120, height: 90)
                    .background(.fill.tertiary, in: .rect(cornerRadius: CYRadius.card))
                    .accessibilityHidden(true)
            }
            TextField("playkitLegacy.name.placeholder", text: textBinding(limit: maxLength))
                .submitLabel(.done)
                .disabled(!enabled)
                .onSubmit {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if enabled, !trimmed.isEmpty { nativePrepare("SUBMIT_DIY_NAME", ["name": .string(trimmed)]) }
                }
                .accessibilityIdentifier("playkit.diyName.field")
        } footer: {
            Text("playkitLegacy.name.audience")
        }
        let suggestions = (raw["suggestions"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        if !suggestions.isEmpty {
            Section {
                ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                    Button { text = PlayKitInputContract.limitText(suggestion, toUTF16: maxLength); dirty = true } label: {
                        Label { Text(verbatim: suggestion) } icon: { Image(systemName: text == suggestion ? "checkmark" : "text.cursor") }
                    }
                    .disabled(!enabled)
                }
            } header: {
                Text("playkitLegacy.name.suggestions")
            }
        }
    }

    // MARK: note

    /// MP `playkit-note` body under the shell header (kicker title, default 留一句 · prompt): 前面的人写过 (text · MM-dd HH:mm)
    /// → field (写在下面) → n/max count → preset lines (hidden once done) → 这句已经留在这儿了 → 留下这句 / 已留下 on the bottom bar.
    @ViewBuilder var nativeNote: some View {
        let limit = PlayKitShortMessageLimit.resolve(raw["maxLength"])
        let done = raw["done"].bool == true
        let previous = (raw["previous"].array ?? []).filter { !($0["text"].text ?? "").isEmpty }
        if !previous.isEmpty {
            Section {
                ForEach(Array(previous.enumerated()), id: \.offset) { _, note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: note["text"].text ?? "")
                        if let at = note["at"].double, at.isFinite {
                            Text(Date(timeIntervalSince1970: at / 1000), format: .dateTime.month(.twoDigits).day(.twoDigits).hour().minute())
                                .font(.footnote).foregroundStyle(.secondary)
                        } else if let at = note["at"].text, !at.isEmpty {
                            Text(verbatim: at).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("playkit.note.previousLabel")
            }
        }
        let presets = (raw["presets"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        Section {
            TextField("playkit.note.placeholder", text: textBinding(limit: limit), axis: .vertical)
                .lineLimit(3...8)
                .disabled(!enabled || done)
                .accessibilityLabel(raw["prompt"].text.flatMap { $0.isEmpty ? nil : Text(verbatim: $0) } ?? Text("playkit.note.fieldLabel"))
                .accessibilityIdentifier("playkit.note.field")
        } footer: {
            Text(verbatim: "\(text.count)/\(limit)").monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityLabel(Text("playkit.note.count \(text.count) \(limit)"))
        }
        if !done, !presets.isEmpty {
            Section {
                ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                    Button { text = PlayKitInputContract.limitText(preset, toUTF16: limit); dirty = true } label: {
                        Label { Text(verbatim: preset).foregroundStyle(.primary) } icon: {
                            Image(systemName: text == preset ? "checkmark" : "text.bubble")
                        }
                    }
                    .disabled(!enabled)
                    .accessibilityLabel(Text("playkit.note.usePreset \(preset)"))
                }
            }
            .accessibilityIdentifier("nativeGames.note.presets")
        }
        if done {
            Section {
                Label("playkit.note.doneLine", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("playkit.note.done")
            }
        }
    }

    // MARK: profile

    var nativeProfileQuestions: [PlayWireValue] {
        (raw["questions"].array ?? []).filter { ($0["key"].text ?? "").isEmpty == false }
    }

    /// Mini-program 出生登记: the register card, then one question at a time, the avatar last, one write.
    @ViewBuilder var nativeProfile: some View {
        let questions = nativeProfileQuestions
        let avatarEnabled = raw["avatar"]["enabled"].bool == true
        let total = questions.count + (avatarEnabled ? 1 : 0)
        let step = min(profileStep, max(0, total - 1))
        let done = projection.complete
        Section {
            ForEach(Array(questions.enumerated()), id: \.offset) { _, question in
                let key = question["key"].text ?? ""
                let value = answers[key] ?? ""
                let shown = PlayKitOption.read(question["options"], idKey: "key").first { $0.id == value }?.label ?? value
                // MP `pf__row-answer`: an unanswered row stays blank until it is written in (no placeholder dash).
                LabeledContent {
                    Text(verbatim: shown)
                } label: {
                    Text(verbatim: question["label"].text ?? key)
                }
            }
        } header: {
            if projection.title.isEmpty { Text("playkit.profile.formTitle") } else { Text(verbatim: projection.title) }
        } footer: {
            if !done && step == total - 1 && total > 0 { Text("playkit.profile.lockNotice") }
        }
        .accessibilityIdentifier("playkit.profile.summary")
        // MP `pf__progress`: 上一题 sits between the register card and the question (step / total is the shell HUD).
        if !done, step > 0 {
            Section {
                Button { profileStep = step - 1 } label: { Label("playkit.profile.previous", systemImage: "chevron.backward") }
                    .disabled(!enabled)
                    .accessibilityIdentifier("playkit.profile.previous")
            }
        }
        if !done, questions.indices.contains(step) { nativeProfileQuestion(questions[step]) }
        if avatarEnabled && ((!done && step == questions.count) || (done && !avatarURL.isEmpty)) {
            Section {
                if !avatarURL.isEmpty {
                    artwork(avatarURL).frame(maxWidth: 160)
                    Label("playkit.profile.avatarReady", systemImage: "person.crop.circle.badge.checkmark")
                }
                if !done { photoInput { url in avatarURL = url; dirty = true } }
            } header: {
                Text(LocalizedStringKey(raw["avatar"]["required"].bool == true ? "playkit.profile.avatarRequired" : "playkit.profile.avatarOptional"))
            }
            .accessibilityIdentifier("playkit.profile.avatar")
        }
        if done {
            Section {
                Label("playkit.profile.seal", systemImage: "checkmark.seal.fill")
                    .accessibilityLabel(Text("playkit.profile.sealLabel"))
                    .accessibilityIdentifier("playkit.profile.seal")
            }
        }
    }

    @ViewBuilder func nativeProfileQuestion(_ question: PlayWireValue) -> some View {
        let key = question["key"].text ?? ""
        let limit = nativeProfileLimit(question)
        Section {
            if question["kind"].text == "pick" {
                Picker(selection: Binding(get: { answers[key] ?? "" }, set: { answers[key] = $0; dirty = true })) {
                    ForEach(PlayKitOption.read(question["options"], idKey: "key")) { option in
                        Text(verbatim: option.label).tag(option.id)
                    }
                } label: {
                    Text(verbatim: question["label"].text ?? key)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .disabled(!enabled)
            } else {
                TextField("playkit.profile.placeholder", text: Binding(get: { answers[key] ?? "" }, set: {
                    answers[key] = PlayKitInputContract.limitText($0, toUTF16: limit); dirty = true
                }))
                .submitLabel(.next)
                .disabled(!enabled)
                .onSubmit { if nativeProfileAnswered(question) { nativeProfileAdvance() } }
                .accessibilityLabel(Text(verbatim: question["label"].text ?? key))
                .accessibilityIdentifier("playkit.profile.field." + key)
            }
        } header: {
            Text(verbatim: question["label"].text ?? key)
        } footer: {
            HStack {
                Text("playkit.profile.required")
                Spacer()
                // MP `pf__count`: n / max under a written answer (not for a pick).
                if question["kind"].text != "pick" {
                    Text(verbatim: "\((answers[key] ?? "").utf16.count) / \(limit)").monospacedDigit()
                }
            }
        }
        .id(key)
        .accessibilityIdentifier("playkit.profile.question." + key)
    }

    /// Mini-program default is 12 characters when the merchant set no limit.
    func nativeProfileLimit(_ question: PlayWireValue) -> Int {
        let configured = question["maxLength"].integer ?? 0
        return configured > 0 ? configured : 12
    }

    func nativeProfileAnswered(_ question: PlayWireValue) -> Bool {
        let value = (answers[question["key"].text ?? ""] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return false }
        if question["kind"].text == "pick" { return PlayKitOption.read(question["options"], idKey: "key").contains { $0.id == value } }
        return value.utf16.count <= nativeProfileLimit(question)
    }

    func nativeProfileAdvance() {
        let total = nativeProfileQuestions.count + (raw["avatar"]["enabled"].bool == true ? 1 : 0)
        if profileStep < total - 1 { profileStep += 1 }
    }

    /// 下一题 until the last step, then 完成建档 (the one SUBMIT_PROFILE write).
    var nativeProfileSubmit: NativeGameSubmit? {
        guard !projection.complete else { return nil }
        let questions = nativeProfileQuestions
        let total = questions.count + (raw["avatar"]["enabled"].bool == true ? 1 : 0)
        guard total > 0 else { return nil }
        let step = min(profileStep, total - 1)
        if step >= total - 1 {
            let payload: [String: PlayWireValue] = ["answers": .object(answers.mapValues(PlayWireValue.string)), "avatarUrl": .string(avatarURL)]
            return nativeSubmit("SUBMIT_PROFILE", payload, valid: nativeValid("SUBMIT_PROFILE", payload), title: Text("playkit.profile.finish"))
        }
        let answered = questions.indices.contains(step) && nativeProfileAnswered(questions[step])
        return NativeGameSubmit(title: Text("playkit.profile.next"), enabled: enabled && answered,
                                identifier: "playkit.profile.next", action: { nativeProfileAdvance() })
    }
}
