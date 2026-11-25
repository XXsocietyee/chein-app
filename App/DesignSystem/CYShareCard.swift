import SwiftUI
import UIKit

// Share card kit (e3 share hero). A card is a fixed artboard (360pt wide, story 9:16 or square 1:1)
// rendered by `ImageRenderer` at 3x, so it uses fixed sizes on purpose: Dynamic Type applies to the
// composer chrome around it, never to the exported bitmap. Every caller passes already-localised
// strings; the kit holds no copy of its own. Unknown values render as an em dash, never a zero.

// MARK: - Model

enum CYShareCardTemplate: String, CaseIterable, Identifiable {
    case poster, ticket, minimal
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .poster: return "photo.artframe"
        case .ticket: return "ticket"
        case .minimal: return "textformat"
        }
    }
    func name(_ locale: Locale) -> String {
        switch self {
        case .poster: return locale.pick("海报", "Poster")
        case .ticket: return locale.pick("票根", "Ticket")
        case .minimal: return locale.pick("极简", "Minimal")
        }
    }
}

enum CYShareCardRatio: String, CaseIterable, Identifiable {
    case story, portrait, square
    var id: String { rawValue }
    /// Artboard size in points. 3x export gives 1080×1920 (story), 1080×1350 (portrait) and 1080×1080 (square).
    var size: CGSize {
        switch self {
        case .story: return CGSize(width: 360, height: 640)
        case .portrait: return CGSize(width: 360, height: 450)
        case .square: return CGSize(width: 360, height: 360)
        }
    }
    var isStory: Bool { self == .story }
    /// Template metrics: the story value, the square value, and their midpoint for portrait.
    func metric(_ story: CGFloat, _ square: CGFloat) -> CGFloat {
        switch self {
        case .story: return story
        case .portrait: return ((story + square) / 2).rounded()
        case .square: return square
        }
    }
    func name(_ locale: Locale) -> String {
        switch self {
        case .story: return locale.pick("竖版 9:16", "Story 9:16")
        case .portrait: return locale.pick("竖版 4:5", "Portrait 4:5")
        case .square: return locale.pick("方形 1:1", "Square 1:1")
        }
    }
}

/// Background swatches. Hue-based so the lint tokens stay in `CYDesignTokens`; no violet (that stays on the selected tab).
enum CYShareCardTint: String, CaseIterable, Identifiable {
    case ink, ember, ocean, moss, sunset, gold
    var id: String { rawValue }
    /// The swatches a person can pick (skill-r2 SR2-08, owner Q11): the share-card palette has no mustard, so `gold`
    /// stays only for cards rendered before this rule and is never offered.
    static var pickable: [CYShareCardTint] { allCases.filter { $0 != .gold } }
    /// Bright colour: strokes, eyebrow text, glow.
    var primary: Color {
        switch self {
        case .ink: return Color(hue: 0.62, saturation: 0.06, brightness: 0.92)
        case .ember: return Color(hue: 0.03, saturation: 0.82, brightness: 0.96)
        case .ocean: return Color(hue: 0.55, saturation: 0.75, brightness: 0.92)
        case .moss: return Color(hue: 0.36, saturation: 0.62, brightness: 0.78)
        case .sunset: return Color(hue: 0.95, saturation: 0.68, brightness: 0.98)
        case .gold: return Color(hue: 0.12, saturation: 0.78, brightness: 0.96)
        }
    }
    /// Deep colour: the card ground.
    var secondary: Color {
        switch self {
        case .ink: return Color(hue: 0.64, saturation: 0.10, brightness: 0.09)
        case .ember: return Color(hue: 0.02, saturation: 0.78, brightness: 0.28)
        case .ocean: return Color(hue: 0.60, saturation: 0.72, brightness: 0.24)
        case .moss: return Color(hue: 0.40, saturation: 0.60, brightness: 0.18)
        case .sunset: return Color(hue: 0.90, saturation: 0.62, brightness: 0.26)
        case .gold: return Color(hue: 0.09, saturation: 0.70, brightness: 0.24)
        }
    }
    func name(_ locale: Locale) -> String {
        switch self {
        case .ink: return locale.pick("墨色", "Ink")
        case .ember: return locale.pick("炭火", "Ember")
        case .ocean: return locale.pick("海蓝", "Ocean")
        case .moss: return locale.pick("苔绿", "Moss")
        case .sunset: return locale.pick("晚霞", "Sunset")
        case .gold: return locale.pick("金色", "Gold")
        }
    }
}

