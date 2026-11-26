import SwiftUI

// MC-30 · badges get real art: one family, shape by category (shield = 探索, hexagon = 成就,
// crest = 俱乐部), emblem by badge (SF Symbol). Locked = the same art in grey with its condition;
// in progress = a ring with `3 / 7`. Never a single character, never the same star for all.

enum ClubBadgeCategory: String, CaseIterable, Sendable {
    case explore, achievement, club

    /// Category from the server's category or family text; unknown falls back to 成就.
    static func resolve(_ raw: String?) -> ClubBadgeCategory {
        let text = (raw ?? "").lowercased()
        if text.contains("club") || text.contains("俱乐部") || text.contains("团") { return .club }
        if text.contains("explore") || text.contains("roam") || text.contains("探索") || text.contains("城市") || text.contains("足迹") { return .explore }
        return .achievement
    }
}

enum ClubBadgeEmblem {
    /// Keyword → emblem, checked in order. Covers the badges named in the frames (初 · 通 · 城 · 连 …).
    static let table: [(keywords: [String], symbol: String)] = [
        (["初", "first", "新手", "启程"], "flag.fill"),
        (["通关", "complete", "完成", "通"], "checkmark.seal.fill"),
        (["连续", "streak", "连"], "flame.fill"),
        (["城市", "城", "city"], "building.2.fill"),
        (["夜", "night"], "moon.stars.fill"),
        (["解谜", "puzzle", "谜"], "puzzlepiece.fill"),
        (["步", "walk", "徒步"], "figure.walk"),
        (["美食", "food", "咖啡", "cafe"], "cup.and.saucer.fill"),
        (["摄影", "photo", "拍"], "camera.fill"),
        (["探索", "explore", "足迹"], "map.fill"),
        (["签到", "check", "打卡"], "mappin.and.ellipse"),
        (["主理", "host", "领队"], "person.badge.shield.checkmark.fill"),
        (["活动", "event"], "ticket.fill"),
        (["贡献", "contrib", "榜"], "trophy.fill"),
    ]
    static let fallback: [String] = ["star.fill", "leaf.fill", "bolt.fill", "heart.fill", "sun.max.fill", "binoculars.fill"]

    static func symbol(for name: String, seed: String) -> String {
        let lowered = name.lowercased()
        for entry in table where entry.keywords.contains(where: { lowered.contains($0) }) { return entry.symbol }
        var hash: UInt64 = 1469598103934665603
        for byte in (seed.isEmpty ? name : seed).utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return fallback[Int(hash % UInt64(fallback.count))]
    }
}

/// The badge outline for a category.
struct ClubBadgeShape: Shape {
    let category: ClubBadgeCategory

    func path(in rect: CGRect) -> Path {
        switch category {
        case .explore: return Self.shield(rect)
        case .achievement: return Self.hexagon(rect)
        case .club: return Self.crest(rect)
        }
    }

    private static func shield(_ r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.16))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY),
                   control1: CGPoint(x: r.maxX, y: r.minY + r.height * 0.62),
                   control2: CGPoint(x: r.midX + r.width * 0.22, y: r.maxY - r.height * 0.08))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.16),
                   control1: CGPoint(x: r.midX - r.width * 0.22, y: r.maxY - r.height * 0.08),
                   control2: CGPoint(x: r.minX, y: r.minY + r.height * 0.62))
        p.closeSubpath()
        return p
    }

    private static func hexagon(_ r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY), radius = min(r.width, r.height) / 2
        for i in 0..<6 {
            let angle = Double(i) * .pi / 3 - .pi / 2
            let point = CGPoint(x: c.x + radius * CGFloat(cos(angle)), y: c.y + radius * CGFloat(sin(angle)))
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        p.closeSubpath()
        return p
    }

    private static func crest(_ r: CGRect) -> Path {
        var p = Path()
        let notch = r.width * 0.18
        p.move(to: CGPoint(x: r.minX, y: r.minY + notch))
        p.addLine(to: CGPoint(x: r.minX + r.width * 0.25, y: r.minY))
        p.addLine(to: CGPoint(x: r.midX, y: r.minY + notch))
        p.addLine(to: CGPoint(x: r.maxX - r.width * 0.25, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + notch))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.6))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY - r.height * 0.1))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.minY + r.height * 0.6), control: CGPoint(x: r.minX, y: r.maxY - r.height * 0.1))
        p.closeSubpath()
        return p
    }
}

enum ClubBadgeState: Equatable, Sendable {
    case earned
    case locked
    case inProgress(current: Int, target: Int)
}

/// Badge/Art: the shape, a metal rim and the emblem. Locked renders the same art in grey.
struct ClubBadgeArt: View {
    let name: String
    var seed: String = ""
    var category: ClubBadgeCategory = .achievement
    var isLit = true
    var size: CGFloat = 64
    @Environment(\.cyPalette) private var palette

    var body: some View {
        let shape = ClubBadgeShape(category: category)
        ZStack {
            shape.fill(isLit ? metal : palette.bgRaised)
            shape.stroke(isLit ? rim : palette.borderStrong, lineWidth: max(1.5, size * 0.05))
            Image(systemName: ClubBadgeEmblem.symbol(for: name, seed: seed))
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.4, height: size * 0.4)
                .foregroundStyle(isLit ? palette.textInverse : palette.textTertiary)
                .offset(y: category == .explore ? -size * 0.04 : 0)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var metal: Color {
        switch category {
        case .explore: return palette.medalSilver
        case .achievement: return palette.medalGold
        case .club: return palette.medalBronze
        }
    }
    private var rim: Color { palette.textPrimary.opacity(0.18) }
}

/// Badge/Tile: art, name and (when locked or in progress) the condition. Grid of three per row.
struct ClubBadgeTile: View {
    let name: String
    var seed: String = ""
    var category: ClubBadgeCategory = .achievement
    var condition: String?
    let state: ClubBadgeState
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if case .inProgress(let current, let target) = state {
                    // Fitness-style progress ring in system colours.
                    Circle()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: ClubBadgeTile.fraction(current, target))
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                ClubBadgeArt(name: name, seed: seed, category: category, isLit: state == .earned, size: 56)
            }
            .frame(width: 72, height: 72)
            Text(verbatim: clubR1Value(name))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(state == .earned ? Color.primary : Color.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            switch state {
            case .earned:
                EmptyView()
            case .locked:
                Text(verbatim: clubR1Value(condition))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            case .inProgress(let current, let target):
                Text(verbatim: "\(current) / \(target)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    static func fraction(_ current: Int, _ target: Int) -> CGFloat {
        guard target > 0 else { return 0 }
        return CGFloat(min(max(current, 0), target)) / CGFloat(target)
    }

    private var accessibilityText: String {
        switch state {
        case .earned: return String(format: clubR1("badge.a11y.earned", locale), clubR1Value(name))
        case .locked: return String(format: clubR1("badge.a11y.locked", locale), clubR1Value(name), clubR1Value(condition))
        case .inProgress(let current, let target):
            return String(format: clubR1("badge.a11y.progress", locale), clubR1Value(name), current, target)
        }
    }
}
