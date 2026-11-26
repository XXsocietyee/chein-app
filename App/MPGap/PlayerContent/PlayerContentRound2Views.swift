import PhotosUI
import SwiftUI

/// `PC-B-1-6` / `PC-C-1-7`: 5-star review composer with 300-char limit & up to 9 photos.
public struct ContextualReviewStarAndPhotoComposerView: View {
    @Binding public var rating: Int
    @Binding public var content: String
    @State private var pickerItems: [PhotosPickerItem] = []
    public let uploadedURLs: [String]
    public let isSubmitting: Bool
    public var onSelectPhotos: ([PhotosPickerItem]) -> Void = { _ in }
    public var onSubmit: () -> Void
    public var onClose: () -> Void

    private let maxChars = 300

    public init(
        rating: Binding<Int>,
        content: Binding<String>,
        uploadedURLs: [String] = [],
        isSubmitting: Bool = false,
        onSelectPhotos: @escaping ([PhotosPickerItem]) -> Void = { _ in },
        onSubmit: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._rating = rating
        self._content = content
        self.uploadedURLs = uploadedURLs
        self.isSubmitting = isSubmitting
        self.onSelectPhotos = onSelectPhotos
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("reviewComposer.title"), style: .player, onClose: onClose)
            Form {
                Section("reviewComposer.rating") {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(1...5, id: \.self) { star in
                            Button {
                                rating = star
                            } label: {
                                Image(systemName: star <= rating ? "star.fill" : "star")
                                    .cyText(.sectionTitle)
                                    .foregroundStyle(star <= rating ? CYColor.brand : CYColor.textSecondary)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("\(star) 星"))
                        }
                    }
                }

                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                        .onChange(of: content) { _, newValue in
                            if newValue.count > maxChars { content = String(newValue.prefix(maxChars)) }
                        }
                } header: {
                    Text("reviewComposer.content")
                } footer: {
                    HStack {
                        Spacer()
                        Text("\(content.count)/\(maxChars)")
                            .cyText(.meta, monospacedDigit: true)
                    }
                }

                Section("reviewComposer.photos") {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 9,
                        matching: .images
                    ) {
                        Label("选择图片（最多 9 张，已选 \(uploadedURLs.count)）", systemImage: "photo.on.rectangle.angled")
                            .cyText(.bodyCompact)
                    }
                    .onChange(of: pickerItems) { _, items in
                        onSelectPhotos(items)
                    }
                }

                Section {
                    Button("common.submit", action: onSubmit)
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .disabled(isSubmitting || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// `PC-B-3-2` / `PC-B-3-3`: Merchant application address/map picker, photo upload, & success card
/// (write goes through `MerchantContentWriteApproval`, MP-first default on).
public struct MerchantApplySuccessSummaryView: View {
    public let shopName: String
    public let topicTitle: String
    public var onViewProgress: () -> Void
    public var onBackHome: () -> Void

    public init(
        shopName: String,
        topicTitle: String,
        onViewProgress: @escaping () -> Void,
        onBackHome: @escaping () -> Void
    ) {
        self.shopName = shopName
        self.topicTitle = topicTitle
        self.onViewProgress = onViewProgress
        self.onBackHome = onBackHome
    }

    public var body: some View {
        ContentUnavailableView {
            Label("merchantApply.success.title", systemImage: "checkmark.seal.fill")
        } description: {
            Text("\(shopName) · \(topicTitle)")
                .cyText(.body)
        } actions: {
            Button("merchantApply.success.viewProgress", action: onViewProgress)
                .buttonStyle(.borderedProminent)
            Button("merchantApply.success.backHome", action: onBackHome)
                .buttonStyle(.bordered)
        }
    }
}

/// `PC-C-1-1` / `PC-C-1-5` / `PC-C-4-4`: Cancelled activity state, owner cancel footer, and official footer bar.
public struct ActivityCancelledStateView: View {
    public let canViewOwnOrders: Bool
    public var onViewOrders: () -> Void
    public var onBack: () -> Void

    public init(canViewOwnOrders: Bool, onViewOrders: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.canViewOwnOrders = canViewOwnOrders
        self.onViewOrders = onViewOrders
        self.onBack = onBack
    }

    public var body: some View {
        ContentUnavailableView {
            Label("activity.cancelled.title", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("activity.cancelled.subtitle")
        } actions: {
            // R9-PC-C1-1: one CTA, as the MP cy-empty (scene-play-activity-detail/index.wxml:5-6):
            // 查看我的订单 with an own order, otherwise 返回活动列表.
            if canViewOwnOrders {
                Button("activity.cancelled.viewOrders", action: onViewOrders)
                    .buttonStyle(.borderedProminent)
            } else {
                Button("activity.cancelled.backToList", action: onBack)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}

/// `PC-D-3-2` / `PC-D-9-4`: CMS rich article blocks & IM composer `+` menu.
public struct SocialArticleRichBlocksView: View {
    public let blocks: [SocialArticleRichBlock]

    public init(blocks: [SocialArticleRichBlock]) {
        self.blocks = blocks
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            ForEach(blocks) { block in
                switch block {
                case .text(_, let content):
                    Text(verbatim: content)
                        .cyText(.body)
                        .foregroundStyle(CYColor.textPrimary)
                case .image(_, let urlStr):
                    // A missing or unusable URL is omitted. A later load failure drops only this image.
                    if let url = QuestifyCardArtwork.safeURL(urlStr),
                       ObjectCardMediaPolicy.origin(url.absoluteString) != nil {
                        SocialArticleRemoteImage(url: url)
                    }
                case .link(_, let title, let urlStr):
                    if let url = QuestifyCardArtwork.safeURL(urlStr) {
                        Link(destination: url) {
                            Text(verbatim: title)
                                .cyText(.bodyMedium)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                        }
                    }
                }
            }
        }
    }
}

/// Shows one CMS image with the feed remote-image view. Waiting and failure take no space, so the rest of the article stays.
private struct SocialArticleRemoteImage: View {
    let url: URL
    private enum Phase { case waiting, shown, skipped }
    @State private var phase: Phase = .waiting

    var body: some View {
        Group {
            if phase == .shown {
                PlayerFeedRemoteImage(
                    url: url,
                    maxPixel: 1200,
                    placeholder: { Color.clear },
                    failure: {
                        Color.clear
                            .frame(height: 0)
                            .onAppear { phase = .skipped }
                    }
                )
                .frame(maxWidth: .infinity)
                .aspectRatio(CYCachedAsyncImageRole.cover.aspectRatio, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }
        }
        .task(id: url) {
            phase = .waiting
            let image = await PlayerFeedImages.image(for: url, maxPixel: 1200)
            guard !Task.isCancelled else { return }
            phase = image == nil ? .skipped : .shown
        }
    }
}

public struct IMComposerPlusMenuButton: View {
    public let allowsPoll: Bool
    public var onSelect: (IMComposerPlusItem) -> Void

    public init(allowsPoll: Bool = false, onSelect: @escaping (IMComposerPlusItem) -> Void) {
        self.allowsPoll = allowsPoll
        self.onSelect = onSelect
    }

    public var body: some View {
        Menu {
            ForEach(IMComposerPlusItem.allCases) { item in
                if item != .poll || allowsPoll {
                    Button {
                        onSelect(item)
                    } label: {
                        Label(item.title, systemImage: item.systemImage)
                    }
                }
            }
        } label: {
            Image(systemName: "plus.circle")
                .accessibilityLabel(Text(verbatim: "更多"))
                .cyText(.sectionTitle)
                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
        }
    }
}
