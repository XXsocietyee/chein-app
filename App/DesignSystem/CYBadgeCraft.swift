import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Night-city light, crafted badge (wave 3 B5 review). The unlock cover used a flat cover-art disc; this is the object that
// lands: a silhouette per badge type (medal with ribbon, star, shield with laurel) so the bloom matches the badge, a lantern
// gold gradient rim with an inner bevel, a quiet noise grain, and a foil sheen that drifts live (a slow lissajous stands in
// for the gyro until CYFoil from B1 lands; Reduce Motion pins it at 25 %).

enum CYBadgeKind: Equatable {
    case medal, star, shield
    /// Stable per badge id, so a badge keeps its silhouette everywhere.
    init(seed: String) {
        switch CYCoverArt.stableHash(seed) % 3 {
        case 0: self = .medal
        case 1: self = .star
        default: self = .shield
        }
    }
}

struct CYBadgeShape: InsettableShape {
    var kind: CYBadgeKind
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> CYBadgeShape { var copy = self; copy.inset += amount; return copy }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        switch kind {
        case .medal: return Path(ellipseIn: r)
        case .star: return Self.star(in: r)
        case .shield: return Self.shield(in: r)
        }
    }

    /// Five-point star with softened tips.
    private static func star(in r: CGRect) -> Path {
        let c = CGPoint(x: r.midX, y: r.midY + r.height * 0.03)
        let outer = min(r.width, r.height) / 2, inner = outer * 0.50
        var pts: [CGPoint] = []
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2
            let rad = i % 2 == 0 ? outer : inner
            pts.append(CGPoint(x: c.x + CGFloat(cos(a)) * rad, y: c.y + CGFloat(sin(a)) * rad))
        }
        return rounded(pts, radius: outer * 0.10)
    }

    /// Heater shield: broad shoulders, pointed base.
    private static func shield(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        let top = r.minY + h * 0.06
        p.move(to: CGPoint(x: r.minX + w * 0.08, y: top + h * 0.10))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: top), control: CGPoint(x: r.minX + w * 0.30, y: top + h * 0.10))
        p.addQuadCurve(to: CGPoint(x: r.maxX - w * 0.08, y: top + h * 0.10), control: CGPoint(x: r.maxX - w * 0.30, y: top + h * 0.10))
        p.addLine(to: CGPoint(x: r.maxX - w * 0.08, y: r.minY + h * 0.52))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY - h * 0.02),
                   control1: CGPoint(x: r.maxX - w * 0.08, y: r.minY + h * 0.78), control2: CGPoint(x: r.midX + w * 0.22, y: r.maxY - h * 0.12))
        p.addCurve(to: CGPoint(x: r.minX + w * 0.08, y: r.minY + h * 0.52),
                   control1: CGPoint(x: r.midX - w * 0.22, y: r.maxY - h * 0.12), control2: CGPoint(x: r.minX + w * 0.08, y: r.minY + h * 0.78))
        p.closeSubpath()
        return p
    }

    private static func rounded(_ pts: [CGPoint], radius: CGFloat) -> Path {
        var path = Path()
        let n = pts.count
        for i in 0..<n {
            let prev = pts[(i + n - 1) % n], cur = pts[i], next = pts[(i + 1) % n]
            func toward(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
                let dx = b.x - a.x, dy = b.y - a.y, len = max(sqrt(dx * dx + dy * dy), 0.001)
                let d = min(radius, len / 2)
                return CGPoint(x: a.x + dx / len * d, y: a.y + dy / len * d)
            }
            let start = toward(cur, prev), end = toward(cur, next)
            if i == 0 { path.move(to: start) } else { path.addLine(to: start) }
            path.addQuadCurve(to: end, control: cur)
        }
        path.closeSubpath()
        return path
    }
}

/// The badge object. `foilTime` (seconds) drives the sheen; nil = static highlight (Reduce Motion, Low Power).
struct CYCraftedMedal: View {
    var kind: CYBadgeKind
    var seed: String
    var symbol: String?
    var size: CGFloat = 168
    var foilTime: Double?
    /// Rarity foil. 0 hides it (locked). Passed through `cyFoil`'s strength.
    var foilStrength: Double = 1

    private static let motifs = ["moon.stars.fill", "mappin.and.ellipse", "flame.fill", "camera.fill", "leaf.fill", "star.fill", "bolt.fill", "heart.fill",
                                 "figure.walk", "cup.and.saucer.fill", "ticket.fill", "binoculars.fill", "sun.max.fill", "bicycle"]
    private var glyph: String { symbol ?? Self.motifs[Int(CYCoverArt.stableHash(seed) % UInt64(Self.motifs.count))] }
    private var rim: CGFloat { size * 0.075 }
    private var shape: CYBadgeShape { CYBadgeShape(kind: kind) }
    private var face: CYBadgeShape { CYBadgeShape(kind: kind, inset: rim) }