struct CYShareCardStyle: Equatable {
    var template: CYShareCardTemplate = .poster
    var ratio: CYShareCardRatio = .story
    var tint: CYShareCardTint = .ink
    func with(template: CYShareCardTemplate) -> CYShareCardStyle {
        var copy = self; copy.template = template; return copy
    }
}

/// One stat cell. `value == nil` renders as an em dash.
struct CYShareStat: Equatable, Identifiable {
    let label: String
    let value: String?
    var id: String { label }
    init(_ label: String, _ value: String?) {
        self.label = label
        self.value = value?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? value : nil
    }
    var display: String { value ?? "—" }
}

struct CYShareCardContent: Equatable {
    enum Kind: Equatable { case walk, medal, route, activity }
    var kind: Kind
    /// Small uppercase line above the title (already localised, e.g. "CITY WALK").
    var eyebrow: String
    var title: String
    /// Date or category line under the title. Optional.
    var subtitle: String?
    /// Place line. `nil` shows an em dash when `showsPlace` is true; callers gate it behind a privacy toggle.
    var place: String?
    var showsPlace = true
    var stats: [CYShareStat] = []
    /// Normalised polyline (0...1, y down). Empty hides the silhouette; one point draws a pin.
    var silhouette: [CGPoint] = []
    var artSeed: String
    var artSymbol: String
    var caption: String = ""
    var brand: String
    /// Generated art carries CYCoverArt's tiny label in DEBUG builds only; Release never shows it.
    var debugArt = true
    /// MP share card without a cover: the route illustration (`subpackageRoam/components/cy/share-card/route-art.png`)
    /// replaces the generated art. Default off keeps every other card unchanged.
    var mpRouteArt = false

    var placeDisplay: String { place?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? place! : "—" }
    var trimmedCaption: String { caption.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// One VoiceOver sentence for the preview: title, subtitle, place, every stat, caption.
    var accessibilitySummary: String {
        var parts: [String] = [eyebrow, title]
        if let subtitle, !subtitle.isEmpty { parts.append(subtitle) }
        if showsPlace { parts.append(placeDisplay) }
        parts.append(contentsOf: stats.map { "\($0.label) \($0.display)" })
        if !trimmedCaption.isEmpty { parts.append(trimmedCaption) }
        return parts.joined(separator: ", ")
    }

    /// Fits latitude/longitude pairs into the unit square (aspect preserved, 8% inset, north up).
    static func silhouette(latitudes: [Double], longitudes: [Double]) -> [CGPoint] {
        let pairs = zip(latitudes, longitudes).filter { $0.0.isFinite && $0.1.isFinite }
        guard let first = pairs.first else { return [] }
        if pairs.count == 1 { return [CGPoint(x: 0.5, y: 0.5)] }
        var minLat = first.0, maxLat = first.0, minLng = first.1, maxLng = first.1
        for (lat, lng) in pairs {
            minLat = min(minLat, lat); maxLat = max(maxLat, lat)
            minLng = min(minLng, lng); maxLng = max(maxLng, lng)
        }
        // Longitude degrees shrink with latitude; scale so the sketch keeps its real proportions.
        let midLat = (minLat + maxLat) / 2
        let lngScale = max(0.2, cos(midLat * .pi / 180))
        let width = (maxLng - minLng) * lngScale, height = maxLat - minLat
        let span = max(width, height)
        guard span > 0 else { return [CGPoint(x: 0.5, y: 0.5)] }
        let inset = 0.08, usable = 1 - inset * 2
        let offsetX = (span - width) / 2, offsetY = (span - height) / 2
        return pairs.map { lat, lng in
            let x = ((lng - minLng) * lngScale + offsetX) / span
            let y = ((maxLat - lat) + offsetY) / span
            return CGPoint(x: inset + x * usable, y: inset + y * usable)
        }
    }
}

// MARK: - Silhouette

/// Route sketch: round-capped polyline with a glow, a filled start dot and a ring at the end. One point draws a pin.
struct CYShareCardSilhouette: View {
    let points: [CGPoint]
    var stroke: Color = .white
    var lineWidth: CGFloat = 4
    var glow = true

