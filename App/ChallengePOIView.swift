import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - POI Challenge View (Ported from pages/play/poi-challenge/index.wxml & index.js)

/// Challenge screen: header, step checklist, photo + quiz inputs and a submit area.
/// The challenge write has no approved contract in this build, so the submit area always carries the
/// "not available yet" banner and `readyButBlocked` explains that a valid attempt was not sent.
@available(macOS 14.0, *)
@MainActor struct ChallengePOIView: View {
    @Bindable var coordinator: ChallengePOICoordinator
    let onRefresh: () async -> Void
    let onSubmit: () async -> Void
    /// Validation message from the last submit attempt (never a success message).
    var submitFeedback: String? = nil
    /// True when the last attempt passed local validation but could not be sent.
    var readyButBlocked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            switch coordinator.state {
            case .loading:
                ProgressView(LocalizedStringKey("playx.poi.loading"))
                    .frame(maxWidth: .infinity, minHeight: 160)

            case .error:
                CYErrorStateView(
                    title: LocalizedStringKey("playx.poi.loadFailed"),
                    message: LocalizedStringKey(coordinator.errorMessage.isEmpty ? W8Text.t("请检查网络连接后重试", "Check your connection and try again") : coordinator.errorMessage),
                    retryTitle: LocalizedStringKey("playx.poi.retry"),
                    onRetry: { Task { await onRefresh() } })

            case .photo, .quiz:
                if let node = coordinator.node {
                    headerCard(node)
                    checklistCard(node)

                    if !coordinator.errorMessage.isEmpty {
                        messageCard(coordinator.errorMessage, tone: .danger)
                    }

                    if coordinator.state == .photo || node.photoRequired {
                        photoCard
                    }

                    if coordinator.state == .quiz || !node.photoRequired {
                        quizCard(node)
                    }

                    submitArea
                }

            case .done:
                doneCard
            }
        }
    }

    // MARK: Cards

    private enum Tone { case danger, success }

    private func messageCard(_ text: String, tone: Tone) -> some View {
        Label(text, systemImage: tone == .danger ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(CYTypography.bodyCompact)
            .foregroundStyle(tone == .danger ? CYColor.dangerText : CYColor.successText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(CYSpacing.md)
            .background(tone == .danger ? CYColor.dangerSoft : CYColor.successSoft,
                        in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func headerCard(_ node: ChallengePOINode) -> some View {
        CYCard(variant: .elevated) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                HStack(alignment: .firstTextBaseline) {
                    Text(node.title.isEmpty ? node.name : node.title)
                        .font(CYTypography.sheetTitle)
                        .foregroundStyle(CYColor.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: CYSpacing.sm)
                    if let dist = coordinator.distanceMeters {
                        Group {
                            if coordinator.withinRange { Text("playx.poi.inRange \(dist)") } else { Text("playx.poi.distance \(dist)") }
                        }
                        .font(CYTypography.caption)
                        .foregroundStyle(coordinator.withinRange ? CYColor.successText : CYColor.warningText)
                    }
                }
                if !node.description.isEmpty {
                    Text(node.description)
                        .font(CYTypography.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func checklistCard(_ node: ChallengePOINode) -> some View {
        let items = ChallengePOIChecklist.items(
            node: node,
            withinRange: coordinator.withinRange,
            distanceMeters: coordinator.distanceMeters,
            photoConfirmed: !coordinator.uploadedPhotoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            answerProvided: ChallengePOIChecklist.hasAnswerInput(
                node: node, selectedOptionIndex: coordinator.selectedOptionIndex, textAnswer: coordinator.textAnswer))
        if !items.isEmpty {
            CYCard {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ProgressView(value: ChallengePOIChecklist.progress(items))
                        .tint(CYColor.accent)
                        .accessibilityLabel(W8Text.t("挑战进度", "Challenge progress"))
                    ChallengePOIChecklistView(items: items)
                }
            }
        }
    }

    private var photoCard: some View {
        CYCard {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text("playx.poi.photoStep")
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                TextField(LocalizedStringKey("playx.poi.photoUrlPlaceholder"), text: $coordinator.uploadedPhotoUrl)
                    .font(CYTypography.body)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, CYSpacing.md)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                Button(LocalizedStringKey("playx.poi.confirmPhoto")) {
                    coordinator.confirmPhotoUploaded(coordinator.uploadedPhotoUrl)
                }
                .buttonStyle(.cySecondary(fullWidth: true))
            }
        }
    }

    @ViewBuilder
    private func quizCard(_ node: ChallengePOINode) -> some View {
        if !node.question.isEmpty || !node.options.isEmpty {
            CYCard {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    if !node.question.isEmpty {
                        Text(node.question)
                            .font(CYTypography.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !node.options.isEmpty {
                        ForEach(Array(node.options.enumerated()), id: \.offset) { idx, option in
                            optionRow(option, selected: coordinator.selectedOptionIndex == idx) {
                                coordinator.selectedOptionIndex = idx
                            }
                        }
                    } else {
                        TextField(LocalizedStringKey("playx.poi.answerPlaceholder"), text: $coordinator.textAnswer)
                            .font(CYTypography.body)
                            .padding(.horizontal, CYSpacing.md)
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .background(CYColor.bgRaised, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    }
                }
            }
        }
    }

    private func optionRow(_ option: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.md) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? CYColor.accentText : CYColor.textTertiary)
                    .accessibilityHidden(true)
                Text(option)
                    .font(CYTypography.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CYSpacing.md)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .background(selected ? CYColor.accentSoft : CYColor.bgSurfaceSubtle,
                        in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var submitArea: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            PlayWriteUnavailableBanner(surface: .challengeSubmit)

            if let submitFeedback, !submitFeedback.isEmpty {
                messageCard(submitFeedback, tone: .danger)
                    .accessibilityIdentifier("playx.poi.feedback")
            } else if readyButBlocked {
                Label(W8Text.t("答案已通过本机校验，但没有发送。", "Your attempt passed the local check but was not sent."),
                      systemImage: "paperplane.circle")
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("playx.poi.readyBlocked")
            }

            Button(LocalizedStringKey("playx.poi.submit")) {
                Task { await onSubmit() }
            }
            .buttonStyle(.cyPrimary(fullWidth: true))
            .disabled(coordinator.submitting || coordinator.unknownSubmission)
            .accessibilityIdentifier("playx.poi.submit")

            if coordinator.unknownSubmission {
                Button(LocalizedStringKey("playx.poi.verifyReceipt")) {
                    Task { await onRefresh() }
                }
                .buttonStyle(.cySecondary(fullWidth: true))
            }
        }
    }

    private var doneCard: some View {
        CYCard(variant: .accentTint) {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Label(
                    coordinator.alreadyClaimed
                        ? W8Text.t("已完成该地标挑战", "Landmark challenge already completed")
                        : W8Text.t("挑战通关！", "Challenge complete!"),
                    systemImage: "medal.fill")
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(CYColor.warningText)
                    .accessibilityAddTraits(.isHeader)

                if let medal = coordinator.medal {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(medal.name)
                            .font(CYTypography.cardTitle)
                            .foregroundStyle(CYColor.textPrimary)
                        if !medal.description.isEmpty {
                            Text(medal.description)
                                .font(CYTypography.bodyCompact)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Mini-program `subpackageRoam/nearby` opens `pages/play/poi-challenge` from a nearby place.
/// DESIGNED host: built from the already-read roam node; the challenge write has no approved path in this build,
/// so a validated submission explains that instead of posting (and never marks the attempt as sent).
@available(macOS 14.0, *)
@MainActor struct ChallengePOIHostView: View {
    let node: RoamNodeDetail
    @State private var coordinator: ChallengePOICoordinator?
    @State private var feedback: String?
    @State private var readyButBlocked = false

    var body: some View {
        ScrollView {
            if let coordinator {
                ChallengePOIView(
                    coordinator: coordinator,
                    onRefresh: {
                        feedback = nil
                        readyButBlocked = false
                        load(coordinator)
                    },
                    onSubmit: {
                        // Validate locally, then say honestly that nothing was sent: no approved write path exists.
                        do {
                            _ = try coordinator.buildCompletionPayload(userLat: nil, userLon: nil)
                            feedback = nil
                            readyButBlocked = true
                        } catch {
                            feedback = error.localizedDescription
                            readyButBlocked = false
                        }
                    },
                    submitFeedback: feedback,
                    readyButBlocked: readyButBlocked
                )
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 120)
            }
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .navigationTitle(W8Text.t("地标挑战", "Landmark challenge"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard coordinator == nil else { return }
            let model = ChallengePOICoordinator(nodeId: node.poiId)
            load(model)
            coordinator = model
        }
    }

    private func load(_ model: ChallengePOICoordinator) {
        model.applyLoadedNode(ChallengePOINode(
            id: node.poiId, name: node.name, title: node.name, description: node.description ?? "",
            latitude: node.coordinate?.latitude, longitude: node.coordinate?.longitude,
            radiusM: Double(node.radiusM ?? 100), photoRequired: true, completed: node.completed))
    }
}

#if DEBUG
#Preview("Challenge · photo + quiz") {
    let model = ChallengePOICoordinator(nodeId: 7)
    model.applyLoadedNode(ChallengePOINode(
        id: 7, name: "Clock Tower", description: "Find the mural behind the clock.",
        radiusM: 100, photoRequired: true, question: "Which year was it built?", options: ["1921", "1934"]))
    return ScrollView {
        ChallengePOIView(coordinator: model, onRefresh: {}, onSubmit: {}, readyButBlocked: true).padding()
    }
    .background(CYColor.bgPage)
}

#Preview("Challenge · load failed") {
    let model = ChallengePOICoordinator(nodeId: 7)
    model.applyLoadError("")
    return ChallengePOIView(coordinator: model, onRefresh: {}, onSubmit: {}).padding()
}
#endif
