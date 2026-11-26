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

    @ViewBuilder var nativePredict: some View {
        if let mine = raw["myOptionKey"].text, !mine.isEmpty {
            Section {
                LabeledContent {
                    Text(verbatim: projection.options.first { $0.id == mine }?.label ?? mine)
                } label: {
                    Label("playkit.predict.mine", systemImage: "lock.fill")
                }
            }
        } else {
            Section {
                ForEach(projection.options) { option in nativeChoiceRow(id: option.id, label: option.label) }
            }
        }
        Section {
            if let status = raw["settleStatus"].integer {
                if status == 2 { Text("playkit.predict.voided") }
                else if status == 1 {
                    Text(raw["won"].bool == true ? "playkit.predict.won" : "playkit.predict.lost")
                    let answer = raw["settledOption"].text ?? ""
                    LabeledContent {
                        Text(verbatim: projection.options.first { $0.id == answer }?.label ?? answer)
                    } label: {
                        Text("playkit.predict.answer")
                    }
                } else {
                    Label("playkit.predict.wait", systemImage: "hourglass")
                }
            }
            if let days = raw["revealDays"].integer, days >= 0 {
                LabeledContent { Text(verbatim: String(days)).monospacedDigit() } label: { Text("playkit.predict.revealDays") }
            }
            if let hour = raw["revealHour"].integer, (0...23).contains(hour) {
                LabeledContent { Text(verbatim: String(hour)).monospacedDigit() } label: { Text("playkit.predict.revealHour") }
            }
        }
    }

    // MARK: estimate

    @ViewBuilder var nativeEstimate: some View {
        // Read only the current accepted node projection, with no cached tier.
        if model.isCurrent, !["stale", "disabled"].contains(model.phase), let resultKey = projection.estimateResultKey {
            Section {
                Text(LocalizedStringKey(resultKey)).font(.headline)
                    .accessibilityIdentifier("playkit.estimate.result")
            }
        }
        // The completed projection does not return the player's guess; no picker is shown as if it were.
        if !projection.complete {
            if let wheel = PlayKitEstimateWheel(segment: raw) {
                let unit = raw["unit"].text ?? ""
                let index = nativeEstimateIndex(wheel)
                Section {
                    LabeledContent {
                        Text(verbatim: PlayGameNumber.text(wheel.minimum, unit: unit) + " – " + PlayGameNumber.text(wheel.maximum, unit: unit))
                    } label: {
                        Text("playkit.estimate.range")
                    }
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
        guard !projection.complete, let wheel = PlayKitEstimateWheel(segment: raw) else { return nil }
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
            if let photo = raw["photoUrl"].text, !photo.isEmpty {
                artwork(photo).frame(maxWidth: 120, alignment: .leading)
                    .accessibilityLabel(Text("playkitLegacy.name.photo"))
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

    @ViewBuilder var nativeNote: some View {
        let limit = PlayKitShortMessageLimit.resolve(raw["maxLength"])
        let previous = (raw["previous"].array ?? []).filter { !($0["text"].text ?? "").isEmpty }
        if !previous.isEmpty {
            Section {
                ForEach(Array(previous.enumerated()), id: \.offset) { _, note in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: note["text"].text ?? "")
                        if let at = note["at"].double, at.isFinite {
                            Text(Date(timeIntervalSince1970: at / 1000), style: .date).font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("playkit.note.previousLabel")
            }
        }
        let presets = (raw["presets"].array ?? []).compactMap(\.text).filter { !$0.isEmpty }
        Section {
            TextField("playkit.note.placeholder", text: textBinding(limit: limit), axis: .vertical)
                .lineLimit(3...8)
                .disabled(!enabled)
                .accessibilityIdentifier("playkit.note.field")
            if !presets.isEmpty {
                Menu {
                    ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                        Button(preset) { text = PlayKitInputContract.limitText(preset, toUTF16: limit); dirty = true }
                    }
                } label: {
                    Label("nativeGames.note.presets", systemImage: "text.bubble")
                }
                .disabled(!enabled)
                .accessibilityIdentifier("nativeGames.note.presets")
            }
        } footer: {
            Text("playkit.note.audience")
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
                LabeledContent {
                    Text(verbatim: shown.isEmpty ? "—" : shown)
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
        } else if step > 0 {
            Section {
                Button { profileStep = step - 1 } label: { Label("playkit.profile.previous", systemImage: "chevron.backward") }
                    .disabled(!enabled)
                    .accessibilityIdentifier("playkit.profile.previous")
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
            Text("playkit.profile.required")
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
