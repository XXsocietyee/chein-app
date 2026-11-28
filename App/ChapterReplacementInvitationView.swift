import SwiftUI

/// C9 host-side replacement-invitation screen (exclusive module).
/// Flow: own topic -> withdrawn-supply vacancy -> invitable candidates (location
/// optional) -> impact review -> one invite -> exact-tuple readback -> vacancy refresh.
/// It contains no accept/supply/payment/refund actions and no inbox aggregation.
@MainActor
final class ChapterReplacementInvitationViewModel: ObservableObject {
    @Published private(set) var phase: ChapterReplacementInvitationCoordinator.Phase = .idle
    @Published private(set) var vacancies: [ChapterReplacementInvitationVacancy] = []
    @Published private(set) var candidates: [ChapterReplacementInvitationCandidate] = []
    @Published private(set) var selectedVacancy: ChapterReplacementInvitationVacancy?
    @Published var message = ""
    /// MP 补位候选已变化，请刷新后重试: the candidate chosen on 找商家承接 is no longer offered.
    @Published private(set) var focusChanged = false

    private let coordinator: ChapterReplacementInvitationCoordinator
    private let topicID: Int
    private let actorAccountID: Int
    private let scope: ChapterReplacementInvitationScope
    private let merchantAccess: MerchantAccess?
    /// Nil when the caller has no approved fresh topic-publisher read. Never synthesized here.
    private let publisherProof: ChapterReplacementInvitationPublisherProof?

    init(coordinator: ChapterReplacementInvitationCoordinator, topicID: Int, actorAccountID: Int,
         scope: ChapterReplacementInvitationScope, merchantAccess: MerchantAccess?, publisherProof: ChapterReplacementInvitationPublisherProof?) {
        self.coordinator = coordinator
        self.topicID = topicID; self.actorAccountID = actorAccountID
        self.scope = scope; self.merchantAccess = merchantAccess
        self.publisherProof = publisherProof
    }

    private func sync() {
        phase = coordinator.phase
        vacancies = coordinator.vacancies
        candidates = coordinator.candidates
        selectedVacancy = coordinator.selectedVacancy
    }

    func load() async {
        coordinator.begin(topicID: topicID, actorAccountID: actorAccountID)
        await coordinator.loadVacancies()
        sync()
    }

    /// Opened from a 邀请补位 option on 找商家承接 (MP `confirmChapterReplacement`): select that vacancy, re-read its
    /// candidates and go straight to the review of the chosen merchant. When the vacancy or the candidate is gone
    /// the page stays on the normal list and says the options changed (MP stillInvitable check).
    func load(focus: CoopNearbyReplacementOption?, coordinates: ChapterReplacementInvitationCoordinates?) async {
        await load()
        guard let focus, phase == .ready else { return }
        guard let vacancy = vacancies.first(where: { $0.offerID == focus.replacementOfOfferID && $0.chapterID == focus.chapterID }) else {
            focusChanged = true; return
        }
        await select(vacancy, coordinates: coordinates)
        guard phase == .ready, let candidate = candidates.first(where: { focus.matches($0) }) else {
            if phase == .ready { focusChanged = true }
            return
        }
        await prepare(candidate)
    }

    func select(_ vacancy: ChapterReplacementInvitationVacancy, coordinates: ChapterReplacementInvitationCoordinates?) async {
        await coordinator.loadCandidates(for: vacancy, coordinates: coordinates)
        sync()
    }

    func prepare(_ candidate: ChapterReplacementInvitationCandidate) async {
        await coordinator.prepare(candidate: candidate, scope: scope, merchantAccess: merchantAccess,
                                  publisherProof: publisherProof, message: message)
        sync()
    }

    func confirm() async { await coordinator.confirmSend(); sync() }
    func verifyUnknown() async { await coordinator.verifyUnknown(); sync() }
    func cancelReview() { coordinator.cancelReview(); sync() }
}

/// Loads the host's fresh topic-publisher proof before showing the C9 screen.
/// A nil proof is passed through; the coordinator then refuses the invite.
@MainActor struct ChapterReplacementInvitationEntry: View {
    let context: MerchantChapterReplacementHostContext
    let topicID: Int
    let merchantAccess: MerchantAccess?
    /// Set when opened from a 邀请补位 option on 找商家承接; nil keeps the plain vacancy → candidate flow.
    var focus: CoopNearbyReplacementOption? = nil
    @State private var model: ChapterReplacementInvitationViewModel?
    @State private var unavailable = false

