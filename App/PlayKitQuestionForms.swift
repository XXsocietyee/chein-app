import SwiftUI

extension PlayKitScreen {
    @ViewBuilder var qaForm: some View {
        artwork(raw["imageUrl"].text)
        PlatformAudioHost(rawURL: raw["audioUrl"].text, scope: mediaScope, makeModel: makeAudio)
        let mode = (raw["mode"].text ?? "TYPE").uppercased()
        if mode == "SHOT" {
            if let note = raw["shotNote"].text { Text(verbatim: note) }
            photoInput { url in prepare("SUBMIT_QA", ["imageUrl": .string(url)]) }
        } else if mode == "PICK" {
            let multi = raw["multi"].bool == true
            if multi { Text("playkit.qa.multiHint").cyText(.bodyCompact) }
            if let pictures = PlayKitImageOption.read(raw) {
                // UG-02: two picture cards per row, key and label under the picture. Judgement stays on the option id.
                LazyVGrid(columns: [GridItem(.flexible(), spacing: CYSpacing.md), GridItem(.flexible(), spacing: CYSpacing.md)], spacing: CYSpacing.md) {
                    ForEach(pictures) { option in
                        PlayKitImageOptionCard(option: option, selected: selected.contains(option.id), multi: multi, enabled: enabled,
                                               approvedHosts: approvedArtworkHosts) { toggle(option.id, multi: multi) }
                    }
                }
                .accessibilityIdentifier("playkit.qa.pictures")
            } else {
                ForEach(Array(projection.options.enumerated()), id: \.element.id) { index, option in
                    let marker = PlayKitImageOption.letter(at: index)
                    CYChoiceRow(label: PlayKitImageOption.stripDuplicateKey(option.label, key: marker),
                                selected: selected.contains(option.id), multi: multi, enabled: enabled, marker: marker) { toggle(option.id, multi: multi) }
                }
            }
            submitButton("SUBMIT_QA", payload: multi ? ["optionIds": .array(selected.sorted().map(PlayWireValue.string))] : ["optionId": .string(selected.first ?? "")], valid: !selected.isEmpty)
        } else if raw["letterPool"] != .null {
            PlayKitQuestionLetterPoolView(segment: raw, revision: runtimeIdentity, enabled: enabled,
                onDirty: { dirty = true }, requestReview: prepare)
                .id(childReset)
            wrongReply
        } else {
            TextField("playkit.qa.answer", text: textBinding(), axis: .vertical).cyField().disabled(!enabled)
            wrongReply
            if let howTo = raw["howTo"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !howTo.isEmpty {
                PlayKitHowToButton(text: howTo, identifier: "playkit.qa.howTo")
            }
            submitButton("SUBMIT_QA", payload: ["input": .string(text)], valid: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        if let answer = raw["answerId"].text, !answer.isEmpty, projection.complete {
            LabeledContent("playkit.qa.revealedAnswer") { Text(verbatim: projection.options.first { $0.id == answer }?.label ?? answer) }
        }
        attempts
    }
    @ViewBuilder var branchForm: some View {
        if let echo = CastBranchEcho(branch: raw) {
            CastBranchEchoLabel(echo: echo, config: castContext?.config)
        }
        if let title = raw["currentStep"]["title"].text { Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader) }
        if let body = raw["currentStep"]["body"].text { Text(verbatim: body).cyText(.body).foregroundStyle(CYColor.textSecondary) }
        if projection.options.isEmpty, !projection.complete {
            ContentUnavailableView("playkit.branch.waiting", systemImage: "arrow.triangle.branch")
                .accessibilityIdentifier("playkit.branch.waiting")
        }
        ForEach(projection.options) { option in
            CYChoiceRow(label: option.label, selected: false, enabled: enabled) { prepare("CHOOSE", ["optionId": .string(option.id)]) }
        }
        if projection.complete { Text("playkit.branch.ended") }
    }
    @ViewBuilder var wrongReply: some View {
        if let reply = PlayKitWrongReply.text(segment: raw) {
            Text(verbatim: reply).font(.footnote).foregroundStyle(.secondary)
                .accessibilityIdentifier("playkit.qa.wrongReply")
        }
    }
    @ViewBuilder var estimateForm: some View {
        // Read only the current accepted node projection, with no cached tier.
        if model.isCurrent, !["stale", "disabled"].contains(model.phase),
           let resultKey = projection.estimateResultKey {
            Text(LocalizedStringKey(resultKey)).cyText(.cardTitle)
                .accessibilityIdentifier("playkit.estimate.result")
        }
        // The completed projection does not return the player's guess. Do not
        // present a newly centered picker as if it were their submitted value.
        if !projection.complete {
            if let wheel = PlayKitEstimateWheel(segment: raw) {
                PlayKitEstimateWheelForm(wheel: wheel, unit: raw["unit"].text ?? "", enabled: enabled,
                                         onDirty: { dirty = true }, requestReview: prepare)
                    .id("\(runtimeIdentity):\(wheel.minimum):\(wheel.maximum):\(childReset)")
            } else { Text("playkit.configurationInvalid") }
        }
        attempts
    }
    @ViewBuilder var pricePairForm: some View {
        // Recomputed from the current accepted state; never from a local pick or
        // a cached receipt. Invalidated owner/scope states reveal no old result.
        let result = model.isCurrent && !["stale", "disabled"].contains(model.phase)
            ? PlayKitPricePairResult(segment: raw) : nil
        ForEach(projection.options) { option in
            VStack(alignment: .leading, spacing: 12) {
                artwork(option.raw["imageUrl"].text)
                Text(verbatim: option.label).cyText(.cardTitle)
                if let note = option.raw["note"].text { Text(verbatim: note) }
                if let result, result.lastPickID == option.id {
                    Label(result.passed ? "playkit.pricePair.lastCorrect" : "playkit.pricePair.lastIncorrect",
                          systemImage: result.passed ? "checkmark.seal" : "xmark.seal")
                        .accessibilityIdentifier("playkit.pricePair.lastPick." + option.id)
                }
                if let result, result.answerID == option.id {
                    Label("playkit.pricePair.revealedAnswer", systemImage: "checkmark.circle.fill")
                        .accessibilityIdentifier("playkit.pricePair.answer." + option.id)
                }
                Button { toggle(option.id, multi: false) } label: {
                    Label(selected.contains(option.id) ? "playkit.pricePair.currentChoice" : "playkit.select",
                          systemImage: selected.contains(option.id) ? "circle.inset.filled" : "circle")
                }.disabled(!enabled)
                    .accessibilityLabel(Text(verbatim: option.label))
                    .accessibilityValue(Text(selected.contains(option.id) ? "playkit.pricePair.currentChoice" : "playkit.select"))
            }.padding(CYSpacing.lg).background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
        if let result, !result.passed {
            Text(result.finished ? "playkit.pricePair.ended" : "playkit.pricePair.retry")
                .accessibilityIdentifier("playkit.pricePair.roundStatus")
        }
        submitButton("SUBMIT_PRICE_PAIR", payload: ["pickId": .string(selected.first ?? "")], valid: !selected.isEmpty)
        attempts
    }
    @ViewBuilder var hiddenObjectForm: some View {
        let found = Set((raw["foundIds"].array ?? []).compactMap(\.text))
        ForEach(PlayKitOption.read(raw["targets"])) { target in
            Label { Text(verbatim: target.label) } icon: { Image(systemName: found.contains(target.id) || target.raw["found"].bool == true ? "checkmark.circle.fill" : "circle") }
        }
        if let url = QuestifyCardArtwork.safeURL(raw["imageUrl"].text), let host = url.host, approvedArtworkHosts.contains(host) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFit().overlay {
                        // The overlay follows the fitted image's actual rectangle, not its outer container.
                        GeometryReader { geometry in
                            Color.clear.contentShape(Rectangle())
                                .gesture(SpatialTapGesture().onEnded { event in
                                    guard enabled, let point = PlayKitInputContract.imagePoint(x: Double(event.location.x), y: Double(event.location.y), viewWidth: Double(geometry.size.width), viewHeight: Double(geometry.size.height), imageWidth: Double(geometry.size.width), imageHeight: Double(geometry.size.height)) else { return }
                                    prepare("SUBMIT_HIDDEN_OBJECT", ["x": .number(point.0), "y": .number(point.1)])
                                })
                        }
                    }.accessibilityLabel(Text("playkit.hidden.scene"))
                        .accessibilityHint(Text("playkit.hidden.hint"))
                        .accessibilityAction(named: Text("playkit.hidden.center")) {
                            if enabled { prepare("SUBMIT_HIDDEN_OBJECT", ["x": .number(0.5), "y": .number(0.5)]) }
                        }
                }                 else if phase.error != nil {
                    ContentUnavailableView {
                        Label("playkit.imageUnavailable", systemImage: "photo.badge.exclamationmark")
                    } actions: {
                        Button("playkit.imageRetry") { childReset = UUID() }
                    }
                }
                else { PlayGameImagePlaceholder(titleKey: "playkit.hidden.scenePending", loading: true) }
            }
            .id(childReset)
        } else { PlayGameImagePlaceholder(titleKey: "playkit.hidden.scenePending", systemImage: "photo") }
        attempts
    }
    @ViewBuilder var predictForm: some View {
        if let mine = raw["myOptionKey"].text, !mine.isEmpty {
            LabeledContent("playkit.predict.mine") { Text(verbatim: projection.options.first { $0.id == mine }?.label ?? mine) }
        } else {
            ForEach(projection.options) { option in
                CYChoiceRow(label: option.label, selected: selected.contains(option.id), enabled: enabled) { toggle(option.id, multi: false) }
            }
            submitButton("SUBMIT_PREDICT", payload: ["optionKey": .string(selected.first ?? "")], valid: !selected.isEmpty)
        }
        if let status = raw["settleStatus"].integer {
            if status == 2 { Text("playkit.predict.voided") }
            else if status == 1 {
                Text(raw["won"].bool == true ? "playkit.predict.won" : "playkit.predict.lost")
                let answer = raw["settledOption"].text ?? ""
                LabeledContent("playkit.predict.answer") { Text(verbatim: projection.options.first { $0.id == answer }?.label ?? answer) }
            } else { Text("playkit.predict.wait") }
        }
        if let days = raw["revealDays"].integer, days >= 0 { LabeledContent("playkit.predict.revealDays") { Text(verbatim: String(days)) } }
        if let hour = raw["revealHour"].integer, (0...23).contains(hour) { LabeledContent("playkit.predict.revealHour") { Text(verbatim: String(hour)) } }
    }
    @ViewBuilder var attempts: some View {
        let used = raw["attempts"].integer ?? raw["tries"].integer
        if let cap = raw["maxTries"].integer ?? raw["maxAttempts"].integer, cap > 0 {
            // Mini-program "还能错 ●●●": one dot per remaining try.
            let left = max(0, cap - (used ?? 0))
            HStack(spacing: CYSpacing.xs) {
                Text("playkit.triesLeft").cyText(.meta).foregroundStyle(.secondary)
                if cap <= 10 {
                    ForEach(0..<cap, id: \.self) { index in
                        Circle().fill(index < left ? Color.primary : Color.secondary.opacity(0.3)).frame(width: 8, height: 8)
                    }
                } else { Text(verbatim: "\(left) / \(cap)").cyText(.meta).monospacedDigit() }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("playkit.triesLeft"))
            .accessibilityValue(Text("a11y.value.ofTotal \(left) \(cap)"))
            .accessibilityIdentifier("playkit.triesLeft")
        } else if let used { LabeledContent("playkit.attempts") { Text(verbatim: String(used)) } }
    }
    private func toggle(_ id: String, multi: Bool) {
        if multi { if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } }
        else { selected = [id] }
        dirty = true
    }
}

