import SwiftUI

/// Shared pieces for the player discovery + commerce pages (activity, route, bundle, registration).
/// Presentation only. Covers use the real image when an HTTPS URL exists; otherwise a neutral tile
/// (DEBUG fixtures get labelled generated art so layouts are judged with imagery).

/// Cover tile that fills its frame: remote image, else gradient + SF symbol.
struct E1CoverArt: View {
    let seed: String
    var symbol = "sparkles"
    var imageURL: String? = nil
    var debugLabel = true
    /// Where the generated-art glyph sits, as a fraction of the cover. Cards that put a chip top-right move it away.
    /// `nil` drops the glyph (covers whose title block would sit on it).
    var symbolPoint: CGPoint? = CGPoint(x: 0.8, y: 0.24)
    /// MP default cover (`MPAsset.BannerCover.*`) shown instead of the generated art when there is no
    /// loadable image. `fallbackFills` false draws it aspect-fit on the neutral tile (MP `cy-cover-fb`).
    var fallbackImage: Image? = nil
    var fallbackFills = true
    @Environment(\.cyPalette) private var palette

    private var url: URL? {
        guard let imageURL, let u = URL(string: imageURL), u.scheme?.lowercased() == "https" else { return nil }
        return u
    }
    private var hue: Double {
        Double(seed.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 360 }) / 360
    }
    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { art }
                }
            } else {
                art
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var art: some View {
        if let fallbackImage {
            if fallbackFills { fallbackImage.resizable().scaledToFill() }
            else {
                LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay { fallbackImage.resizable().scaledToFit().padding(CYSpacing.md) }
            }
        } else { generatedArt }
    }
    @ViewBuilder private var generatedArt: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--design-fixture") { debugArt } else { neutral }
        #else
        neutral
        #endif
    }
    private var neutral: some View {
        LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay { if symbolPoint != nil { Image(systemName: symbol).font(.title).foregroundStyle(palette.textPlaceholder) } }
    }
    #if DEBUG
    private var debugArt: some View {
        let h2 = (hue + 0.14).truncatingRemainder(dividingBy: 1)
        return ZStack {
            LinearGradient(colors: [Color(hue: hue, saturation: 0.6, brightness: 0.66), Color(hue: h2, saturation: 0.78, brightness: 0.24)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Color(hue: h2, saturation: 0.5, brightness: 0.95).opacity(0.5), .clear],
                           center: .topTrailing, startRadius: 2, endRadius: 190)
            RadialGradient(colors: [Color(hue: hue, saturation: 0.4, brightness: 1).opacity(0.28), .clear],
                           center: .bottomLeading, startRadius: 2, endRadius: 150)
            GeometryReader { g in
                if let symbolPoint {
                    let glyphSize = max(16, min(g.size.width, g.size.height) * 0.3)
                    Image(systemName: symbol)
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.light)
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: glyphSize, height: glyphSize)
                        .position(x: g.size.width * symbolPoint.x, y: g.size.height * symbolPoint.y)
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if debugLabel {
                Text(verbatim: "DEBUG ART").cyText(.micro).foregroundStyle(.white.opacity(0.5)).padding(6)
            }
        }
    }
    #endif
}

/// Frosted capsule used on top of covers (duration, distance, stops, status).
struct E1GlassChip: View {
    let systemImage: String
    let text: String
    var body: some View {
        Label { Text(verbatim: text).monospacedDigit() } icon: { Image(systemName: systemImage) }
            .font(.caption.weight(.semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(.black.opacity(0.42), in: Capsule(style: .continuous))
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
    }
}

enum E1Money {
    /// `¥12.5`; nil when the amount is unknown (never rendered as 0).
    static func yuan(_ value: Decimal?, locale: Locale) -> String? {
        guard let value, value >= 0 else { return nil }
        return "¥" + value.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
    }
    static func yuan(text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text.hasPrefix("¥") ? text : "¥" + text
    }
}

/// Activity timing state derived from the server dates only; nil when dates are absent/unparseable.
enum E1ActivityState {
    case upcoming, live, ended
    static func of(start: String?, end: String?, now: Date = Date()) -> E1ActivityState? {
        let utc = TimeZone(secondsFromGMT: 0)!
        func parse(_ raw: String?) -> Date? {
            guard let raw, !raw.isEmpty else { return nil }
            return HomeFeedDate.parse(raw, sourceTimeZone: nil) ?? HomeFeedDate.parse(raw, sourceTimeZone: utc)
        }
        let s = parse(start), e = parse(end)
        if let e, e < now { return .ended }
        if let s, s > now { return .upcoming }
        if s != nil, e != nil { return .live }
        if let s, s <= now { return e == nil ? .ended : .live }
        return nil
    }
    func chip(_ copy: CoreLoopCopy) -> CYStatusChip {
        switch self {
        case .upcoming: return CYStatusChip(verbatim: copy.t("即将开始", "Upcoming"), tone: .info, systemImage: "clock")
        case .live: return CYStatusChip(verbatim: copy.t("进行中", "Happening now"), tone: .success, systemImage: "dot.radiowaves.left.and.right")
        case .ended: return CYStatusChip(verbatim: copy.t("已结束", "Ended"), tone: .neutral, systemImage: "checkmark")
        }
    }
}

/// Quiet section heading with a leading icon (forms and detail pages).
struct E1IconHeader: View {
    let systemImage: String
    let title: String
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Label { Text(verbatim: title) } icon: { Image(systemName: systemImage).foregroundStyle(palette.textSecondary) }
            .font(CYTypography.sectionTitle.weight(.semibold))
            .foregroundStyle(palette.textPrimary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

/// Dashed ticket perforation with two side notches (registration ticket card).
struct E1Perforation: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Rectangle().fill(.clear).frame(height: 1)
            .overlay(Line().stroke(palette.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [5, 4])).padding(.horizontal, CYSpacing.lg))
            .accessibilityHidden(true)
    }
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: rect.minX, y: rect.midY)); p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)); return p }
    }
}

// MARK: - Tail helpers (Form / List screens restyled with the kit; presentation only)

extension View {
    /// Hero title row for a Form/List: transparent row, page margins, no separator.
    func e1HeroRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    /// Full-width action row for a Form/List (hosts a `CYPillButton`).
    func e1ActionRow() -> some View {
        listRowInsets(EdgeInsets(top: CYSpacing.xs, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.xs, trailing: CYSpacing.pageHorizontal))
            .listRowBackground(Color.clear)
    }
}

/// Label-only pill content for a NavigationLink styled with CYPillButtonStyle.
struct CYPillButtonLabel: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    init(_ title: LocalizedStringKey, systemImage: String? = nil) { self.title = title; self.systemImage = systemImage }
    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            if let systemImage { Image(systemName: systemImage) }
            Text(title)
        }
    }
}
