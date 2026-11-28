import SwiftUI
import UIKit

/// Mini `square/utils/square-share.js` (U-050) as a pure projection. Only a PUBLIC, published post
/// shares its own excerpt and first image; everything else falls back to the generic card with no
/// post content (a sent card is frozen in the receiver's chat, so nothing private may leak into it).
struct CYSquareSharePayload: Equatable {
    static let titleLimit = 28
    let postID: Int?
    /// Nil means the generic card ("城瘾Hub").
    let excerpt: String?
    let imageURL: URL?
    var isGeneric: Bool { postID == nil }
    static let generic = CYSquareSharePayload()
    private init() { postID = nil; excerpt = nil; imageURL = nil }

    init(post: SquarePost) {
        guard PublicContentShareLink.squarePost(PublicContentShareLink.l5Post(from: post)) != nil else {
            postID = nil; excerpt = nil; imageURL = nil; return
        }
        postID = post.id
        let text = (post.contents ?? "").split(whereSeparator: \.isWhitespace).joined(separator: " ")
        excerpt = text.isEmpty ? nil : (text.count > Self.titleLimit ? String(text.prefix(Self.titleLimit)) + "…" : text)
        imageURL = post.images.lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { ObjectCardMediaPolicy.origin($0) != nil }
            .flatMap(URL.init(string:))
    }
}

/// Mini detail `act-share` (open-type=share, placed after like/comment/bookmark, Threads-style).
/// Native: a half sheet with the card the receiver will see, then the system share sheet.
struct CYSquareShareSheet: View {
    let payload: CYSquareSharePayload
    let url: URL
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack {
                Text("share.title", tableName: "SocialParity").cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(CYTypography.label.weight(.semibold))
                        .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                        .background(Circle().fill(CYColor.bgSurfaceSubtle))
                }
                .buttonStyle(.cyPressable)
                .accessibilityLabel(Text("share.close", tableName: "SocialParity"))
                .accessibilityIdentifier("square.share.close")
            }
            card
            if payload.isGeneric {
                Text("share.genericNote", tableName: "SocialParity").cyText(.meta).foregroundStyle(CYColor.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ShareLink(item: url, preview: SharePreview(payload.excerpt ?? Self.brand)) {
                Label { Text("share.send", tableName: "SocialParity") } icon: { Image(systemName: "square.and.arrow.up") }
                    .font(CYTypography.bodyMedium.weight(.semibold))
                    .foregroundStyle(CYColor.textOnAccent)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Capsule().fill(CYColor.actionPrimaryBg))
            }
            .buttonStyle(.cyPressable)
            .accessibilityIdentifier("square.share.send")
            Button {
                UIPasteboard.general.setItems(
                    [["public.utf8-plain-text": url.absoluteString]],
                    options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
                withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { copied = true }
            } label: {
                Label { Text(LocalizedStringKey(copied ? "share.copied" : "share.copy"), tableName: "SocialParity") } icon: { Image(systemName: copied ? "checkmark" : "link") }
                    .font(CYTypography.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.cyPressable)
            .accessibilityIdentifier("square.share.copy")
        }
        .padding(CYSpacing.lg)
        .presentationDetents([.medium])
        .cyPlayerSheetGlass()
        .accessibilityIdentifier("square.share.sheet")
    }

    private static let brand = "城瘾Hub"

    private var card: some View {
        HStack(spacing: CYSpacing.md) {
            Group {
                if let image = payload.imageURL {
                    AsyncImage(url: image) { phase in
                        if let loaded = phase.image { loaded.resizable().scaledToFill() } else { CYColor.bgSurfaceSubtle }
                    }
                } else {
                    ZStack { CYColor.bgSurfaceSubtle; Image(systemName: "sparkles").foregroundStyle(CYColor.textSecondary) }
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: payload.excerpt ?? Self.brand).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                Text(verbatim: Self.brand).cyText(.meta).foregroundStyle(CYColor.textTertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.sheetCard))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(CYColor.borderSubtle, lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("square.share.card")
    }
}