    var body: some View {
        ZStack {
            if kind == .medal { ribbon }
            if kind == .shield { laurel }
            plate
            faceArt
            bevel
            glyphMark
            grain
        }
        .frame(width: size, height: size)
        .cyFoil(in: shape, active: foilStrength > 0, strength: foilStrength)
        .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
        .accessibilityHidden(true)
    }

    // Lantern gold plate: angular gradient so the rim reads as turned metal.
    private var plate: some View {
        shape.fill(AngularGradient(colors: [CYNight.lanternHot, CYNight.lantern, CYNight.ember, CYNight.lantern, CYNight.lanternHot, CYNight.lantern, CYNight.lanternHot],
                                   center: .center, angle: .degrees(-30)))
            .overlay(shape.strokeBorder(Color.white.opacity(0.35), lineWidth: 0.75))
    }

    private var faceArt: some View {
        ZStack {
            CYCoverArt(seed: seed, symbol: glyph, showsDebugLabel: false, showsGlyph: false)
            LinearGradient(colors: [.clear, CYNight.ink0.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.white.opacity(0.30), .clear], center: UnitPoint(x: 0.3, y: 0.18), startRadius: 0, endRadius: size * 0.5)
        }
        .clipShape(face)
    }

    // Inner bevel: light edge on top-left, shadow edge on bottom-right, plus a hairline between plate and face.
    private var bevel: some View {
        ZStack {
            face.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.75), .clear, Color.black.opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 2)
            shape.inset(by: rim * 0.45).strokeBorder(Color.black.opacity(0.22), lineWidth: 1)
        }
    }

    private var glyphMark: some View {
        Group {
            if let art = CYMedalGlyph.image(for: glyph) {
                art.resizable().scaledToFit().frame(width: size * 0.42, height: size * 0.42)
            } else {
                Image(systemName: glyph)
                    .accessibilityHidden(true).font(.system(size: size * (kind == .medal ? 0.36 : 0.30), weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.white, CYNight.lanternHot], startPoint: .top, endPoint: .bottom))
            }
        }
        .shadow(color: .black.opacity(0.45), radius: 2, y: 2)
        .offset(y: kind == .star ? size * 0.03 : (kind == .shield ? -size * 0.02 : 0))
    }

    private var grain: some View {
        Canvas { context, canvas in
            for i in 0..<320 {
                let x = Double((i &* 7919) % 997) / 997 * canvas.width
                let y = Double((i &* 104729) % 991) / 991 * canvas.height
                context.fill(Path(CGRect(x: x, y: y, width: 1, height: 1)), with: .color(i % 2 == 0 ? .white : .black))
            }
        }
        .opacity(0.10)
        .blendMode(.overlay)
        .clipShape(shape)
        .allowsHitTesting(false)
    }

    // Two ribbon tails behind the medal, notched at the ends.
    private var ribbon: some View {
        HStack(spacing: size * 0.04) {
            tail.rotationEffect(.degrees(8))
            tail.scaleEffect(x: -1).rotationEffect(.degrees(-8))
        }
        .offset(y: size * 0.60)
    }

    private var tail: some View {
        Path { p in
            let w = size * 0.20, h = size * 0.42
            p.move(to: .zero)
            p.addLine(to: CGPoint(x: w, y: 0))
            p.addLine(to: CGPoint(x: w, y: h))
            p.addLine(to: CGPoint(x: w / 2, y: h - w * 0.35))
            p.addLine(to: CGPoint(x: 0, y: h))
            p.closeSubpath()
        }
        .fill(LinearGradient(colors: [CYNight.lantern, CYNight.ember], startPoint: .top, endPoint: .bottom))
        .overlay(Rectangle().fill(Color.black.opacity(0.18)).frame(width: 1).offset(x: size * 0.10))
        .frame(width: size * 0.20, height: size * 0.42)
    }

    private var laurel: some View {
        MPAsset.BadgeMedal.laurel
            .resizable()
            .scaledToFit()
            .frame(width: size * 1.15, height: size * 0.74)
            .offset(y: size * 0.04)
            .opacity(0.9)
    }
}

#if canImport(UIKit)
/// UIKit / SceneKit palette tokens for the 3D badge showroom turntable and medallion placeholder.
enum CYBadgeShowroomPalette {
    static let stageBackground = UIColor(red: 0.08, green: 0.09, blue: 0.14, alpha: 1)
    static let emblemFill = UIColor(red: 0.13, green: 0.16, blue: 0.25, alpha: 1)

    static func accent(style: String, rarity: Int) -> UIColor {
        switch (style, rarity) {
        case ("glow", _), (_, 4): return UIColor(red: 0.96, green: 0.78, blue: 0.28, alpha: 1)
        case (_, 3): return UIColor(red: 0.30, green: 0.78, blue: 0.72, alpha: 1)
        case (_, 2): return UIColor(red: 0.42, green: 0.76, blue: 0.96, alpha: 1)
        default: return UIColor(red: 0.85, green: 0.74, blue: 0.48, alpha: 1)
        }
    }
}
#endif
