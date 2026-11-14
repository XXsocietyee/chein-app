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
    /// Optional action to open the city-slip / stamp flow after completing the challenge.
    var onWriteCitySlip: (() -> Void)? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xl) {
            switch coordinator.state {
            case .loading:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    CYSkeleton()
                    Text("playx.poi.loading")
                        .font(CYTypography.body)
                        .foregroundStyle(palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("playx.poi.loading"))

            case .error:
                CYStateLayout(
                    kind: .failure,
                    title: Text("playx.poi.loadFailed"),
                    detail: Text(verbatim: readable(coordinator.errorMessage.isEmpty
                        ? W8Text.t("请检查网络连接后重试", "Check your connection and try again")
                        : coordinator.errorMessage)),
                    primary: (title: "playx.poi.retry", action: { Task { await onRefresh() } }),
                    primaryStyle: .secondary
                )

            case .photo, .quiz:
                if let node = coordinator.node {
                    placeCard(node)
                    checklistCard(node)

                    if !coordinator.errorMessage.isEmpty {
                        note(readable(coordinator.errorMessage), symbol: "exclamationmark.triangle.fill", tone: .danger)
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
        .cyAnimation(value: coordinator.state)
        .cyHaptic(.success, trigger: coordinator.state) { _, new in new == .done }
    }

    private func placeCard(_ node: ChallengePOINode) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            let place = node.title.isEmpty ? node.name : node.title
            CYImageCard(
                verbatim: isRawKey(place) ? "" : place,
                fallback: "playx.poi.photoStep",
                meta: node.description.isEmpty || isRawKey(node.description) ? nil : node.description
            )
            if let dist = coordinator.distanceMeters {
                HStack(spacing: CYSpacing.sm) {
                    Image(systemName: coordinator.withinRange ? "checkmark.circle.fill" : "location")
                        .accessibilityHidden(true)
                    Group {
                        if coordinator.withinRange { Text("playx.poi.inRange \(dist)") }
                        else { Text("playx.poi.distance \(dist)") }
                    }
                    .font(CYTypography.caption)
                    .foregroundStyle(coordinator.withinRange ? palette.success : palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    if !coordinator.withinRange, let url = Self.navigationURL(for: node) {
                        Spacer(minLength: 0)
                        Button {
                            openURL(url)
                        } label: {
                            Label("playx.poi.navigate", systemImage: "arrow.triangle.turn.up.right.diamond")
                                .font(CYTypography.caption.weight(.semibold))
                                .foregroundStyle(palette.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("playx.poi.navigate")
                    }
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
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                ProgressView(value: ChallengePOIChecklist.progress(items))
                    .tint(palette.textPrimary)
                    .accessibilityLabel(Text(verbatim: W8Text.t("挑战进度", "Challenge progress")))
                ChallengePOIChecklistView(items: items)
            }
            .cyDomainCard()
        }
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("playx.poi.photoStep")
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            TextField(LocalizedStringKey("playx.poi.photoUrlPlaceholder"), text: $coordinator.uploadedPhotoUrl)
                .font(CYTypography.body)
                .textContentType(.URL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .cyField()
            CYPillButton("playx.poi.confirmPhoto", style: .secondary, systemImage: "camera") {
                coordinator.confirmPhotoUploaded(coordinator.uploadedPhotoUrl)
            }
            .accessibilityLabel(Text("playx.poi.confirmPhoto"))
        }
        .cyDomainCard()
    }

    @ViewBuilder
    private func quizCard(_ node: ChallengePOINode) -> some View {
        if !node.question.isEmpty || !node.options.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if !node.question.isEmpty {
                    Text(verbatim: readable(node.question))
                        .font(CYTypography.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !node.options.isEmpty {
                    ForEach(Array(node.options.enumerated()), id: \.offset) { idx, option in
                        CYChoiceRow(label: readable(option), selected: coordinator.selectedOptionIndex == idx) {
                            coordinator.selectedOptionIndex = idx
                        }
                    }
                } else {
                    TextField(LocalizedStringKey("playx.poi.answerPlaceholder"), text: $coordinator.textAnswer)
                        .font(CYTypography.body)
                        .cyField()
                }
            }
            .cyDomainCard()
        }
    }

    private var submitArea: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            PlayWriteUnavailableBanner(surface: .challengeSubmit)

            if let submitFeedback, !submitFeedback.isEmpty {
                note(readable(submitFeedback), symbol: "exclamationmark.triangle.fill", tone: .danger)
                    .accessibilityIdentifier("playx.poi.feedback")
            } else if readyButBlocked {
                note(W8Text.t("答案已通过本机校验，但没有发送。", "Your attempt passed the local check but was not sent."),
                     symbol: "paperplane.circle", tone: .neutral)
                    .accessibilityIdentifier("playx.poi.readyBlocked")
            }

            if coordinator.unknownSubmission {
                CYPillButton("playx.poi.verifyReceipt", systemImage: "arrow.clockwise") {
                    Task { await onRefresh() }
                }
                .accessibilityLabel(Text("playx.poi.verifyReceipt"))
                CYPillButton("playx.poi.submit", style: .secondary, systemImage: "paperplane.fill") {
                    Task { await onSubmit() }
                }
                .disabled(true)
                .accessibilityIdentifier("playx.poi.submit")
                .accessibilityLabel(Text("playx.poi.submit"))
            } else {
                CYPillButton("playx.poi.submit", systemImage: "paperplane.fill") {
                    Task { await onSubmit() }
                }
                .disabled(coordinator.submitting)
                .accessibilityIdentifier("playx.poi.submit")
                .accessibilityLabel(Text("playx.poi.submit"))
            }
        }
    }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Label(
                coordinator.alreadyClaimed
                    ? W8Text.t("已完成该地标挑战", "Landmark challenge already completed")
                    : W8Text.t("挑战通关！", "Challenge complete!"),
                systemImage: "medal.fill")
                .font(CYTypography.sectionTitle)
                .foregroundStyle(palette.warning)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let medal = coordinator.medal {
                // A3.5: prefer the landmark cover image; fall back to medal icon / key icon.
                let coverURL = coordinator.node.flatMap { Self.validImageURL($0.coverUrl) } ?? Self.validImageURL(medal.iconUrl)
                CYImageCard(
                    verbatim: isRawKey(medal.name) ? "" : medal.name,
                    fallback: "playx.poi.completed",
                    meta: medal.description.isEmpty || isRawKey(medal.description) ? nil : medal.description,
                    imageURL: coverURL
                )
            }
            if let onWriteCitySlip {
                CYPillButton("playx.poi.writeCitySlip", style: .secondary, systemImage: "camera", action: onWriteCitySlip)
                    .accessibilityIdentifier("playx.poi.writeCitySlip")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func validImageURL(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), url.host != nil else { return nil }
        return url
    }

    private static func navigationURL(for node: ChallengePOINode) -> URL? {
        guard let lat = node.latitude, let lng = node.longitude, lat.isFinite, lng.isFinite else { return nil }
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = [
            URLQueryItem(name: "daddr", value: "\(lat),\(lng)"),
            URLQueryItem(name: "q", value: node.title.isEmpty ? node.name : node.title),
        ]
        return components?.url
    }

    private func note(_ text: String, symbol: String, tone: CYStatusTone) -> some View {
        let foreground: Color = tone == .danger ? palette.danger : tone == .success ? palette.success : palette.textPrimary
        let background: Color = tone == .danger ? palette.dangerSoft : tone == .success ? palette.successSoft : palette.bgRaised
        return HStack(alignment: .top, spacing: CYSpacing.sm) {
            Image(systemName: symbol).accessibilityHidden(true)
            Text(verbatim: text)
                .font(CYTypography.bodyCompact)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(foreground)
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func isRawKey(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#, options: .regularExpression) != nil
    }

    private func readable(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "—" }
        guard isRawKey(trimmed) else { return trimmed }
        let resolved = String(localized: String.LocalizationValue(stringLiteral: trimmed))
        return resolved == trimmed ? "—" : resolved
    }
}

/// Mini-program `subpackageRoam/nearby` opens `pages/play/poi-challenge` from a nearby place.
/// DESIGNED host: built from the already-read roam node; the challenge write has no approved path in this build,
/// so a validated submission goes through the injected writer (gated by default) and never claims it was sent.
@available(macOS 14.0, *)
@MainActor struct ChallengePOIHostView: View {
    let node: RoamNodeDetail
    @State private var coordinator: ChallengePOICoordinator?
    @State private var feedback: String?
    @State private var readyButBlocked = false
    @State private var showingStampCamera = false
    @StateObject private var submitModel = ChallengePOISubmitModel(writer: ChallengePOIWriterFactory.makeWriter())

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                CYHeroHeader(verbatim: W8Text.t("地标挑战", "Landmark challenge"))
                if let coordinator {
                    ChallengePOIView(
                        coordinator: coordinator,
                        onRefresh: {
                            feedback = nil
                            readyButBlocked = false
                            load(coordinator)
                        },
                        onSubmit: {
                            // Validate locally, then send through the injected writer (gated by default: nothing is sent).
                            await submitModel.submit(coordinator: coordinator, userLat: nil, userLon: nil)
                            switch submitModel.state {
                            case .unavailable: feedback = nil; readyButBlocked = true
                            case .invalid(let message), .rejected(let message), .unconfirmed(let message):
                                feedback = message; readyButBlocked = false
                            case .idle, .submitting, .done: feedback = nil; readyButBlocked = false
                            }
                        },
                        submitFeedback: feedback,
                        readyButBlocked: readyButBlocked,
                        onWriteCitySlip: { showingStampCamera = true }
                    )
                } else {
                    CYSkeleton()
                        .accessibilityLabel(Text("playx.poi.loading"))
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.lg)
            .padding(.bottom, CYSpacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .cyDomainPageBackground()
        .themeDomain(.player)
        .cyHeroScreen()
        .sheet(isPresented: $showingStampCamera) {
            NavigationStack {
                RoamStampCameraView()
            }
            .cyPlayerSheetGlass()
        }
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
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYHeroHeader(verbatim: W8Text.t("地标挑战", "Landmark challenge"))
            ChallengePOIView(coordinator: model, onRefresh: {}, onSubmit: {}, readyButBlocked: true)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    .cyDomainPageBackground()
    .themeDomain(.player)
    .cyHeroScreen()
}

#Preview("Challenge · load failed") {
    let model = ChallengePOICoordinator(nodeId: 7)
    model.applyLoadError("")
    return ScrollView {
        ChallengePOIView(coordinator: model, onRefresh: {}, onSubmit: {})
            .padding(.horizontal, CYSpacing.pageHorizontal)
    }
    .cyDomainPageBackground()
    .themeDomain(.player)
}
#endif
