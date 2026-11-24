import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Roam nearby parity (mini-program `subpackageRoam/nearby`): the team card's "举报队伍" entry and the official place
// expanded card (place play, Xiaohongshu, info rows, "网上怎么说" quotes, player reviews + my review, photo credit).
// Layout only. The report goes through the existing `TeamOrientBoardAccess.reportTeam`; place extras need a binding.

// MARK: - Official place extras

struct RoamPlaceGame: Equatable {
    let title: String?
    let detail: String?
    let steps: [String]
    let completed: Bool
}

struct RoamPlaceInfoRow: Identifiable, Equatable {
    let key: String
    let value: String
    var id: String { key }
}

/// A cited press / travelogue excerpt. Kept apart from player reviews and never presented as a player.
struct RoamPlaceQuote: Identifiable, Equatable {
    let url: String
    let text: String
    let sourceLabel: String
    var id: String { url }
}

struct RoamPlaceReview: Identifiable, Equatable {
    let id: String
    let name: String?
    let timeText: String?
    let stars: Int?
    let text: String
}

struct RoamPlaceExtras: Equatable {
    var placeName: String
    var game: RoamPlaceGame?
    var infoRows: [RoamPlaceInfoRow]
    var quotes: [RoamPlaceQuote]
    var reviews: [RoamPlaceReview]
    /// False until the review read finished (the empty sentence waits for it).
    var reviewsLoaded: Bool
    /// The player already reviewed this place: the compose block hides.
    var reviewed: Bool
    var photoCredit: String?
    var reviewBusy = false
    var reviewError: String?
}

/// Logic stub for Cursor: official place facts (template game, info rows, cited quotes, photo credit) and
/// place reviews (read + publish once the place challenge is completed).
@MainActor protocol RoamPlaceExtrasBinding: AnyObject, Observable {
    var extras: RoamPlaceExtras? { get }
    func load()
    func publishReview(stars: Int, text: String)
}

private struct RoamPlaceExtrasProviderKey: EnvironmentKey {
    static let defaultValue: (@MainActor (_ poiID: Int) -> (any RoamPlaceExtrasBinding)?)? = nil
}

extension EnvironmentValues {
    /// Nil (default) hides the place extras entirely.
    var roamPlaceExtrasProvider: (@MainActor (_ poiID: Int) -> (any RoamPlaceExtrasBinding)?)? {
        get { self[RoamPlaceExtrasProviderKey.self] }
        set { self[RoamPlaceExtrasProviderKey.self] = newValue }
    }
}

/// Mount point under the POI node card. Draws nothing without a provider or binding.
@MainActor struct RoamPlaceExtrasMount: View {
    let poiID: Int
    @Environment(\.roamPlaceExtrasProvider) private var provider
    @State private var binding: (any RoamPlaceExtrasBinding)?

    var body: some View {
        Group {
            if let production = binding as? RoamPlaceExtrasProduction {
                RoamPlaceExtrasLive(binding: production)
            } else if let binding, let extras = binding.extras {
                RoamPlaceExtrasSection(extras: extras, onPublish: { binding.publishReview(stars: $0, text: $1) })
            }
        }
        .task(id: poiID) {
            guard binding == nil, let made = provider?(poiID) else { return }
            binding = made
            made.load()
        }
    }
}

struct RoamPlaceExtrasSection: View {
    let extras: RoamPlaceExtras
    let onPublish: (Int, String) -> Void
    @Environment(\.locale) private var locale
    @State private var creditOpen = false
    @State private var copiedNotice: String?
    @State private var myStars = 0
    @State private var myText = ""
    @State private var showingReviewSheet = false
    @State private var confirmPublishReview = false
    @State private var toastMessage: String?
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        Section {
            if let game = extras.game { gameCard(game) }
            infoRows
            if !extras.quotes.isEmpty { quotes }
            reviews
            if extras.game?.completed == true && !extras.reviewed {
                Button {
                    showingReviewSheet = true
                } label: {
                    Text(verbatim: c.t("评价据点", "Review this place"))
                }
                .accessibilityIdentifier("roam.place.reviewSheetOpen")
            }
            if let credit = extras.photoCredit, !credit.isEmpty { creditRow(credit) }
            if let copiedNotice {
                Text(verbatim: copiedNotice).cyText(.meta).foregroundStyle(CYColor.successText)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .accessibilityIdentifier("roam.place.extras")
        .sheet(isPresented: $showingReviewSheet) {
            PlayCloseSheetHost(
                title: c.t("评价据点", "Review Place"),
                detents: [.half],
                onClose: { showingReviewSheet = false }
            ) {
                compose
                    .padding(CYSpacing.pageHorizontal)
                    .padding(.bottom, CYSpacing.lg)
            }
        }
        .cyModalOverlay(isPresented: confirmPublishReview) {
            CYModal(
                title: c.t("确认发布评价？", "Publish review?"),
                message: c.t("发布后可在据点页展示或再调整。", "Your review will be published on this place."),
                cancelTitle: c.t("取消", "Cancel"),
                confirmTitle: c.t("发布", "Publish"),
                onCancel: { confirmPublishReview = false },
                onConfirm: {
                    confirmPublishReview = false
                    showingReviewSheet = false
                    onPublish(myStars, myText.trimmingCharacters(in: .whitespacesAndNewlines))
                    toastMessage = c.t("已提交评价", "Review submitted")
                }
            )
        }
        .cyToast(verbatimMessage: $toastMessage)
    }

    private func gameCard(_ game: RoamPlaceGame) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack {
                Text(verbatim: c.t("地点玩法", "Place play")).cyText(.caption).tracking(0.6).foregroundStyle(CYNight.lantern)
                Spacer()
                if game.completed { CYStatusChip(verbatim: c.t("已完成", "Completed"), tone: .success, systemImage: "checkmark") }
            }
            Text(verbatim: game.title ?? c.t("地点挑战", "Place challenge")).cyText(.cardTitle)
            if let detail = game.detail { Text(verbatim: detail).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary) }
            ForEach(Array(game.steps.enumerated()), id: \.offset) { index, step in
                Text(verbatim: "\(index + 1)  \(step)").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.place.game")
    }