/// Native wheel interaction for estimate, using only the server's public range.
/// A new authoritative session/version remounts this form; cancelling its frozen
/// review keeps the selected tick. There is no local judgement or score.
@MainActor struct PlayKitEstimateWheelForm: View {
    let wheel: PlayKitEstimateWheel
    let unit: String
    let enabled: Bool
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest
    @State private var selectedIndex: Int
    @ScaledMetric(relativeTo: .title2) private var wheelHeight: CGFloat = 180
    init(wheel: PlayKitEstimateWheel, unit: String, enabled: Bool,
         onDirty: @escaping () -> Void, requestReview: @escaping PlayKitReviewRequest) {
        self.wheel = wheel; self.unit = unit; self.enabled = enabled
        self.onDirty = onDirty; self.requestReview = requestReview
        _selectedIndex = State(initialValue: wheel.initialIndex)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("playkit.estimate.range") {
                Text(verbatim: PlayGameNumber.text(wheel.minimum, unit: unit) + " – " + PlayGameNumber.text(wheel.maximum, unit: unit))
            }
            Picker("playkit.estimate.value", selection: $selectedIndex) {
                ForEach(wheel.ticks.indices, id: \.self) { index in
                    Text(verbatim: PlayGameNumber.text(wheel.ticks[index], unit: unit))
                        .lineLimit(1).minimumScaleFactor(0.5).tag(index)
                }
            }.pickerStyle(.wheel).frame(height: wheelHeight).disabled(!enabled)
                .accessibilityIdentifier("playkit.estimate.wheel")
            Button("playkit.review") {
                guard enabled, let value = wheel.value(at: selectedIndex) else { return }
                requestReview("SUBMIT_ESTIMATE", ["value": .number(value)], {})
            }.buttonStyle(.borderedProminent).disabled(!enabled || wheel.value(at: selectedIndex) == nil)
                .accessibilityIdentifier("playkit.submit.estimate")
        }.onChange(of: selectedIndex) { _, _ in onDirty() }
    }
}

