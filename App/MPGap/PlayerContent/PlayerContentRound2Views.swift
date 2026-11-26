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
    /// MP `registrationId` set: 修改已保存; otherwise 报名已提交.
    public let saved: Bool
    /// Route · chapter · stop names the link carried (MP summary card); empty hides the card.
    public let lines: [String]
    public var onViewProgress: (() -> Void)?
    public var onBackHome: (() -> Void)?

    public init(saved: Bool, lines: [String], onViewProgress: (() -> Void)?, onBackHome: (() -> Void)?) {
        self.saved = saved
        self.lines = lines
        self.onViewProgress = onViewProgress
        self.onBackHome = onBackHome
    }

    public var body: some View {
        ContentUnavailableView {
            Label(saved ? "merchantApply.success.saved" : "merchantApply.success.title", systemImage: "checkmark.circle")
        } description: {
            VStack(spacing: 4) {
                // MP index.wxml:177-185: 已保存 after an edit; 主理人确认后生效，预计 1–3 天 after a create.
                Text(saved ? "merchantApply.success.savedDetail" : "merchantApply.success.pending")
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line).foregroundStyle(.secondary)
                }
            }
        } actions: {
            if let onViewProgress {
                Button("merchantApply.success.viewProgress", action: onViewProgress)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("merchantApply.success.viewProgress")
            }
            if let onBackHome {
                Button("merchantApply.success.backHome", action: onBackHome)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("merchantApply.success.backHome")
            }
        }
    }
}

/// R7-PC-B3-3: MP merchantapply `shop` from `POST /api/merchant/info` (index.js:240-255).
struct MerchantApplyShop: Equatable {
    let name: String
    let address: String
    let businessTime: String
    let cover: URL?
    let latitude: Double?
    let longitude: Double?

    init(_ d: PlayWireValue) {
        func text(_ key: String) -> String { (d[key].text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }
        func number(_ key: String) -> Double? { d[key].double ?? d[key].text.flatMap { Double($0.trimmingCharacters(in: .whitespaces)) } }
        name = text("name"); address = text("address"); businessTime = text("businessTime")
        // Cover: 门头图 first, else the logo; first of a comma list; https only.
        let firstCover = (text("coverImage").isEmpty ? text("logo") : text("coverImage"))
            .split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        cover = URL(string: firstCover).flatMap { $0.scheme?.lowercased() == "https" ? $0 : nil }
        latitude = number("locationLat"); longitude = number("locationLng")
    }
    var isEmpty: Bool { name.isEmpty && address.isEmpty && businessTime.isEmpty }
    /// Apple Maps link at the store coordinate; nil without a real point.
    var mapURL: URL? {
        guard let latitude, let longitude, latitude.isFinite, longitude.isFinite, !(latitude == 0 && longitude == 0) else { return nil }
        var parts = URLComponents(string: "https://maps.apple.com/")
        parts?.queryItems = [URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"), URLQueryItem(name: "q", value: name.isEmpty ? address : name)]
        return parts?.url
    }
}

private struct MerchantApplyShopServiceKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> PlayerContentRound2Service?)? = nil
}
extension EnvironmentValues {
    /// R7-PC-B3-3: signed-in `/api/merchant/info` read for the merchantapply store card.
    var merchantApplyShopService: (@MainActor () -> PlayerContentRound2Service?)? {
        get { self[MerchantApplyShopServiceKey.self] }
        set { self[MerchantApplyShopServiceKey.self] = newValue }
    }
}

extension AppSession {
    func makeMerchantApplyShopService() -> PlayerContentRound2Service? {
        guard (account?.id ?? 0) > 0, let token, let api = regionalConfiguration?.apiConfiguration else { return nil }
        return PlayerContentRound2Service(baseURL: api.baseURL, token: { token }, transport: runtimeHTTPTransport)
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
                // R9-PC-D3-1: CMS images carry no alt text; VoiceOver names them as article images.
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("social.article.image"))
                .accessibilityAddTraits(.isImage)
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