    @ViewBuilder private var infoRows: some View {
        Button {
            LocalPasteboard.copy(extras.placeName)
            copiedNotice = c.t("已复制地点名，去小红书搜笔记", "Place name copied. Search it on Xiaohongshu.")
        } label: {
            LabeledContent { Text(verbatim: c.t("复制地点名去搜笔记", "Copy the place name to search notes")).foregroundStyle(CYColor.textSecondary) } label: {
                Text(verbatim: c.t("小红书", "Xiaohongshu"))
            }
            .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityIdentifier("roam.place.xhs")
        ForEach(extras.infoRows) { row in
            LabeledContent { Text(verbatim: row.value) } label: { Text(verbatim: row.key) }
        }
    }

    private var quotes: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: c.t("网上怎么说", "What people say online")).cyText(.label).accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    ForEach(extras.quotes) { quote in
                        Button {
                            LocalPasteboard.copy(quote.url)
                            copiedNotice = c.t("已复制原文链接", "Source link copied")
                        } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text(verbatim: "「\(quote.text)」").cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary).lineLimit(4)
                                Text(verbatim: "\(quote.sourceLabel) · " + c.t("复制原文链接", "Copy source link")).cyText(.caption).foregroundStyle(CYColor.textSecondary)
                            }
                            .frame(width: 240, alignment: .leading)
                            .padding(CYSpacing.md)
                            .background(CYNight.ink2, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: c.t("复制原文链接：", "Copy source link: ") + quote.sourceLabel))
                    }
                }
            }
        }
        .accessibilityIdentifier("roam.place.quotes")
    }

    private var reviews: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.xs) {
                Text(verbatim: c.t("玩家评价", "Player reviews")).cyText(.label)
                if !extras.reviews.isEmpty { Text(verbatim: String(extras.reviews.count)).cyText(.label).foregroundStyle(CYColor.textSecondary) }
            }
            .accessibilityAddTraits(.isHeader)
            if extras.reviews.isEmpty {
                if extras.reviewsLoaded {
                    Text(verbatim: c.t("还没有评价。完成挑战后来写第一条。", "No reviews yet. Finish the challenge and write the first one."))
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("roam.place.reviewsEmpty")
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(extras.reviews) { review in
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                HStack {
                                    Text(verbatim: review.name ?? c.t("玩家", "Player")).cyText(.label)
                                    Spacer()
                                    if let time = review.timeText { Text(verbatim: time).cyText(.caption).foregroundStyle(CYColor.textTertiary) }
                                }
                                if let stars = review.stars {
                                    Label { Text(verbatim: String(stars)) } icon: { Image(systemName: "star.fill") }
                                        .cyText(.caption).foregroundStyle(CYNight.lantern)
                                        .accessibilityLabel(Text(verbatim: c.t("\(stars) 星", "\(stars) stars")))
                                }
                                Text(verbatim: review.text).cyText(.bodyCompact).lineLimit(4)
                            }
                            .frame(width: 220, alignment: .leading)
                            .padding(CYSpacing.md)
                            .background(CYNight.ink2, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("roam.place.reviews")
    }

    private var compose: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(1...5, id: \.self) { value in
                    Button { myStars = value } label: {
                        Image(systemName: value <= myStars ? "star.fill" : "star")
                            .cyText(.sectionTitle)
                            .foregroundStyle(value <= myStars ? CYNight.lantern : CYColor.textTertiary)
                            .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: c.t("\(value) 星", "\(value) stars")))
                    .accessibilityAddTraits(value <= myStars ? [.isSelected] : [])
                }
            }
            .cyHaptic(.selection, trigger: myStars)
            TextField(c.t("说说这次挑战和这个地方", "Tell us about the challenge and this place"), text: $myText, axis: .vertical)
                .lineLimit(2...5)
                .onChange(of: myText) { _, value in if value.count > 200 { myText = String(value.prefix(200)) } }
                .accessibilityLabel(Text(verbatim: c.t("写评价", "Write a review")))
                .accessibilityIdentifier("roam.place.reviewText")
            if let error = extras.reviewError { Text(verbatim: error).cyText(.meta).foregroundStyle(CYColor.dangerText) }
            CYPillButton(verbatim: extras.reviewBusy ? c.t("发布中…", "Publishing…") : c.t("发布评价", "Publish review"), style: .secondary) {
                confirmPublishReview = true
            }
            .disabled(extras.reviewBusy || myStars == 0 || myText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("roam.place.reviewPublish")
        }
    }

    private func creditRow(_ credit: String) -> some View {
        DisclosureGroup(isExpanded: $creditOpen) {
            Text(verbatim: credit).cyText(.meta).foregroundStyle(CYColor.textSecondary).textSelection(.enabled)
        } label: {
            Text(verbatim: c.t("照片来源与许可", "Photo sources and licences")).cyText(.meta).foregroundStyle(CYColor.textSecondary)
        }
        .accessibilityIdentifier("roam.place.photoCredit")
    }
}
