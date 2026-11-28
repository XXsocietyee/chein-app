import SwiftUI

/// One medal earned in this run. `imageURL` wins over the glyph when present.
struct CYMedalItem: Identifiable, Equatable {
    let id: String
    let name: String
    var subtitle: String? = nil
    var imageURL: String? = nil
    var systemImage: String = "rosette"
    /// MP default artwork when the server sends no medal image; nil keeps `systemImage`.
    var mpDefault: MPDefault? = nil
    enum MPDefault: Equatable {
        /// `images/play/trophy.png` (pages/play medal screen: 没配勋章图用金奖杯).
        case trophy
        /// `pages/play/images/frames/glass-badge.png` (play ending badge frame).
        case glassBadge
        var image: Image {
            switch self {
            case .trophy: MPAsset.BadgeMedal.trophy
            case .glassBadge: MPAsset.BadgeMedal.glassBadge
            }
        }
        /// `glass-badge` is the MP `cy-frames` sheet (6 × 4 frames of 112 px), not a single picture.
        var isSprite: Bool { self == .glassBadge }
    }
}

/// Hexagon used by the medal deck and the medal screen (mini-program `.ms__hex` / `.hex`).
struct CYHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + w * 0.5, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.25))
        path.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX + w * 0.5, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.25))
        path.closeSubpath()
        return path
    }
}

/// Front-to-back order shared by the deck and the screen: a tap (or horizontal drag) sends the front medal to the back.
private struct CYMedalOrder {
    var order: [Int]
    init(count: Int) { order = Array(0..<count) }
    mutating func advance() { guard order.count > 1 else { return }; order.append(order.removeFirst()) }
    func depth(of index: Int) -> Int { order.firstIndex(of: index) ?? 0 }
    var front: Int? { order.first }
}

/// Mini-program medal and badge glyphs. Unknown symbols stay SF Symbols (back, share, and other controls are not medals).
enum CYMedalGlyph {
    static func image(for symbol: String) -> Image? {
        switch symbol {
        case "rosette", "medal.fill": return MPAsset.BadgeMedal.medal3d
        case "medal": return MPAsset.BadgeMedal.medal
        case "seal", "seal.fill": return MPAsset.BadgeMedal.glassBadge
        case "trophy": return MPAsset.BadgeMedal.trophy
        case "trophy.fill": return MPAsset.BadgeMedal.glTrophy
        case "book", "book.closed", "book.pages": return MPAsset.BadgeMedal.glBook
        case "clock", "clock.fill": return MPAsset.BadgeMedal.glClock
        case "storefront", "storefront.fill", "bag", "bag.fill": return MPAsset.BadgeMedal.glShop
        case "sparkles": return MPAsset.BadgeMedal.glSpark
        case "stamp": return MPAsset.BadgeMedal.glStamp
        case "figure.walk": return MPAsset.BadgeMedal.glWalk
        case "shippingbox", "shippingbox.fill": return MPAsset.BadgeMedal.micChest
        case "mountain.2", "mountain.2.fill", "globe": return MPAsset.BadgeMedal.micEnv
        case "key", "key.fill": return MPAsset.BadgeMedal.micKey
        case "leaf", "leaf.fill": return MPAsset.BadgeMedal.micLeaf
        case "moon", "moon.fill", "moon.stars", "moon.stars.fill": return MPAsset.BadgeMedal.micMoon
        case "checkmark.seal", "checkmark.seal.fill": return MPAsset.BadgeMedal.micStamp
        case "laurel.leading", "laurel.trailing": return MPAsset.BadgeMedal.laurel
        default: return nil
        }
    }
    /// `glass-badge` (seal) is a 6 × 4 `cy-frames` sheet; draw one frame of it, never the whole sheet.
    static func isSprite(_ symbol: String) -> Bool { symbol == "seal" || symbol == "seal.fill" }
}