/// UG-02 picture option. The picture has a fixed square frame so selection never shifts the grid; a picture
/// this build cannot load shows the option key instead of a broken image. The label is the spoken name.
@MainActor struct PlayKitImageOptionCard: View {
    let option: PlayKitImageOption
    let selected: Bool
    let multi: Bool
    let enabled: Bool
    let approvedHosts: Set<String>
    let action: () -> Void
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Color.clear.aspectRatio(1, contentMode: .fit)
                    .overlay { picture }
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                        .strokeBorder(selected ? CYColor.textPrimary : CYColor.borderSubtle, lineWidth: selected ? 2 : 1))
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                    Text(verbatim: option.key).cyText(.label).foregroundStyle(CYColor.textTertiary)
                    Text(verbatim: option.label).cyText(.body).foregroundStyle(CYColor.textPrimary)
                        .lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .offset(y: selected && !reduceMotion ? -2 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("playkit.qa.pictureOption \(option.key) \(option.spokenDescription)"))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("playkit.qa.picture." + option.id)
    }

    @ViewBuilder private var picture: some View {
        if let url = QuestifyCardArtwork.safeURL(option.image), let host = url.host, approvedHosts.contains(host) {
            AsyncImage(url: url) { phase in
                if let image = phase.image { image.resizable().scaledToFill() }
                else if phase.error != nil { keyPlaceholder }
                else { ZStack { CYColor.bgRaised; ProgressView() } }
            }
        } else { keyPlaceholder }
    }

    private var keyPlaceholder: some View {
        ZStack {
            CYColor.bgRaised
            Text(verbatim: option.key).cyText(.pageTitle).foregroundStyle(CYColor.textTertiary)
        }
    }
}