    var body: some View {
        Canvas { context, size in
            guard let first = points.first else { return }
            func position(_ point: CGPoint) -> CGPoint { CGPoint(x: point.x * size.width, y: point.y * size.height) }
            if points.count == 1 {
                let center = position(first)
                let pin = CGRect(x: center.x - lineWidth * 3, y: center.y - lineWidth * 3, width: lineWidth * 6, height: lineWidth * 6)
                context.fill(Circle().path(in: pin.insetBy(dx: -lineWidth * 2, dy: -lineWidth * 2)), with: .color(stroke.opacity(0.22)))
                context.fill(Circle().path(in: pin), with: .color(stroke))
                return
            }
            var path = Path()
            for (index, point) in points.enumerated() {
                if index == 0 { path.move(to: position(point)) } else { path.addLine(to: position(point)) }
            }
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            if glow {
                context.stroke(path, with: .color(stroke.opacity(0.28)), style: StrokeStyle(lineWidth: lineWidth * 3.2, lineCap: .round, lineJoin: .round))
            }
            context.stroke(path, with: .color(stroke), style: style)
            let start = position(first), end = position(points[points.count - 1])
            let dot = lineWidth * 1.6
            context.fill(Circle().path(in: CGRect(x: start.x - dot, y: start.y - dot, width: dot * 2, height: dot * 2)), with: .color(stroke))
            context.stroke(Circle().path(in: CGRect(x: end.x - dot, y: end.y - dot, width: dot * 2, height: dot * 2)),
                           with: .color(stroke), lineWidth: lineWidth * 0.8)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Card

/// The artboard. Fixed size from `style.ratio`; callers scale it for previews via `CYShareCardPreview`.
struct CYShareCard: View {
    let content: CYShareCardContent
    let style: CYShareCardStyle

    var body: some View {
        let size = style.ratio.size
        Group {
            switch style.template {
            case .poster: CYShareCardPoster(content: content, style: style)
            case .ticket: CYShareCardTicket(content: content, style: style)
            case .minimal: CYShareCardMinimal(content: content, style: style)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: content.accessibilitySummary))
    }
}

/// Scales the artboard to the width the layout gives it; the preview and the export are the same view.
struct CYShareCardPreview: View {
    let content: CYShareCardContent
    let style: CYShareCardStyle
    var cornerRadius: CGFloat = CYRadius.xl

    var body: some View {
        let size = style.ratio.size
        Color.clear
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    let scale = proxy.size.width / size.width
                    CYShareCard(content: content, style: style)
                        .scaleEffect(scale, anchor: .topLeading)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: content.accessibilitySummary))
    }
}

/// Preview and export share one view, so what the user approves is what leaves the device.
/// Budget: one 3x export in 120 ms or less (`CYShareRenderBudget`); call it from a `Task` after the press, never inside an animation frame.
@MainActor enum CYShareCardRenderer {
    static func render(_ content: CYShareCardContent, style: CYShareCardStyle, scale: CGFloat = 3) -> UIImage? {
        let renderer = ImageRenderer(content: CYShareCard(content: content, style: style)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, .large))
        renderer.scale = scale
        renderer.isOpaque = true
        let started = CFAbsoluteTimeGetCurrent()
        let image = renderer.uiImage
        CYShareRenderBudget.check(CFAbsoluteTimeGetCurrent() - started, ratio: style.ratio)
        return image
    }
}

// MARK: - Shared pieces

private struct CYShareEyebrowRow: View {
    let eyebrow: String
    let brand: String
    var tint: Color = .white
    var onLight = false
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: eyebrow.uppercased())
                .cyText(.caption, weight: .bold).tracking(2.2)
                .foregroundStyle(tint)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(verbatim: brand)
                .cyText(.meta, weight: .semibold)
                .foregroundStyle(onLight ? Color.black.opacity(0.55) : Color.white.opacity(0.7))
                .lineLimit(1)
        }
    }
}

