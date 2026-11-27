import SwiftUI

@MainActor struct JourneyNarrativeView: View {
    /// a11y-dt r3: the found-count ring grows with Dynamic Type (capped so the n / total column keeps room beside it).
    @ScaledMetric(relativeTo: .title) private var progressRing: CGFloat = 88
    @Bindable var model: JourneyNarrativeCoordinator
    var imageReader: (any RetainedPublicImageReading)? = nil
    var makeAudio: (@MainActor () -> PlatformAudioPlayback)? = nil
    var mediaScope = UUID()
    var onChanged: (() async -> Void)? = nil
    var body: some View {
        List {
            CYCoverHeaderSection(LocalizedStringKey(model.query.titleKey), symbol: "book.closed.fill", seed: model.query.key)
            if model.busy { CYSkeleton().accessibilityLabel(Text("journey.working")) }
            if let issue = model.issue { Text(LocalizedStringKey(issue)).accessibilityIdentifier("journey.record.error") }
            if !model.pending.isEmpty { Text("journey.record.unknown").accessibilityIdentifier("journey.record.pending") }
            if let receipt = model.receipt {
                Section("journey.record.answer") { Text(verbatim: receipt.question); Text(verbatim: receipt.answer) }
            }
            if let dialogueReceipt = model.dialogueReceipt {
                Section("journey.record.dialogue") {
                    Text(verbatim: dialogueReceipt.reply)
                    if let relation = dialogueReceipt.relation { relationRow(relation) }
                    effectRows(dialogueReceipt.effects)
                }
            }
            if let document = model.document { content(document) }
            Button("journey.record.refresh") { Task { await model.load() } }.disabled(model.busy || !model.available)
                .accessibilityIdentifier("journey.record.refresh")
        }.cyGroupedSurface()
        .navigationTitle(LocalizedStringKey(model.query.titleKey)).navigationBarTitleDisplayMode(.inline).privacySensitive()
        .accessibilityIdentifier("journey.record." + model.query.key)
        .task(id: model.identity) { await model.load() }
        .refreshable { await model.load() }
        .onDisappear { model.dismiss() }
        .onChange(of: model.acknowledgedRevision) { _, _ in Task { await onChanged?() } }
        .cySheet(item: Binding(get: { model.review }, set: { if $0 == nil && model.review != nil { model.cancelReview() } })) { review in
            NavigationStack {
                Form {
                    Text(verbatim: review.question.question)
                    Text("journey.record.askImpact")
                    Button("journey.confirm") { Task { await model.confirm(review) } }.disabled(model.busy)
                        .accessibilityIdentifier("journey.record.confirm")
                }.cyGroupedSurface().navigationTitle("journey.record.questions").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("journey.cancel") { model.cancelReview() }.disabled(model.busy) } }
            }.interactiveDismissDisabled(model.busy)
        }
        .cyDomainScreen(.player)
    }
    @ViewBuilder private func content(_ document: JourneyNarrativeDocument) -> some View {
        switch document {
        case .casebook(let value):
            progress(found: value.found, total: value.total)
            lines("journey.record.facts", value.facts)
            relations(value.relations)
            if !value.effects.isEmpty {
                Section("journey.record.effects") { effectRows(value.effects) }
            }
            lines("journey.record.costs", value.costs)
            Section("journey.record.log") {
                if value.log.isEmpty { Text("journey.record.empty") }
                ForEach(Array(value.log.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: item.text)
                        if let at = item.at { Text(Date(timeIntervalSince1970: Double(at) / 1000), style: .date).cyText(.meta) }
                        LabeledContent("journey.hp", value: String(item.hpDelta)); LabeledContent("journey.luck", value: String(item.luckDelta))
                    }
                }
            }
        case .backpack(let items):
            Text("journey.record.rewardAuthority").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            if items.isEmpty { Text("journey.record.empty") }
            ForEach(items) { item in
                Section {
                    LabeledContent("journey.record.node", value: String(item.id))
                    if let reward = item.reward { Text(verbatim: reward) }
                    Text(LocalizedStringKey("journey.record.reward." + item.status))
                    if let at = item.claimableAt { Text(Date(timeIntervalSince1970: Double(at) / 1000), style: .date) }
                }.accessibilityIdentifier("journey.record.reward.\(item.id)")
            }
        case .stage(let value):
            lines("journey.record.changed", value.changed)
            if let open = value.open { Section("journey.record.next") { Text(verbatim: open) } }
            lines("journey.record.costs", value.costs)
            Section { if let hp = value.hp { LabeledContent("journey.hp", value: String(hp)) }; if let luck = value.luck { LabeledContent("journey.luck", value: String(luck)) } }
        case .ending(let value): ending(value)
        case .questions(let value):
            if let opener = value.opener { Text(verbatim: opener) }
            if let aside = value.aside { Text(verbatim: aside).foregroundStyle(.secondary) }
            if value.questions.isEmpty { Text("journey.record.empty") }
            ForEach(value.questions) { question in
                Section {
                    Text(verbatim: question.question).cyText(.cardTitle)
                    if question.asked {
                        if let answer = question.answer { Text(verbatim: answer) }
                    } else {
                        Button("journey.record.ask") { model.prepare(question.id) }
                            .buttonStyle(.bordered).controlSize(.large).disabled(!model.canAsk || model.pending.contains(question.id)).accessibilityIdentifier("journey.record.ask." + question.id)
                    }
                }
            }
            if !model.canAsk { Text("journey.record.actionGate").cyText(.bodyCompact) }
        }
    }
    private func progress(found: Int, total: Int) -> some View {
        HStack(spacing: CYSpacing.lg) {
            CYProgressRing(progress: total > 0 ? Double(found) / Double(total) : nil, lineWidth: 9) {
                Text(verbatim: "\(found)").cyText(.dataXL).foregroundStyle(CYColor.textPrimary)
                    .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, CYSpacing.xs)
            }.frame(width: min(progressRing, 132), height: min(progressRing, 132))
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: "\(found) / \(total)").cyText(.data2XL).foregroundStyle(CYColor.textPrimary)
                    .minimumScaleFactor(0.6).lineLimit(1)
                Text("journey.record.discoveries").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            }
        }.accessibilityElement(children: .combine)
            .sensoryFeedback(.success, trigger: total > 0 && found == total)
    }
    private func lines(_ key: LocalizedStringKey, _ values: [String]) -> some View {
        Section(key) { if values.isEmpty { Text("journey.record.empty") }; ForEach(Array(values.enumerated()), id: \.offset) { _, text in Text(verbatim: text) } }
    }
    private func relations(_ values: [JourneyRecordRelation]) -> some View {
        Section("journey.record.relations") {
            if values.isEmpty { Text("journey.record.empty") }
            ForEach(Array(values.enumerated()), id: \.offset) { _, item in
                relationRow(item)
            }
        }
    }
    private func relationRow(_ item: JourneyRecordRelation) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.sm) {
                if let name = item.name { Text(verbatim: name).cyText(.cardTitle) }
                Spacer(minLength: CYSpacing.xs)
                CYStatusChip(
                    LocalizedStringKey("journey.record.relation." + item.state),
                    tone: relationTone(item.state),
                    systemImage: relationSymbol(item.state)
                )
                .accessibilityIdentifier("journeyRelationBadge.\(item.state)")
            }
            if let line = item.line { Text(verbatim: line) }
        }
    }
    @ViewBuilder private func effectRows(_ effects: [JourneyDialogueEffect]) -> some View {
        ForEach(effects) { effect in
            HStack(spacing: CYSpacing.sm) {
                CYStatusChip(
                    verbatim: effectChipText(effect),
                    tone: effectTone(effect),
                    systemImage: effectSymbol(effect)
                )
                .accessibilityIdentifier("journeyEffectReceipt.\(effect.key)")
                if let label = effect.label, !label.isEmpty {
                    Text(verbatim: label).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
            }
        }
    }
    private func relationTone(_ state: String) -> CYStatusTone {
        switch state { case "ally": return .success; case "guarded": return .warning; default: return .info }
    }
    private func relationSymbol(_ state: String) -> String {
        switch state { case "ally": return "heart.fill"; case "guarded": return "shield.fill"; default: return "person.2" }
    }
    private func effectChipText(_ effect: JourneyDialogueEffect) -> String {
        switch effect.type {
        case .inc:
            let delta = effect.delta ?? 0
            return delta > 0 ? "\(effect.key) +\(delta)" : "\(effect.key) \(delta)"
        case .addTag:
            return effect.key
        }
    }
    private func effectTone(_ effect: JourneyDialogueEffect) -> CYStatusTone {
        switch effect.type {
        case .inc: return (effect.delta ?? 0) >= 0 ? .success : .warning
        case .addTag: return .info
        }
    }
    private func effectSymbol(_ effect: JourneyDialogueEffect) -> String {
        switch effect.type {
        case .inc: return (effect.delta ?? 0) >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
        case .addTag: return "tag.fill"
        }
    }
    @ViewBuilder private func ending(_ value: JourneyEndingDocument) -> some View {
        if let title = value.title { CYHeroHeader(verbatim: title) }
        if let summary = value.summary { Text(verbatim: summary).cyText(.body).foregroundStyle(CYColor.textSecondary) }
        if let badge = value.badgeTitle { Section("journey.record.badge") { Text(verbatim: badge) } }
        progress(found: value.found, total: value.total)
        relations(value.epilogues); lines("journey.record.exhibits", value.exhibits); lines("journey.record.costs", value.costs)
        Section("journey.record.archive") {
            ForEach(Array(value.identity.enumerated()), id: \.offset) { _, item in LabeledContent { Text(verbatim: item.text ?? "") } label: { Text(verbatim: item.title) } }
            ForEach(Array(value.notes.enumerated()), id: \.offset) { _, item in VStack(alignment: .leading) { Text(verbatim: item.title).cyText(.cardTitle); Text(verbatim: item.text ?? "") } }
            ForEach(Array(value.photos.enumerated()), id: \.offset) { _, item in
                if let url = item.text { photo(url, title: item.title) }
            }
        }
        if value.chapter.object != nil { JourneyEndingChapterView(raw: value.chapter, imageReader: imageReader, makeAudio: makeAudio, mediaScope: mediaScope) }
    }
    @ViewBuilder private func photo(_ url: String, title: String) -> some View {
        if !title.isEmpty { Text(verbatim: title) }
        if let imageReader { RetainedPublicReviewImages(urls: [url], reader: imageReader) }
        else { Label("journey.record.mediaGate", systemImage: "photo") }
    }
}

