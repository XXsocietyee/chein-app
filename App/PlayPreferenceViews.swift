import SwiftUI

@MainActor struct PlayPreferenceView: View {
    @Bindable var model: PlayPreferenceCoordinator
    var onFinished: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var useExisting = true
    @State private var selectedTagID = 0
    @State private var review: PlayPreferenceReview?
    @State private var confirm = false
    @State private var tagConfirm = false
    @State private var tagSheetShow = false
    @State private var correctedValue = ""
    @State private var error: PlayExperienceError?
    /// Mini-program shows one calibration question at a time; a server tiebreak jumps to the new last step.
    @State private var stepIndex = 0
    @State private var pickFirst = false
    @ViewBuilder var body: some View {
        if !model.hasCurrentReadLifetime { Text("playMode.recoveryBlocked") }
        else { currentContent }
    }
    private var currentContent: some View {
        List {
            Section {
                PlayRuntimePhaseText(phase: model.phase)
                if let issue = model.issue ?? error { PlayExperienceIssueView(issue: issue) }
                if model.phase == "unknown" {
                    Text("playx.unknown.body")
                    CYPillButton("playx.reconcile", style: .secondary) { Task { await model.load() } }.listRowBackground(Color.clear)
                    if model.canRetryExact { Button("playx.retryExact") { Task { await model.retryExact() } } }
                }
            }
            if let submission = model.submission, !submission.needsTiebreak {
                Section("playx.preference.result") {
                    if let title = submission.evaluation["title"].text { Text(verbatim: title).cyText(.cardTitle) }
                    if let body = submission.evaluation["body"].text { Text(verbatim: body) }
                    if let next = submission.evaluation["nextStep"].text, !next.isEmpty { Text(verbatim: next) }
                    if let days = submission.evaluation["nextStepDays"].tolerantInteger { LabeledContent("playx.preference.days") { Text(verbatim: String(days)) } }
                }
                PlayRewardSection(reward: submission.progress)
                if let tag = model.pendingTag {
                    Section("playx.preference.tag") {
                        Text(verbatim: tag.code + " · " + tag.value)
                        if let purpose = submission.disclosure["purpose"].text { LabeledContent { Text(verbatim: purpose) } label: { Text("playx.preference.purpose") } }
                        if let recipient = submission.disclosure["recipientLabel"].text { LabeledContent { Text(verbatim: recipient) } label: { Text("playx.preference.recipient") } }
                        if tag.status == 1 { CYStatusChip("playx.preference.confirmed", tone: .success, systemImage: "checkmark.seal") }
                        else { Button("playx.preference.confirmTag") { correctedValue = ""; tagConfirm = true }.disabled(model.phase != "completed" || !submission.canDiscloseTag) }
                        if submission.availableTagValues.count >= 2 {
                            Picker("playx.preference.correctValue", selection: $correctedValue) {
                                Text("playx.choose").tag("")
                                ForEach(submission.availableTagValues, id: \.self) { value in Text(verbatim: value).tag(value) }
                            }
                            Button("playx.preference.correctTag") { tagConfirm = true }
                                .disabled(correctedValue.isEmpty || correctedValue == tag.value || model.phase != "completed" || !submission.canDiscloseTag)
                            Button {
                                tagSheetShow = true
                            } label: {
                                Text(verbatim: PlayCloseCopy.text("改成哪个结果", "Choose another outcome", locale))
                            }
                            .disabled(model.phase != "completed" || !submission.canDiscloseTag)
                            .accessibilityIdentifier("playx.preference.tagSheetButton")
                        }
                    }
                }
            } else if model.phase == "completed" { Section { Text("playx.preference.completedNoResult") } }
            else if !model.steps.isEmpty || !model.inheritedTags.isEmpty {
                if !model.inheritedTags.isEmpty && useExisting {
                    Section("playx.preference.inherit") {
                        Text("playx.preference.inherit.detail")
                        Picker("playx.preference.tag", selection: $selectedTagID) {
                            Text("playx.choose").tag(0)
                            ForEach(model.inheritedTags) { tag in Text(verbatim: tag.code + " · " + tag.value).tag(tag.id) }
                        }
                        Button("playx.preference.reuse") { prepare(reuse: selectedTagID) }.disabled(selectedTagID <= 0 || model.phase != "ready")
                        Button("playx.preference.answerAgain") { useExisting = false }.disabled(model.phase != "ready" || model.steps.isEmpty)
                    }
                } else {
                    let index = min(stepIndex, max(0, model.steps.count - 1))
                    if model.steps.indices.contains(index) {
                        let step = model.steps[index]
                        Section {
                            // Mini-program calibration header: "装机校准 i / n", question, then option cards.
                            Text("playx.preference.stepCount \(index + 1) \(model.steps.count)")
                                .cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
                            Text(verbatim: step.title).cyText(.cardTitle)
                            if step.type == "discard" { Text("playx.preference.discard").cyText(.meta).foregroundStyle(.secondary) }
                            VStack(spacing: CYSpacing.sm) {
                                ForEach(step.options) { option in
                                    let on = model.choices[step.id] == option.id
                                    Button { model.select(stepID: step.id, optionID: option.id); pickFirst = false } label: {
                                        HStack {
                                            Text(verbatim: option.text).cyText(.body).foregroundStyle(Color.primary)
                                            Spacer(minLength: CYSpacing.sm)
                                            if on { Image(systemName: "checkmark.circle").accessibilityHidden(true) }
                                        }
                                        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 52)
                                        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(on ? CYColor.bgRaised : Color.clear))
                                        .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(on ? Color.primary.opacity(0.8) : CYNight.glassEdgeTop))
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                                    .accessibilityIdentifier("playx.preference.option.\(step.id).\(option.id)")
                                }
                            }
                            .disabled(model.phase != "ready")
                            .accessibilityIdentifier("playx.preference.step.\(step.id)")
                            if pickFirst {
                                Text("playx.preference.pickFirst").cyText(.meta).foregroundStyle(CYColor.dangerText)
                                    .accessibilityIdentifier("playx.preference.pickFirst")
                            }
                        }
                        .id(step.id)
                        let last = index >= model.steps.count - 1
                        CYPillButton(last ? "playx.preference.generate" : "playx.preference.next") {
                            guard model.choices[step.id] != nil else { pickFirst = true; return }
                            pickFirst = false
                            if last { prepare(reuse: nil) } else { stepIndex = index + 1 }
                        }
                        .listRowBackground(Color.clear).disabled(model.phase != "ready")
                        .accessibilityIdentifier(last ? "playx.preference.review" : "playx.preference.next")
                    }
                }
            }
            if model.phase == "completed" { CYPillButton("playx.preference.done") { dismiss() }.listRowBackground(Color.clear) }
            if model.phase == "failed" || model.phase == "idle" { Button("playx.refresh") { Task { await model.load() } } }
        }.cyGroupedSurface().privacySensitive().navigationTitle("playx.preference.title").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("playx.preference.view")
            .task { await model.load() }
            .onChange(of: model.steps.count) { old, new in
                // A tiebreak step appended by the server is answered next; a reload starts over.
                stepIndex = new > old && old > 0 ? new - 1 : min(stepIndex, max(0, new - 1))
                pickFirst = false
            }
            .cyModalConfirm(
                isPresented: confirm,
                title: appLocalized("playx.review", locale: locale),
                message: appLocalized(String.LocalizationValue(stringLiteral: review?.reusedTagCode == nil ? "playx.preference.submitNotice" : "playx.preference.reuseNotice"), locale: locale),
                cancelTitle: appLocalized("playx.cancel", locale: locale),
                confirmTitle: appLocalized("playx.submit", locale: locale),
                onCancel: { confirm = false; model.cancelReview(); review = nil },
                onConfirm: {
                    confirm = false
                    if let review { Task { await model.submit(review); self.review = nil; useExisting = false } }
                }
            )
            .cyModalConfirm(
                isPresented: tagConfirm,
                title: appLocalized("playx.preference.tag", locale: locale),
                message: tagConfirmMessage,
                cancelTitle: appLocalized("playx.cancel", locale: locale),
                confirmTitle: appLocalized("playx.submit", locale: locale),
                onCancel: { tagConfirm = false },
                onConfirm: {
                    tagConfirm = false
                    Task { await model.writeTag(correctedValue: correctedValue.isEmpty ? nil : correctedValue) }
                }
            )
            .cySheet(isPresented: $tagSheetShow) {
                CYOptionSheet(
                    title: PlayCloseCopy.text("改成哪个结果", "Select outcome tag", locale),
                    items: (model.submission?.availableTagValues ?? []).map {
                        CYOptionSheetItem(id: $0, title: $0)
                    },
                    selectedID: correctedValue.isEmpty ? nil : correctedValue,
                    closeIdentifier: "playx.preference.tagSheet.close",
                    onSelect: { value in
                        correctedValue = value
                        tagSheetShow = false
                        tagConfirm = true
                    },
                    onClose: { tagSheetShow = false }
                )
                .cyDomainSheet(detents: [.half])
            }
            .onDisappear { model.cancelReview(); review = nil; onFinished() }
    }
    private var tagConfirmMessage: String {
        if let disclosure = model.submission?.disclosure,
           let recipient = disclosure["recipientLabel"].text, let purpose = disclosure["purpose"].text {
            return recipient + "\n" + purpose
        }
        return ""
    }
    private func prepare(reuse: Int?) {
        do { review = try model.review(reuseTagID: reuse); confirm = true; error = nil }
        catch { self.error = .invalidAction }
    }
}