/// One frame of an MP `cy-frames` sprite sheet (default: `glass-badge` / `glass-success`, 6 columns × 4 rows,
/// frame 0 = the front-facing still). Static: the medal deck and stat cells never animate it.
struct CYSpriteStill: View {
    let sheet: Image
    var columns = 6
    var rows = 4
    var index = 0
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            sheet.resizable().interpolation(.high)
                .frame(width: w * CGFloat(columns), height: h * CGFloat(rows))
                .offset(x: -w * CGFloat(index % columns), y: -h * CGFloat(index / columns))
                .frame(width: w, height: h, alignment: .topLeading)
                .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Hexagon face: lantern bloom behind, artwork or glyph inside, foil sheen on top.
struct CYMedalFace: View {
    let item: CYMedalItem
    var side: CGFloat = 160
    var tone: Int = 0
    private var ground: [Color] {
        switch tone % 4 {
        case 1: return [CYNight.foilC.opacity(0.85), CYNight.indigo]
        case 2: return [CYNight.ember, CYNight.ink2]
        case 3: return [CYNight.tileTeal, CYNight.indigo]
        default: return [CYNight.lantern, CYNight.ember]
        }
    }
    var body: some View {
        ZStack {
            CYHexagon().fill(LinearGradient(colors: ground, startPoint: .topLeading, endPoint: .bottomTrailing))
            CYHexagon().hexInset(side * 0.06).fill(CYNight.ink0.opacity(0.28))
            if let url = item.imageURL, !url.isEmpty {
                CYCachedAsyncImage(url, role: .shelf)
                    .frame(width: side * 0.7, height: side * 0.7)
                    .clipShape(CYHexagon())
            } else if let art = item.mpDefault?.image ?? CYMedalGlyph.image(for: item.systemImage) {
                // The page's own MP default (trophy / glass badge) wins over the symbol-derived glyph.
                if item.mpDefault.map(\.isSprite) ?? CYMedalGlyph.isSprite(item.systemImage) {
                    CYSpriteStill(sheet: art).frame(width: side * 0.72, height: side * 0.72)
                } else {
                    art
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * 0.72, height: side * 0.72)
                }
            } else {
                Image(systemName: item.systemImage)
                    .font(.system(size: side * 0.36, weight: .semibold))
                    .foregroundStyle(CYNight.lanternHot)
            }
            CYHexagon()
                .fill(LinearGradient(colors: [.white.opacity(0.28), .clear, .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .blendMode(.screen)
            CYHexagon().hexBorder(CYNight.glassEdgeTop, lineWidth: 1)
        }
        .frame(width: side, height: side * 1.12)
        .accessibilityHidden(true)
    }
}

private extension CYHexagon {
    func hexInset(_ amount: CGFloat) -> some Shape { CYInsetHexagon(amount: amount) }
    func hexBorder(_ color: Color, lineWidth: CGFloat) -> some View { CYInsetHexagon(amount: lineWidth / 2).stroke(color, lineWidth: lineWidth) }
}
private struct CYInsetHexagon: Shape {
    let amount: CGFloat
    func path(in rect: CGRect) -> Path { CYHexagon().path(in: rect.insetBy(dx: amount, dy: amount)) }
}

/// "Earned this run · N" medal deck for finish surfaces (mini-program `play/components/finish-medals`).
/// The front medal faces you, the rest stack behind; tap or swipe to bring the next one forward.
struct CYMedalDeck: View {
    let items: [CYMedalItem]
    var side: CGFloat = 132
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var order = CYMedalOrder(count: 0)
    @State private var drag: CGFloat = 0

    var body: some View {
        if !items.isEmpty {
            VStack(spacing: CYSpacing.md) {
                Text("medalDeck.earned \(items.count)").cyText(.caption)
                    .foregroundStyle(CYColor.textSecondary)
                ZStack {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        let depth = order.depth(of: index)
                        VStack(spacing: CYSpacing.xs) {
                            CYMedalFace(item: item, side: side, tone: index)
                            Text(verbatim: item.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                .lineLimit(typeSize.isAccessibilitySize ? 4 : 2).multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                            if let sub = item.subtitle, !sub.isEmpty {
                                Text(verbatim: sub).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 2).multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: typeSize.isAccessibilitySize)
                            }
                        }
                        .opacity(depth == 0 ? 1 : 0)
                        .overlay(alignment: .top) {
                            if depth > 0 { CYMedalFace(item: item, side: side, tone: index).brightness(-0.25 * Double(min(depth, 3))) }
                        }
                        .scaleEffect(depth == 0 ? 1 : max(0.66, 1 - 0.12 * CGFloat(depth)), anchor: .top)
                        .offset(x: depth == 0 ? drag : 0, y: depth == 0 ? 0 : -14 * CGFloat(min(depth, 3)))
                        .rotationEffect(.degrees(depth == 0 ? Double(drag) * 0.05 : 0))
                        .zIndex(Double(items.count - depth))
                        .opacity(depth > 3 ? 0 : 1)
                        .accessibilityHidden(depth != 0)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, CYSpacing.xxl)
                .contentShape(Rectangle())
                .onTapGesture { next() }
                .gesture(DragGesture(minimumDistance: 12)
                    .onChanged { value in if !reduceMotion { drag = value.translation.width } }
                    .onEnded { value in
                        if abs(value.translation.width) > 60 { next() }
                        withAnimation(CYMotion.release) { drag = 0 }
                    })
                .accessibilityElement(children: .contain)
                .accessibilityAddTraits(items.count > 1 ? .isButton : [])
                .accessibilityHint(items.count > 1 ? Text("medalDeck.next") : Text(verbatim: ""))
                .accessibilityAction { next() }
                if items.count > 1 { CYMedalDots(count: items.count, current: order.front ?? 0, onDark: false) }
            }
            .accessibilityIdentifier("medalDeck")
            .onAppear { if order.order.count != items.count { order = CYMedalOrder(count: items.count) } }
            .onChange(of: items.map(\.id)) { _, ids in order = CYMedalOrder(count: ids.count) }
        }
    }
    private func next() {
        guard items.count > 1 else { return }
        UIKitHapticsDriver.ensureInstalled()
        HapticsService.shared.play(.medalCycle)
        withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { order.advance() }
    }
}

private struct CYMedalDots: View {
    let count: Int
    let current: Int
    let onDark: Bool
    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            ForEach(0..<count, id: \.self) { index in
                Capsule().fill(index == current ? CYNight.lantern : (onDark ? Color.white.opacity(0.25) : CYColor.textTertiary.opacity(0.4)))
                    .frame(width: index == current ? 14 : 6, height: 6)
            }
        }.accessibilityHidden(true)
    }
}