/// Only server-projected ending blocks are accepted here. Never evaluate creator
/// conditions or expose internal variables/tags in a player ending.
@MainActor private struct JourneyEndingChapterView: View {
    let raw: PlayWireValue
    let imageReader: (any RetainedPublicImageReading)?
    let makeAudio: (@MainActor () -> PlatformAudioPlayback)?
    let mediaScope: UUID
    @State private var audioURL: String?
    var body: some View {
        Section("journey.record.endingChapter") {
            if let title = raw["name"].text { Text(verbatim: title).cyText(.cardTitle) }
            ForEach(Array((raw["blocks"].array ?? []).enumerated()), id: \.offset) { _, block in
                switch block["type"].text {
                case "text" where block["optional"].bool == true:
                    let paragraphs = (block["content"].text ?? "").components(separatedBy: .newlines).compactMap { line -> String? in
                        let line = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        return line.isEmpty ? nil : line
                    }
                    if !paragraphs.isEmpty {
                        ChapterOptionalReadingCard(subtitle: block["who"].text, paragraphs: paragraphs)
                    }
                case "text", "voice", "reveal":
                    if let who = block["who"].text { Text(verbatim: who).cyText(.meta) }
                    if let content = block["content"].text { Text(verbatim: content) }
                case "image": if let url = block["url"].text { image(url) }
                case "audio": if let url = block["url"].text { Button("chapterStory.listen") { audioURL = url } }
                case "dream":
                    if let title = block["title"].text { Text(verbatim: title).cyText(.cardTitle) }
                    ForEach(Array((block["images"].array ?? []).enumerated()), id: \.offset) { _, item in
                        if let url = item["url"].text { image(url) }; if let line = item["line"].text { Text(verbatim: line) }
                    }
                default: EmptyView()
                }
            }
            if audioURL != nil { PlatformAudioHost(rawURL: audioURL, scope: mediaScope, makeModel: makeAudio) }
        }.onDisappear { audioURL = nil }
    }
    @ViewBuilder private func image(_ url: String) -> some View {
        if let imageReader { RetainedPublicReviewImages(urls: [url], reader: imageReader) }
        else { Label("journey.record.mediaGate", systemImage: "photo") }
    }
}