private struct CYShareMetaLine: View {
    let content: CYShareCardContent
    var color: Color = .white.opacity(0.82)
    var body: some View {
        HStack(spacing: 10) {
            if let subtitle = content.subtitle, !subtitle.isEmpty {
                Label { Text(verbatim: subtitle) } icon: { Image(systemName: "calendar") }
            }
            if content.showsPlace {
                Label { Text(verbatim: content.placeDisplay) } icon: { Image(systemName: "mappin.and.ellipse") }
            }
        }
        .cyText(.label)
        .foregroundStyle(color)
        .lineLimit(1)
        .labelStyle(CYShareTightLabelStyle())
    }
}

private struct CYShareTightLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon; configuration.title }
    }
}

private struct CYShareStatsRow: View {
    let stats: [CYShareStat]
    var valueColor: Color = .white
    var labelColor: Color = .white.opacity(0.7)
    var valueSize: CGFloat = 24
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(stats.prefix(4)) { stat in
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: stat.display)
                        .font(.system(size: valueSize, weight: .bold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(valueColor)
                        .lineLimit(1).minimumScaleFactor(0.6)
                    Text(verbatim: stat.label.uppercased())
                        .cyText(.micro).tracking(1)
                        .foregroundStyle(labelColor)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct CYShareCaption: View {
    let caption: String
    var color: Color = .white.opacity(0.92)
    var body: some View {
        if !caption.isEmpty {
            Text(verbatim: "“" + caption + "”")
                .cyText(.body).italic()
                .foregroundStyle(color)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Medal art for `.medal` content: foil rim around generated art with the medal glyph.
private struct CYShareMedalArt: View {
    let content: CYShareCardContent
    let tint: CYShareCardTint
    var size: CGFloat = 150

    /// Gold is the completion medal. Silver and bronze follow when the title or symbol names that metal.
    /// A stamp share (`mappin.and.ellipse` on a medal card) uses the 3D stamp.
    private var medalImage: (Image) {
        let blob = (content.artSymbol + " " + content.title + " " + content.artSeed).lowercased()
        if blob.contains("bronze") || blob.contains("铜") { return MPAsset.BadgeMedal.medalBronze }
        if blob.contains("silver") || blob.contains("银") { return MPAsset.BadgeMedal.medalSilver }
        if content.artSymbol == "mappin.and.ellipse" { return MPAsset.BadgeMedal.stamp3d }
        if content.artSymbol == "storefront.fill" { return MPAsset.BadgeMedal.glShop }
        if content.artSymbol == "medal" { return MPAsset.BadgeMedal.medal }
        return MPAsset.BadgeMedal.medalGold
    }

    var body: some View {
        CYFoilMedal(unlocked: true, size: size, tint: tint.primary) {
            ZStack {
                CYCoverArt(seed: content.artSeed, symbol: content.artSymbol, showsDebugLabel: false, showsGlyph: false)
                medalImage
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.62, height: size * 0.62)
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            }
        }
    }
}

// MARK: - Template 1: poster (image-led, text over a scrim)

private struct CYShareCardPoster: View {
    let content: CYShareCardContent
    let style: CYShareCardStyle
    var body: some View {
        let ratio = style.ratio
        ZStack(alignment: .bottomLeading) {
            if content.mpRouteArt { MPAsset.BannerCover.routeArt.resizable().scaledToFill() }
            else { CYCoverArt(seed: content.artSeed, symbol: content.artSymbol, showsDebugLabel: content.debugArt, showsGlyph: content.kind != .medal) }
            LinearGradient(colors: [style.tint.primary.opacity(0.22), style.tint.secondary.opacity(0.92)],
                           startPoint: .top, endPoint: .bottom)
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                CYShareEyebrowRow(eyebrow: content.eyebrow, brand: content.brand, tint: .white.opacity(0.9))
                Spacer(minLength: 12)
                if content.kind == .medal {
                    // Share badge (210:10082, SR2-08): the earned badge at 144 pt on the story card.
                    CYShareMedalArt(content: content, tint: style.tint, size: ratio.metric(144, 120))
                        .frame(maxWidth: .infinity)
                } else if !content.silhouette.isEmpty {
                    CYShareCardSilhouette(points: content.silhouette, stroke: .white, lineWidth: ratio.metric(5, 4))
                        .frame(height: ratio.metric(230, 120))
                }
                Spacer(minLength: 12)
                Text(verbatim: content.title)
                    .font(.system(size: ratio.metric(34, 26), weight: .heavy))
                    .lineLimit(ratio == .square ? 2 : 3).minimumScaleFactor(0.7)
                    .fixedSize(horizontal: false, vertical: true)
                CYShareMetaLine(content: content)
                    .padding(.top, 6)
                if !content.stats.isEmpty {
                    CYShareStatsRow(stats: content.stats, valueSize: ratio.metric(24, 20))
                        .padding(.top, ratio.metric(18, 12))
                }
                CYShareCaption(caption: content.trimmedCaption)
                    .padding(.top, ratio.metric(16, 10))
            }
            .foregroundStyle(.white)
            .padding(ratio.metric(28, 22))
        }
    }
}

// MARK: - Template 2: ticket (stats-led stub with a perforation)

private struct CYShareCardTicket: View {
    let content: CYShareCardContent
    let style: CYShareCardStyle
    private let paper = Color(white: 0.98)
    private let inkText = Color(white: 0.10)
    var body: some View {
        let ratio = style.ratio
        let ground = style.tint.secondary
        ZStack {
            LinearGradient(colors: [style.tint.secondary, style.tint.secondary.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            Group {
                if content.mpRouteArt { MPAsset.BannerCover.routeArt.resizable().scaledToFill() }
                else { CYCoverArt(seed: content.artSeed, symbol: content.artSymbol, showsDebugLabel: content.debugArt, showsGlyph: false) }
            }
                .opacity(0.28)
            VStack(spacing: 0) {
                // Upper stub: identity.
                VStack(alignment: .leading, spacing: 10) {
                    CYShareEyebrowRow(eyebrow: content.eyebrow, brand: content.brand, tint: style.tint.secondary, onLight: true)
                    Text(verbatim: content.title)
                        .font(.system(size: ratio.metric(28, 22), weight: .heavy))
                        .foregroundStyle(inkText)
                        .lineLimit(ratio == .square ? 2 : 3).minimumScaleFactor(0.7)
                        .fixedSize(horizontal: false, vertical: true)
                    CYShareMetaLine(content: content, color: Color.black.opacity(0.6))
                    if content.kind == .medal {
                        CYShareMedalArt(content: content, tint: style.tint, size: ratio.metric(140, 96))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 6)
                    } else if !content.silhouette.isEmpty {
                        CYShareCardSilhouette(points: content.silhouette, stroke: style.tint.secondary, lineWidth: 4, glow: false)
                            .frame(height: ratio.metric(170, 90))
                            .background(style.tint.primary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.top, 6)
                    }
                }
                .padding(ratio.metric(22, 18))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(paper)
                // Perforation: a gap that shows the ground, two notches, a dashed tear line.
                ZStack {
                    ground.frame(height: 14)
                    Line().stroke(Color.black.opacity(0.22), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                        .frame(height: 1).padding(.horizontal, 18)
                    HStack {
                        Circle().fill(ground).frame(width: 22, height: 22).offset(x: -11)
                        Spacer()
                        Circle().fill(ground).frame(width: 22, height: 22).offset(x: 11)
                    }
                }
                .frame(height: 14)
                .zIndex(1)
                // Lower stub: numbers.
                VStack(alignment: .leading, spacing: 12) {
                    if !content.stats.isEmpty {
                        CYShareStatsRow(stats: content.stats, valueColor: inkText, labelColor: Color.black.opacity(0.55), valueSize: ratio.metric(28, 22))
                    }
                    CYShareCaption(caption: content.trimmedCaption, color: Color.black.opacity(0.7))
                }
                .padding(ratio.metric(22, 18))
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(paper)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            .padding(ratio.metric(26, 20))
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path(); path.move(to: CGPoint(x: rect.minX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return path
        }
    }
}

// MARK: - Template 3: minimal (typographic, solid ground, large silhouette)

private struct CYShareCardMinimal: View {
    let content: CYShareCardContent
    let style: CYShareCardStyle
    var body: some View {
        let ratio = style.ratio
        ZStack {
            style.tint.secondary
            RadialGradient(colors: [style.tint.primary.opacity(0.35), .clear], center: UnitPoint(x: 0.15, y: 0.1), startRadius: 0, endRadius: ratio.metric(420, 300))
            VStack(alignment: .leading, spacing: 0) {
                CYShareEyebrowRow(eyebrow: content.eyebrow, brand: content.brand, tint: style.tint.primary)
                Text(verbatim: content.title)
                    .font(.system(size: ratio.metric(40, 30), weight: .bold, design: .serif))
                    .lineLimit(3).minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14)
                CYShareMetaLine(content: content, color: .white.opacity(0.7))
                    .padding(.top, 8)
                Spacer(minLength: 10)
                if content.kind == .medal {
                    CYShareMedalArt(content: content, tint: style.tint, size: ratio.metric(160, 100))
                        .frame(maxWidth: .infinity)
                } else if !content.silhouette.isEmpty {
                    CYShareCardSilhouette(points: content.silhouette, stroke: style.tint.primary, lineWidth: 3)
                        .frame(height: ratio.metric(220, 100))
                }
                Spacer(minLength: 10)
                if !content.stats.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(content.stats.prefix(4)) { stat in
                            HStack(alignment: .firstTextBaseline) {
                                Text(verbatim: stat.label).cyText(.label).foregroundStyle(.white.opacity(0.7))
                                Spacer(minLength: 8)
                                Text(verbatim: stat.display).font(.system(size: ratio.metric(20, 17), weight: .semibold, design: .rounded)).monospacedDigit()
                            }
                            .padding(.vertical, ratio.metric(8, 5))
                            if stat.id != content.stats.prefix(4).last?.id {
                                Rectangle().fill(.white.opacity(0.14)).frame(height: 1)
                            }
                        }
                    }
                }
                CYShareCaption(caption: content.trimmedCaption)
                    .padding(.top, ratio.metric(18, 10))
            }
            .foregroundStyle(.white)
            .padding(ratio.metric(32, 24))
        }
    }
}

// MARK: - Previews (synthetic)

#Preview("Share card · three templates") {
    let content = CYShareCardContent(kind: .walk, eyebrow: "City walk", title: "Sunday hutong loop", subtitle: "12 Oct 2026", place: "—",
                                     stats: [CYShareStat("Distance", "4.2 km"), CYShareStat("Duration", "1 h 10 min"), CYShareStat("Shops", "3"), CYShareStat("Explored", nil)],
                                     silhouette: [CGPoint(x: 0.1, y: 0.8), CGPoint(x: 0.3, y: 0.4), CGPoint(x: 0.55, y: 0.5), CGPoint(x: 0.9, y: 0.15)],
                                     artSeed: "hutong", artSymbol: "figure.walk", caption: "Best dumplings on the last stop.", brand: "城瘾", debugArt: true)
    ScrollView(.horizontal) {
        HStack(spacing: 16) {
            ForEach(CYShareCardTemplate.allCases) { template in
                CYShareCardPreview(content: content, style: CYShareCardStyle(template: template, ratio: .story, tint: .ocean)).frame(width: 240)
            }
        }.padding()
    }.background(Color.black)
}