/// Run-complete medal screen (mini-program `play/components/medal-screen`, owner v13):
/// rays and bloom, stacked hexagon medals (tap or drag to switch), medal name and "n/N",
/// headline, a stats grid that counts up, a new-record card only when there is real data, two pills.
struct CYMedalScreen: View {
    struct Record: Equatable { let label: String; let text: String; let tag: String }
    let items: [CYMedalItem]
    let title: String
    var subtitle: String? = nil
    var stats: [CYStoryStat] = []
    var record: Record? = nil
    /// Text to hand to the share sheet. Nil hides the share pill (capability absent).
    var shareText: String? = nil
    /// mp-nav r3: the MP settle share path (`/pages/topic/index/index?id=`) sent with `shareText`; nil shares the text alone.
    var shareURL: URL? = nil
    var secondaryTitle: LocalizedStringKey = "medalScreen.done"
    var onSecondary: (() -> Void)? = nil
    let onClose: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @State private var order = CYMedalOrder(count: 0)
    @State private var on = false
    @State private var counted: Double = 0
    @State private var drag: CGFloat = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [CYNight.indigo, CYNight.ink0], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            rays
            ScrollView {
                VStack(spacing: CYSpacing.xl) {
                    medalStack.padding(.top, 72)
                    if let front = order.front, items.indices.contains(front) {
                        VStack(spacing: CYSpacing.xs) {
                            Text(verbatim: items[front].name).cyText(.sectionTitle).foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                            HStack(spacing: CYSpacing.xs) {
                                if let sub = items[front].subtitle, !sub.isEmpty { Text(verbatim: sub) }
                                if items.count > 1 { Text(verbatim: "\(front + 1)/\(items.count)").monospacedDigit() }
                            }.cyText(.meta).foregroundStyle(.white.opacity(0.6))
                            if items.count > 1 { CYMedalDots(count: items.count, current: front, onDark: true).padding(.top, CYSpacing.xs) }
                        }.accessibilityElement(children: .combine)
                    }
                    VStack(spacing: CYSpacing.xs) {
                        Text(verbatim: title).cyText(.pageTitle).foregroundStyle(.white).multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        if let subtitle, !subtitle.isEmpty {
                            Text(verbatim: subtitle).cyText(.body).foregroundStyle(.white.opacity(0.72)).multilineTextAlignment(.center)
                        }
                    }.opacity(on ? 1 : 0)
                    if !stats.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: CYSpacing.sm), GridItem(.flexible(), spacing: CYSpacing.sm)], spacing: CYSpacing.sm) {
                            ForEach(stats) { stat in statCell(stat) }
                        }.opacity(on ? 1 : 0)
                    }
                    if let record { recordCard(record).opacity(on ? 1 : 0) }
                    buttons.opacity(on ? 1 : 0).padding(.bottom, CYSpacing.xxl)
                }
                .padding(.horizontal, CYSpacing.xl)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
            Button(action: onClose) {
                Image(systemName: "chevron.left").font(.headline).foregroundStyle(.white)
                    .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                    .background(CYNight.glassFill, in: Circle())
            }
            .accessibilityLabel(Text("medalScreen.back"))
            .accessibilityIdentifier("medalScreen.back")
            .padding(.leading, CYSpacing.lg).padding(.top, CYSpacing.sm)
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("medalScreen")
        .onAppear {
            order = CYMedalOrder(count: items.count)
            if reduceMotion { on = true; counted = 1 }
            else {
                let wait = 0.5 + Double(min(items.count, 4)) * 0.3
                withAnimation(CYMotion.entrance.delay(wait)) { on = true }
            }
        }
        .task {
            // Text does not interpolate, so the count-up steps itself (ease in-out over 1.4 s, 40 ms frames).
            guard !reduceMotion else { counted = 1; return }
            try? await Task.sleep(for: .seconds(0.5 + Double(min(items.count, 4)) * 0.3))
            let start = Date()
            while !Task.isCancelled {
                let t = min(1, Date().timeIntervalSince(start) / 1.4)
                counted = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
                if t >= 1 { break }
                try? await Task.sleep(for: .milliseconds(40))
            }
        }
        .cyHapticEvent(.rewardOrMedal, trigger: on) { _, new in new }
    }

    private var rays: some View {
        ZStack {
            Circle().fill(CYNight.glow(radius: 140)).frame(width: 420, height: 420)
            if !reduceMotion && CYLightBudget.shadersAllowed {
                AngularGradient(colors: [CYNight.lantern.opacity(0.0), CYNight.lantern.opacity(0.16), CYNight.lantern.opacity(0.0),
                                         CYNight.lantern.opacity(0.12), CYNight.lantern.opacity(0.0)], center: .center)
                    .frame(width: 520, height: 520).clipShape(Circle()).blur(radius: 6)
                    .rotationEffect(.degrees(on ? 20 : 0))
            }
        }
        .frame(maxWidth: .infinity).offset(y: -60)
        .allowsHitTesting(false).accessibilityHidden(true)
    }

    private var medalStack: some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let depth = order.depth(of: index)
                CYMedalFace(item: item, side: 168, tone: index)
                    .brightness(depth == 0 ? 0 : -0.15 * Double(min(depth, 3)))
                    .scaleEffect(depth == 0 ? 1 : max(0.66, 1 - 0.14 * CGFloat(depth)), anchor: .top)
                    .offset(x: depth == 0 ? drag : 0, y: depth == 0 ? 0 : -18 * CGFloat(min(depth, 3)))
                    .rotationEffect(.degrees(depth == 0 ? Double(drag) * 0.05 : 0))
                    .opacity(depth > 3 ? 0 : 1)
                    .zIndex(Double(items.count - depth))
            }
        }
        .frame(height: 210)
        .contentShape(Rectangle())
        .onTapGesture { next() }
        .gesture(DragGesture(minimumDistance: 12)
            .onChanged { value in if !reduceMotion { drag = value.translation.width } }
            .onEnded { value in
                if abs(value.translation.width) > 60 { next() }
                withAnimation(CYMotion.release) { drag = 0 }
            })
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: order.front.flatMap { items.indices.contains($0) ? items[$0].name : nil } ?? ""))
        .accessibilityAddTraits(items.count > 1 ? .isButton : [])
        .accessibilityAction { next() }
    }

    private func statCell(_ stat: CYStoryStat) -> some View {
        HStack(spacing: CYSpacing.sm) {
            if let image = stat.systemImage {
                Group {
                    if let art = CYMedalGlyph.image(for: image) {
                        if CYMedalGlyph.isSprite(image) { CYSpriteStill(sheet: art).frame(width: 28, height: 28) }
                        else { art.resizable().scaledToFit().frame(width: 28, height: 28) }
                    } else {
                        Image(systemName: image).font(.title3).foregroundStyle(CYNight.lantern).frame(width: 28)
                    }
                }
                .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(LocalizedStringKey(stat.key)).cyText(.micro).foregroundStyle(.white.opacity(0.6))
                Text(verbatim: CYMedalCountUp.frame(stat.value, progress: counted)).cyText(.dataXL).monospacedDigit()
                    .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md)
        .background(CYNight.glassFill, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(stat.key)) + Text(verbatim: " ") + Text(verbatim: stat.value ?? "—"))
    }

    private func recordCard(_ record: Record) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.xs) {
                MPAsset.BadgeMedal.glTrophy.resizable().scaledToFit().frame(width: 18, height: 18).accessibilityHidden(true)
                Text("medalScreen.newRecord").cyText(.label).foregroundStyle(CYNight.lantern)
            }
            Text(verbatim: record.label).cyText(.meta).foregroundStyle(.white.opacity(0.66))
            Text(verbatim: record.text).cyText(.sectionTitle).foregroundStyle(.white)
            if !record.tag.isEmpty { CYStatusChip(verbatim: record.tag) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(CYSpacing.lg)
        .background(CYNight.ink2, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var shareLabel: some View {
        Label("medalScreen.share", systemImage: "square.and.arrow.up")
            .cyText(.bodyMedium).frame(maxWidth: .infinity, minHeight: 56)
            .foregroundStyle(CYNight.ink0)
            .background(Color.white, in: Capsule())
    }

    private var buttons: some View {
        HStack(spacing: CYSpacing.sm) {
            CYPillButton(secondaryTitle, style: .secondary) { (onSecondary ?? onClose)() }
                .accessibilityIdentifier("medalScreen.secondary")
            if let shareText {
                Group {
                    if let shareURL {
                        ShareLink(item: shareURL, message: Text(verbatim: shareText)) { shareLabel }
                    } else {
                        ShareLink(item: shareText) { shareLabel }
                    }
                }
                .accessibilityIdentifier("medalScreen.share")
            }
        }
    }

    private func next() {
        guard items.count > 1 else { return }
        UIKitHapticsDriver.ensureInstalled()
        HapticsService.shared.play(.medalCycle)
        withAnimation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion)) { order.advance() }
    }
}