@MainActor struct PlayOperatingSummaryView: View {
    @Bindable var model: PlayOperatingSummaryCoordinator
    @State private var sourceIsCurrent: @MainActor () -> Bool
    init(model: PlayOperatingSummaryCoordinator, sourceIsCurrent: @escaping @MainActor () -> Bool = { false }) {
        self.model = model
        // Preserve the entry read fence for this destination lifetime, even if the host rebuilds.
        _sourceIsCurrent = State(initialValue: sourceIsCurrent)
    }
    @StateObject private var presentation = PlayOperatingSummaryPresentation()
    @State private var confirm = false
    @Environment(\.scenePhase) private var scenePhase
    private struct ReadID: Equatable { let active: Bool; let current: Bool }
    var body: some View {
        Group {
            if scenePhase != .active { Color.clear }
            else if !sourceIsCurrent() { PlayExperienceIssueView(issue: .staleSession) }
            else { currentContent }
        }
        .privacySensitive().navigationTitle("playx.os.title").navigationBarTitleDisplayMode(.inline).accessibilityIdentifier("playx.os.view")
        .task(id: ReadID(active: scenePhase == .active, current: sourceIsCurrent())) {
            guard scenePhase == .active, sourceIsCurrent() else { presentation.retire(); return }
            presentation.activate()
            await presentation.load(model: model, current: sourceIsCurrent)
        }
        .onDisappear { confirm = false; presentation.retire() }
        .onChange(of: scenePhase) { _, next in
            if next != .active { confirm = false; presentation.retire() }
        }
        .onChange(of: sourceIsCurrent()) { _, current in
            if !current { confirm = false; presentation.retire() }
        }
        .onChange(of: presentation.review) { _, value in if value == nil { confirm = false } }
        .onChange(of: model.phase) { _, phase in
            if phase != "ready" { confirm = false; presentation.cancelRevocation() }
        }
        .cyModalConfirm(
            isPresented: confirm,
            title: appLocalized("playx.os.revoke", locale: .current),
            message: appLocalized("playx.os.revokeNotice", locale: .current),
            cancelTitle: appLocalized("playx.cancel", locale: .current),
            confirmTitle: appLocalized("playx.os.revoke", locale: .current),
            isDestructive: true,
            onCancel: { confirm = false; presentation.cancelRevocation() },
            onConfirm: {
                confirm = false
                if let review = presentation.review {
                    Task { await presentation.revoke(review, model: model, current: sourceIsCurrent) }
                }
            }
        )
    }
    private var currentContent: some View {
        List {
            Section {
                Text("playx.os.private").cyText(.meta).accessibilityIdentifier("playx.os.private")
                PlayRuntimePhaseText(phase: model.phase)
                if presentation.loading { CYSkeleton(label: "playx.loading") }
                if let issue = model.issue { PlayExperienceIssueView(issue: issue) }
                CYPillButton("playx.refresh", style: .secondary) {
                    Task { await presentation.load(model: model, current: sourceIsCurrent) }
                }.listRowBackground(Color.clear).disabled(presentation.loading || model.phase == "submitting")
                if !model.unresolvedTagIDs.isEmpty { Text("playx.unknown.body") }
            }
            if let summary = presentation.displayedSummary(model: model, current: sourceIsCurrent) {
                if let edition = summary.edition { Section { Text(verbatim: edition) } }
                if summary.isEmpty { ContentUnavailableView("playx.os.empty", systemImage: "tag") }
                Section("playx.os.tags") {
                    ForEach(summary.tags) { tag in
                        VStack(alignment: .leading) {
                            Text(verbatim: tag.value).accessibilityIdentifier("playx.os.tag.\(tag.id)")
                            if tag.revoked { Text("playx.os.revoked").cyText(.meta) }
                            else { Button("playx.os.revoke", role: .destructive) {
                                    presentation.prepareRevocation(tagID: tag.id, model: model, current: sourceIsCurrent)
                                    confirm = presentation.review != nil
                                }.disabled(model.phase != "ready")
                                 .disabled(presentation.loading || !model.unresolvedTagIDs.isEmpty)
                            }
                        }
                    }
                }
                ForEach(Array(summary.cards.enumerated()), id: \.offset) { _, card in
                    Section { if !card.title.isEmpty { Text(verbatim: card.title).cyText(.cardTitle) }; if !card.body.isEmpty { Text(verbatim: card.body) } }
                }
                Section("playx.os.anchors") {
                    if !summary.anchors.isEmpty { PlayPreferenceOriginalAnchorMap(anchors: summary.anchors) }
                    ForEach(Array(summary.anchors.enumerated()), id: \.offset) { _, anchor in
                        Text(verbatim: anchor.name).accessibilityLabel(Text(verbatim: anchor.name))
                    }
                }
                Section("playx.os.week") { ForEach(Array(summary.actions7Days.enumerated()), id: \.offset) { _, action in Text(verbatim: action) } }
                Section("playx.os.month") { ForEach(Array(summary.actions30Days.enumerated()), id: \.offset) { _, action in Text(verbatim: action) } }
            }
        }.cyGroupedSurface()
    }
}
