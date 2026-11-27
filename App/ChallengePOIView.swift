import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - POI Challenge View (Ported from pages/play/poi-challenge/index.wxml & index.js)

/// Challenge screen: header, step checklist, photo + quiz inputs and a submit area.
/// When a live writer is not installed, the submit area carries the "not available yet" banner
/// and `readyButBlocked` explains that a valid attempt was not sent.
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
    /// PLAYPOI-4: MP 查看徽章墙 (badgeCode) secondary on the medal screen.
    var onOpenBadgeWall: (() -> Void)? = nil
    /// PLAYPOI-5: MP 返回地图 on the error state.
    var onBackToMap: (() -> Void)? = nil
    /// PLAYPOI-1: scoped uploader for the camera photo step; nil keeps the step disabled with a note.
    var photoUploader: (any RetainedImageUploading)? = nil
    @Environment(\.cyPalette) private var palette
    @Environment(\.openURL) private var openURL
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xl) {
            switch coordinator.state {
            case .loading:
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    // MP poi-challenge loading is the skeleton alone (no line of text); VoiceOver keeps the label.
                    CYSkeleton()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("playx.poi.loading"))

            case .error:
                CYStateLayout(
                    kind: .failure,
                    title: Text("playx.poi.loadFailed"),
                    detail: coordinator.errorMessage.isEmpty ? Text("playx.poi.checkNetwork") : Text(verbatim: readable(coordinator.errorMessage)),
                    primary: (title: "playx.poi.retry", action: { _ = Task { await onRefresh() } }),
                    primaryStyle: .secondary,
                    secondaryVerbatim: onBackToMap.map { back in (title: appLocalized("playx.poi.backToMap", locale: locale), action: back) }
                )

            case .photo, .quiz:
                if let node = coordinator.node {
                    placeCard(node)
                    checklistCard(node)

                    if !coordinator.errorMessage.isEmpty {
                        note(readable(coordinator.errorMessage), symbol: "exclamationmark.triangle.fill", tone: .danger)
                    }

                    // mp-journey r3 (MP poi-challenge: 一次一屏): the photo step and the quiz step never share a screen.
                    // A confirmed photo moves the coordinator on to .quiz; the photo stays in the checklist above.
                    if coordinator.state == .photo {
                        photoCard
                    } else {
                        quizCard(node)
                    }

                    // The photo screen of a node that still has a question has no submit: the quiz screen sends both.
                    if !(coordinator.state == .photo && Self.hasQuiz(node)) {
                        submitArea
                    }
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
                fallback: "playx.poi.title",
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
                    .cyText(.caption)
                    .foregroundStyle(coordinator.withinRange ? palette.success : palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
                    if !coordinator.withinRange, let url = Self.navigationURL(for: node) {
                        Spacer(minLength: 0)
                        Button {
                            openURL(url)
                        } label: {
                            Label("playx.poi.navigate", systemImage: "arrow.triangle.turn.up.right.diamond")
                                .cyText(.caption, weight: .semibold)
                                .foregroundStyle(palette.brand)
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
                    .accessibilityLabel(Text("playx.poi.progress"))
                    .accessibilityValue(Text(verbatim: ChallengePOIChecklist.progress(items) == 0 ? "0" : "\(ChallengePOIChecklist.progress(items))"))
                ChallengePOIChecklistView(items: items)
            }
            .cyDomainCard()
        }
    }

    static func hasQuiz(_ node: ChallengePOINode) -> Bool { !node.question.isEmpty || !node.options.isEmpty }

    private var photoCard: some View {
        ChallengePOIPhotoCapture(
            lead: coordinator.node?.photoRequireDesc,
            uploader: photoUploader,
            confirmed: !coordinator.uploadedPhotoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onUploaded: { coordinator.confirmPhotoUploaded($0) }
        )
    }

    @ViewBuilder
    private func quizCard(_ node: ChallengePOINode) -> some View {
        if !node.question.isEmpty || !node.options.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if !node.question.isEmpty {
                    Text(verbatim: readable(node.question))
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // MP cy-playkit-qa pick mode lists the options inline; no extra 选择答案 sheet.
                if !node.options.isEmpty {
                    ForEach(Array(node.options.enumerated()), id: \.offset) { idx, option in
                        CYChoiceRow(label: readable(option), selected: coordinator.selectedOptionIndex == idx) {
                            coordinator.selectedOptionIndex = idx
                        }
                        .accessibilityLabel(Text(verbatim: readable(option)))
                        .accessibilityValue(Text(verbatim: readable(option)))
                        .accessibilityHint(Text(verbatim: node.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : readable(node.question)))
                    }
                } else {
                    TextField(LocalizedStringKey("playx.poi.answerPlaceholder"), text: $coordinator.textAnswer)
                        .cyText(.body)
                        .cyField()
                        .accessibilityLabel(Text("playx.poi.answerPlaceholder"))
                        .accessibilityValue(Text(verbatim: coordinator.textAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : coordinator.textAnswer))
                        .accessibilityHint(Text(verbatim: node.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : readable(node.question)))
                }
            }
            .cyDomainCard()
        }
    }

    private var submitArea: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            if !ChallengePOIWriterFactory.isLive {
                PlayWriteUnavailableBanner(surface: .challengeSubmit)
            }

            if let submitFeedback, !submitFeedback.isEmpty {
                note(readable(submitFeedback), symbol: "exclamationmark.triangle.fill", tone: .danger)
                    .accessibilityIdentifier("playx.poi.feedback")
            } else if readyButBlocked {
                note(appLocalized("playx.poi.readyBlocked", locale: locale),
                     symbol: "paperplane.circle", tone: .neutral)
                    .accessibilityIdentifier("playx.poi.readyBlocked")
            }

            if coordinator.unknownSubmission {
                CYPillButton("playx.poi.verifyReceipt", systemImage: "arrow.clockwise") {
                    Task { await onRefresh() }
                }
                .accessibilityLabel(Text("playx.poi.verifyReceipt"))
                .accessibilityValue(Text(verbatim: "—"))
                .accessibilityHint(Text("playx.poi.verifyReceipt"))
                CYPillButton("playx.poi.submit", style: .secondary, systemImage: "paperplane.fill") {
                    Task { await onSubmit() }
                }
                .disabled(true)
                .accessibilityIdentifier("playx.poi.submit")
                .accessibilityLabel(Text("playx.poi.submit"))
                .accessibilityValue(Text(verbatim: "—"))
                .accessibilityHint(Text("playx.poi.submit"))
            } else {
                CYPillButton("playx.poi.submit", systemImage: "paperplane.fill") {
                    Task { await onSubmit() }
                }
                .disabled(coordinator.submitting)
                .accessibilityIdentifier("playx.poi.submit")
                .accessibilityLabel(Text("playx.poi.submit"))
                .accessibilityValue(Text(coordinator.submitting ? "playx.poi.loading" : "playx.poi.submit"))
                .accessibilityHint(Text("playx.poi.submit"))
            }
        }
    }

    private var doneCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Label(
                coordinator.alreadyClaimed ? "playx.poi.alreadyClaimed" : "playx.poi.medalDone",
                systemImage: "medal.fill")
                .cyText(.sectionTitle)
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
                // MP cy-medal-screen: the place cover, else the `mic_key.svg` medal glyph (_finish mic: 'key').
                .fallbackArtwork(MPAsset.BadgeMedal.micKey)
            }
            // MP _finish sub: 勋章已放进徽章墙, or 再完成一次不会重复发放 when it was already collected.
            Text(LocalizedStringKey(coordinator.alreadyClaimed ? "playx.poi.claimedAgain" : "playx.poi.medalStored"))
                .cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // MP medal screen: primary 写一张城市签 (citystamp kind=sign), secondary 查看徽章墙.
            if let onWriteCitySlip {
                CYPillButton("playx.poi.writeCitySlip", style: .primary, systemImage: "signature", action: onWriteCitySlip)
                    .accessibilityIdentifier("playx.poi.writeCitySlip")
            }
            if let onOpenBadgeWall {
                CYPillButton("playx.poi.openBadgeWall", style: .secondary, systemImage: "medal", action: onOpenBadgeWall)
                    .accessibilityIdentifier("playx.poi.openBadgeWall")
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

    /// N-POICH (r10): a system Label in the semantic tone colour; no tinted rounded box (MP pages/play/poi-challenge.wxml notes).
    private func note(_ text: String, symbol: String, tone: CYStatusTone) -> some View {
        let foreground: Color = tone == .danger ? palette.danger : tone == .success ? palette.success : palette.textPrimary
        return Label {
            Text(verbatim: text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
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

/// `pages/play/poi-challenge?poiId=`. PLAYPOI-2: the node is read from `GET /api/city/nodes/{id}` (status, photo,
/// quiz A–D, badge code) when a roam reader is present; the already-read roam node only seeds the first frame.
/// Submissions run through `ChallengePOIWriterFactory.makeWriter()` with foreground GCJ-02 coordinates.
@available(macOS 14.0, *)
@MainActor struct ChallengePOIHostView: View {
    let poiID: Int
    var seed: RoamNodeDetail? = nil
    var reader: (any RoamReading)? = nil
    /// MP `onLoad(q)` `photo=`: a photo the map spot-camera already uploaded; it fills the photo step once.
    var prefilledPhotoURL: String? = nil
    @Environment(\.playEmergencyLocationProvider) private var locationProvider
    @Environment(\.challengePOIPhotoUploader) private var makePhotoUploader
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var coordinator: ChallengePOICoordinator?
    @State private var feedback: String?
    @State private var readyButBlocked = false
    @State private var showingCitySign = false
    @State private var showingBadgeWall = false
    @State private var placeName: String?
    @State private var badgeCode: String?
    @StateObject private var submitModel = ChallengePOISubmitModel(writer: ChallengePOIWriterFactory.makeWriter())

    init(node: RoamNodeDetail, reader: (any RoamReading)? = nil) {
        poiID = node.poiId; seed = node; self.reader = reader
    }
    init(poiID: Int, reader: (any RoamReading)?, photoURL: String? = nil) {
        self.poiID = poiID; self.reader = reader; self.prefilledPhotoURL = photoURL
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                if let coordinator {
                    ChallengePOIView(
                        coordinator: coordinator,
                        onRefresh: {
                            feedback = nil
                            readyButBlocked = false
                            await load(coordinator)
                        },
                        onSubmit: {
                            let coords = await currentGCJ02Coordinate()
                            await submitModel.submit(coordinator: coordinator, userLat: coords?.latitude, userLon: coords?.longitude)
                            switch submitModel.state {
                            case .unavailable: feedback = nil; readyButBlocked = true
                            case .invalid(let message), .rejected(let message), .unconfirmed(let message):
                                feedback = message; readyButBlocked = false
                            case .idle, .submitting, .done: feedback = nil; readyButBlocked = false
                            }
                        },
                        submitFeedback: feedback,
                        readyButBlocked: readyButBlocked,
                        onWriteCitySlip: { showingCitySign = true },
                        onOpenBadgeWall: { showingBadgeWall = true },
                        onBackToMap: { dismiss() },
                        photoUploader: ChallengePOIWriterFactory.isLive ? makePhotoUploader?(poiID) : nil
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
        // PLAYPOI-3: one inline bar title, the place name once it is known.
        .modifier(ChallengePOITitle(name: placeName))
        .navigationDestination(isPresented: $showingCitySign) {
            // PLAYPOI-4: MP 写一张城市签 → subpackageRoam/citystamp?kind=sign&place=
            SessionRoamCityStampFlowView(kind: "sign", place: placeName)
        }
        .navigationDestination(isPresented: $showingBadgeWall) {
            ChallengePOIBadgeWallDestination(badgeCode: badgeCode)
        }
        .task {
            guard coordinator == nil else { return }
            let model = ChallengePOICoordinator(nodeId: poiID)
            if let seed { apply(seed, to: model) }
            coordinator = model
            await load(model)
            applyPrefilledPhoto(to: model)
        }
    }

    /// Only an absolute https upload, only for an open photo step that has no photo yet; the server still checks
    /// that the photo belongs to this account (MP 照片未上传成功或不属于当前账号).
    private func applyPrefilledPhoto(to model: ChallengePOICoordinator) {
        guard let raw = prefilledPhotoURL?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty,
              let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host != nil, url.user == nil, url.password == nil,
              let node = model.node, node.photoRequired, !node.completed,
              model.uploadedPhotoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        model.confirmPhotoUploaded(raw)
    }

    private func load(_ model: ChallengePOICoordinator) async {
        guard let reader else {
            if let seed { apply(seed, to: model) } else { model.applyLoadError(appLocalized("playx.poi.notFound", locale: locale)) }
            return
        }
        do {
            let node = try await reader.roamNodeDetail(id: poiID)
            apply(node, to: model)
        } catch is CancellationError {
            return
        } catch {
            model.applyLoadError(appLocalized("playx.poi.checkNetwork", locale: locale))
        }
    }

    /// MP `_load`: completed → medal (已收藏); status ≠ 1 → 暂未开放; quiz = validationMethod 3 with options;
    /// photoRequired → photo step; neither → 还没有配置挑战.
    private func apply(_ node: RoamNodeDetail, to model: ChallengePOICoordinator) {
        placeName = node.name.isEmpty ? nil : node.name
        badgeCode = node.badgeCode
        let quiz = node.isQuiz
        model.applyLoadedNode(ChallengePOINode(
            id: node.poiId, name: node.name, title: node.name, description: node.description ?? "",
            latitude: node.coordinate?.latitude, longitude: node.coordinate?.longitude,
            radiusM: Double(node.radiusM ?? 100), photoRequired: node.photoRequired,
            question: quiz ? (node.questionName ?? "") : "",
            options: quiz ? node.quizOptions.map(\.text) : [],
            completed: node.completed,
            optionIDs: quiz ? node.quizOptions.map(\.id) : nil,
            photoRequireDesc: node.photoRequireDesc, badgeCode: node.badgeCode))
        guard !node.completed else { return }
        if node.status != 1 { model.applyLoadError(appLocalized("playx.poi.notOpen", locale: locale)); return }
        if !quiz && !node.photoRequired { model.applyLoadError(appLocalized("playx.poi.notConfigured", locale: locale)) }
    }

    private func currentGCJ02Coordinate() async -> (latitude: Double, longitude: Double)? {
        guard let raw = await locationProvider?.currentCoordinate(),
              let roam = RoamCoordinate(latitude: raw.latitude, longitude: raw.longitude) else {
            return nil
        }
        if let gcj = try? RuntimeLocationProjection.gcj02MapCenter(RuntimeLocationProjection.MapCenter(coordinate: roam, datum: .wgs84)) {
            return (gcj.coordinate.latitude, gcj.coordinate.longitude)
        }
        return raw
    }
}

private struct ChallengePOITitle: ViewModifier {
    let name: String?
    func body(content: Content) -> some View {
        if let name { content.cyPageTitle(verbatim: name) } else { content.cyPageTitle("playx.poi.title") }
    }
}

/// 查看徽章墙 with the earned badge focused; uses the session profile reader when the app session is present.
@MainActor private struct ChallengePOIBadgeWallDestination: View {
    let badgeCode: String?
    @EnvironmentObject private var session: AppSession
    var body: some View {
        ObjectBadgeWallView(reader: session.profileReader, media: session.makeObjectCardImageLoader(), focusBadgeCode: badgeCode)
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