/// Count-up frame for stat strings (mini-program medal-screen `frame`): "h:mm:ss" and "m:ss" by seconds,
/// "a/b" counts only the numerator, plain numbers keep their decimals, anything else is shown as is.
enum CYMedalCountUp {
    static func frame(_ raw: String?, progress: Double) -> String {
        guard let raw, !raw.isEmpty else { return "—" }
        let k = max(0, min(1, progress))
        if k >= 1 { return raw }
        let parts = raw.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        if parts.count == 3, let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]), parts[1].count == 2, parts[2].count == 2 {
            let t = Int((Double(h * 3600 + m * 60 + s) * k).rounded())
            return String(format: "%d:%02d:%02d", t / 3600, (t / 60) % 60, t % 60)
        }
        if parts.count == 2, let m = Int(parts[0]), let s = Int(parts[1]), parts[1].count == 2 {
            let t = Int((Double(m * 60 + s) * k).rounded())
            return String(format: "%d:%02d", t / 60, t % 60)
        }
        let fraction = raw.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        if fraction.count == 2, let a = Int(fraction[0]), Int(fraction[1]) != nil {
            return "\(Int((Double(a) * k).rounded()))/\(fraction[1])"
        }
        if let value = Double(raw), raw.allSatisfy({ $0.isNumber || $0 == "." }) {
            let decimals = raw.split(separator: ".").dropFirst().first?.count ?? 0
            return String(format: "%.\(decimals)f", value * k)
        }
        return raw
    }
}
