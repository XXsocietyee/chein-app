import SwiftUI
import UIKit

// Celebration share + route draw (e4, W2-3 / W2-4). Spec: docs/release/motion-spec-celebration.md.
// The badge cover and the roam summary both end in the same sheet: a `CYShareCard` preview and one system `ShareLink`
// on the rendered bitmap. Nothing is uploaded; the route stays off the card until the person turns it on.

// MARK: - Card content

enum CYCelebrationShare {
    static func badge(_ payload: CYBadgePayload, locale: Locale) -> CYShareCardContent {
        let copy = CYCelebrationCopy(locale: locale)
        return CYShareCardContent(
            kind: .medal,
            eyebrow: copy.badgeEyebrow,
            title: CYUnknown.text(payload.name),
            showsPlace: false,
            artSeed: payload.id,
            artSymbol: payload.symbol ?? "medal.fill",
            brand: appLocalized("roamSub.w208.share.brand", locale: locale))
    }

    static func stamp(_ payload: CYStampPayload, locale: Locale) -> CYShareCardContent {
        let copy = CYCelebrationCopy(locale: locale)
        return CYShareCardContent(
            kind: .medal,
            eyebrow: copy.stampEyebrow,
            title: copy.stampLine,
            showsPlace: false,
            artSeed: payload.id,
            artSymbol: payload.symbol,
            brand: appLocalized("roamSub.w208.share.brand", locale: locale))
    }

    /// Unknown numbers are `nil` stats (an em dash on the card), never 0.
    static func walk(_ payload: CYRoamSummaryPayload, locale: Locale, includeRoute: Bool = false) -> CYShareCardContent {
        let copy = CYCelebrationCopy(locale: locale)
        let km = payload.kilometers.map { CYUnknown.decimal($0) }.flatMap { $0 == CYUnknown.dash ? nil : $0 }
        let tiles = payload.tiles.map { CYUnknown.count($0) }.flatMap { $0 == CYUnknown.dash ? nil : $0 }
        let stamps = payload.stamps.map { CYUnknown.count($0) }.flatMap { $0 == CYUnknown.dash ? nil : $0 }
        return CYShareCardContent(
            kind: .walk,
            eyebrow: appLocalized("roam.share.card.eyebrow", locale: locale),
            title: copy.walkTitle,
            showsPlace: false,
            stats: [CYShareStat(copy.kmUnit, km), CYShareStat(copy.tilesUnit, tiles), CYShareStat(copy.stampsUnit, stamps)],
            silhouette: includeRoute ? payload.route : [],
            artSeed: "walk-\(payload.id)",
            artSymbol: "figure.walk",
            brand: appLocalized("roamSub.w208.share.brand", locale: locale))
    }
}

// MARK: - Share sheet

/// Preview + render + `ShareLink`. The bitmap is rendered after the sheet is up (never inside an animation frame).
struct CYCelebrationShareSheet: View {
    let content: CYShareCardContent
    /// Walk only: lets the person put the route silhouette on the card. Off by default.
    var routeContent: CYShareCardContent?
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @State private var includeRoute = false
    @State private var image: UIImage?
    @State private var failed = false

    private var shown: CYShareCardContent { includeRoute ? (routeContent ?? content) : content }
    private let style = CYShareCardStyle(template: .poster, ratio: .story, tint: .ink)

    var body: some View {
        let copy = CYCelebrationCopy(locale: locale)
        VStack(spacing: CYSpacing.lg) {
            Text(verbatim: copy.shareTitle)
                .font(CYTypography.sheetTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, CYSpacing.xl)
            CYShareCardPreview(content: shown, style: style)
                .frame(maxHeight: 420)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
            if routeContent != nil {
                Toggle(CYKitCopy(locale: locale)("Include the route", "卡片带上路线"), isOn: $includeRoute)
                    .font(CYTypography.bodyCompact)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("cy.celebration.share.route")
            }
            Spacer(minLength: 0)
            action(copy)
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.bottom, CYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgPage.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task(id: includeRoute) { await render() }
        .accessibilityIdentifier("cy.celebration.share")
    }

    @ViewBuilder private func action(_ copy: CYCelebrationCopy) -> some View {
        if let image {
            ShareLink(item: Image(uiImage: image), preview: SharePreview(Text(verbatim: shown.title), image: Image(uiImage: image))) {
                Text(verbatim: copy.shareAction)
                    .font(CYTypography.cardTitle)
                    .frame(maxWidth: .infinity, minHeight: 56)
            }
            .buttonStyle(.cyPrimary)
            .accessibilityIdentifier("cy.celebration.share.link")
        } else if failed {
            Text(verbatim: copy.shareFailed).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
        } else {
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text(verbatim: copy.shareRendering).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
            }
            .frame(minHeight: 56)
        }
    }

    private func render() async {
        image = nil; failed = false
        // Yield once so the sheet's presentation frame is not shared with the bitmap render.
        try? await Task.sleep(for: .milliseconds(50))
        guard !Task.isCancelled else { return }
        let rendered = CYShareCardRenderer.render(shown, style: style)
        guard !Task.isCancelled else { return }
        image = rendered
        failed = rendered == nil
    }
}

// MARK: - Route draw

/// The walk's route drawn on once (`trim` 0 to 1 over 0.60 s) after the three numbers have rolled, so it is the only
/// animation running by then. Reduce Motion: the finished route cross-fades in. Decorative; the label names it for VoiceOver.
struct CYRouteDraw: View {
    let points: [CGPoint]
    let label: String
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @State private var progress: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let path = Path { path in
                for (index, point) in points.enumerated() {
                    let p = CGPoint(x: point.x * side, y: point.y * side)
                    if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
            }
            ZStack {
                path.trim(from: 0, to: reduceMotion ? 1 : progress)
                    .stroke(palette.textPrimary.opacity(0.2), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                path.trim(from: 0, to: reduceMotion ? 1 : progress)
                    .stroke(palette.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(reduceMotion && progress == 0 ? 0 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: label))
        .accessibilityIdentifier("cy.celebration.roam.route")
        .task { await draw() }
    }

    private func draw() async {
        if reduceMotion {
            withAnimation(CYMotion.reduced) { progress = 1 }
            return
        }
        // Numbers: 0.10 s stagger + 0.60 s roll. Start the route when they are done.
        try? await Task.sleep(for: .seconds(0.7))
        guard !Task.isCancelled else { return }
        withAnimation(.easeInOut(duration: CYMotion.Duration.slow)) { progress = 1 }
    }
}