    var body: some View {
        Group {
            if let model {
                ChapterReplacementInvitationView(model: model, coordinates: context.coordinates, focus: focus)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: CYSpacing.xl) {
                        CYHeroHeader("chapterReplacement.title")
                        if unavailable {
                            CYEmptyState(systemImage: "exclamationmark.triangle", "chapterReplacement.section.failed", kind: .failure)
                                .accessibilityIdentifier("chapterReplacement.failed")
                        } else {
                            CYSkeleton().task { await resolve() }
                        }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.top, CYSpacing.lg)
                    .padding(.bottom, CYSpacing.xxl)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .cyDomainPageBackground()
                .themeDomain(.player)
                .cyHeroScreen()
            }
        }
    }

    private func resolve() async {
        let proof = await context.loadPublisherProof(topicID)
        guard !Task.isCancelled, let effects = context.makeEffects(proof) else { unavailable = true; return }
        model = .init(coordinator: .init(effects: effects), topicID: topicID, actorAccountID: context.actorAccountID,
            scope: context.scope, merchantAccess: merchantAccess ?? context.merchantAccess, publisherProof: proof)
    }
}

struct ChapterReplacementInvitationView: View {
    @StateObject private var model: ChapterReplacementInvitationViewModel
    /// Supplied by the host shell; `nil` means location was refused and candidates
    /// must still be queried by topic alone.
    let coordinates: ChapterReplacementInvitationCoordinates?
    let focus: CoopNearbyReplacementOption?
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale

    init(model: ChapterReplacementInvitationViewModel, coordinates: ChapterReplacementInvitationCoordinates? = nil,
         focus: CoopNearbyReplacementOption? = nil) {
        _model = StateObject(wrappedValue: model)
        self.coordinates = coordinates
        self.focus = focus
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xxl) {
                CYHeroHeader("chapterReplacement.title", subtitle: "chapterReplacement.intro")
                if model.focusChanged {
                    CYInlineError(verbatim: CoopNearbyReplacementOption.changedText(chinese: LocaleDisplay.isChinese(locale)))
                        .accessibilityIdentifier("chapterReplacement.focusChanged")
                }
                vacancySection
                if model.selectedVacancy != nil {
                    candidateSection
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        Text("chapterReplacement.section.message")
                            .cyText(.sectionTitle)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .fixedSize(horizontal: false, vertical: true)
                        TextField(text: $model.message, prompt: Text("chapterReplacement.message.prompt")) {
                            Text("chapterReplacement.message.label")
                        }
                        .cyText(.body)
                        .cyField()
                        .accessibilityIdentifier("chapterReplacement.message")
                    }
                }
                statusSection
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
        .cyAnimation(value: model.phase)
        .cyHaptic(.impactMedium, trigger: model.phase, where: Self.startedSending)
        .task { await model.load(focus: focus, coordinates: coordinates) }
    }

    @ViewBuilder private var vacancySection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("chapterReplacement.section.vacancies")
                .cyText(.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            if model.phase == .idle || model.phase == .loadingVacancies {
                CYSkeleton()
            } else if model.phase == .ready, model.vacancies.isEmpty {
                CYEmptyState(systemImage: "tray", "chapterReplacement.vacancies.empty")
            } else {
                ForEach(model.vacancies) { vacancy in
                    Button {
                        Task { await model.select(vacancy, coordinates: coordinates) }
                    } label: {
                        HStack(alignment: .top, spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "flag")
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text("chapterReplacement.vacancy.row \(vacancy.chapterID) \(vacancy.offerID)")
                                    .cyText(.cardTitle)
                                    .foregroundStyle(palette.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(verbatim: shown(vacancy.withdrawReason))
                                    .cyText(.meta)
                                    .foregroundStyle(palette.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: CYSpacing.sm)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("chapterReplacement.vacancy.\(vacancy.offerID)")
                    .accessibilityAddTraits(model.selectedVacancy?.id == vacancy.id ? .isSelected : [])
                }
            }
        }
    }

    @ViewBuilder private var candidateSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("chapterReplacement.section.candidates")
                .cyText(.sectionTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            if case .loadingCandidates = model.phase {
                CYSkeleton()
            } else if model.candidates.isEmpty {
                CYEmptyState(systemImage: "person.2", "chapterReplacement.candidates.empty")
            } else {
                ForEach(model.candidates) { candidate in
                    Button {
                        Task { await model.prepare(candidate) }
                    } label: {
                        HStack(spacing: CYSpacing.md) {
                            CYRowIcon(systemImage: "person")
                            Group {
                                if let name = personName(candidate.displayName) {
                                    Text(verbatim: name)
                                } else {
                                    Text("chapterReplacement.candidate.member \(candidate.merchantMemberID)")
                                }
                            }
                            .cyText(.cardTitle)
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: CYSpacing.sm)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(palette.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.cyPressable)
                    .accessibilityIdentifier("chapterReplacement.candidate.\(candidate.id)")
                }
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        switch model.phase {
        case .reviewing(let plan):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text("chapterReplacement.section.review")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                if let focus, focus.matches(plan.candidate) {
                    // MP 邀请商家补位 modal: names instead of ids when the merchant was chosen on 找商家承接.
                    Text(verbatim: focus.confirmText(chinese: LocaleDisplay.isChinese(locale)))
                        .cyText(.body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("chapterReplacement.review.focus")
                } else {
                    Text("chapterReplacement.review.invite \(plan.candidate.merchantMemberID) \(plan.candidate.chapterID) \(plan.candidate.replacementOfOfferID)")
                        .cyText(.body)
                        .foregroundStyle(palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text("chapterReplacement.review.pendingOnly")
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("chapterReplacement.send", systemImage: "paperplane.fill") { Task { await model.confirm() } }
                    .accessibilityIdentifier("chapterReplacement.send")
                    .accessibilityLabel(Text("chapterReplacement.send"))
                Button("action.cancel", role: .cancel) { model.cancelReview() }
                    .cyText(.bodyMedium)
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            }
        case .sending:
            CYSkeleton()
                .frame(minHeight: CYSpacing.minTouchTarget)
                .accessibilityIdentifier("chapterReplacement.sending")
        case .unknown(let plan):
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text("chapterReplacement.section.unknown")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    .fixedSize(horizontal: false, vertical: true)
                Text("chapterReplacement.unknown \(shownTuple(plan.targetTuple))")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                CYPillButton("chapterReplacement.verify", systemImage: "arrow.clockwise") { Task { await model.verifyUnknown() } }
                    .accessibilityIdentifier("chapterReplacement.verifyUnknown")
                    .accessibilityLabel(Text("chapterReplacement.verify"))
            }
        case .verified(let verified):
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("chapterReplacement.section.verified")
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Group {
                    if let applicationID = verified.applicationID {
                        Text("chapterReplacement.verified.application \(applicationID)")
                    } else {
                        Text("chapterReplacement.verified")
                    }
                }
                .cyText(.body)
                .foregroundStyle(palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("chapterReplacement.verified")
            }
        case .failed(let failure):
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                CYEmptyState(systemImage: "exclamationmark.triangle", "chapterReplacement.section.failed", kind: .failure)
                Text(verbatim: shown(String(describing: failure)))
                    .cyText(.meta)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("chapterReplacement.failed")
            }
        default:
            EmptyView()
        }
    }

    private func personName(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || isRawKey(trimmed) { return nil }
        return trimmed
    }

    /// Interpolation values must stay the catalog placeholders. A dotted key in the tuple becomes an em dash.
    private func shownTuple(_ raw: String) -> String {
        isRawKey(raw) ? "—" : raw
    }

    private func shown(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "—" }
        return isRawKey(trimmed) ? "—" : trimmed
    }

    private func isRawKey(_ raw: String) -> Bool {
        raw.range(of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#, options: .regularExpression) != nil
    }
}

/// Typed haptic condition (design consistency `untyped haptic`): fires when the state lands on `.sending`.
private extension ChapterReplacementInvitationView {
    static func startedSending(_ old: ChapterReplacementInvitationCoordinator.Phase, _ new: ChapterReplacementInvitationCoordinator.Phase) -> Bool {
        if case .sending = new { return true }
        return false
    }
}
