import SwiftUI

// Collection album kit (HERO: collection album). Spec: docs/release/motion-spec-album.md.
// Stamp album, badge wall and object cards share these pieces: page-turn pager, flip card, foil sheen,
// locked silhouette, "new" pulse, count-up progress ring and the unlock moment. Every moving piece is
// gated on `@QuestifyReduceMotion`; the fallback is an instant change or a short cross-fade.

// MARK: - Tokens

enum CYAlbumMotion {
    /// Page turn: driven by the scroll, no duration. Max hinge angle in degrees.
    static let pageTurnAngle: Double = 42
    /// Flip card: one spring, lands in about 0.6 s with a small overshoot.
    static let flip = Animation.spring(response: 0.55, dampingFraction: 0.78)
    /// Foil sheen sweep: 1.1 s ease-in-out after a 0.25 s hold.
    static let sheen = Animation.easeInOut(duration: 1.1).delay(0.25)
    /// Progress ring fill and count-up: 0.9 s ease-out.
    static let countUp = Animation.easeOut(duration: 0.9)
    /// "New" pulse: three breaths, 1.3 s each, then rest.
    static let pulse = Animation.easeOut(duration: 1.3).repeatCount(3, autoreverses: false)
    /// Foil colours (the only gold in the app; medals and rings share it).
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.40)
    static let amber = Color(red: 0.95, green: 0.62, blue: 0.20)
}

/// Copy shared by the album surfaces. Unknown values are a dash, never a fake zero.
enum CYAlbumCopy {
    static let unknownMark = "—"
}

// MARK: - Recency and "seen" memory

/// "New" means collected within the last seven days by the server date string ("yyyy-MM-dd HH:mm[:ss]" or an ISO prefix).
/// Unknown or unparsable dates are never new: the pulse is a fact, not a nudge.
enum CYAlbumRecency {
    static let window: TimeInterval = 7 * 86_400
    static func date(_ raw: String?) -> Date? {
        guard let raw, raw.count >= 10 else { return nil }
        let parts = raw.prefix(10).split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day
        return Calendar(identifier: .gregorian).date(from: components)
    }
    static func isNew(_ raw: String?, now: Date = .now) -> Bool {
        guard let date = date(raw) else { return false }
        let age = now.timeIntervalSince(date)
        return age >= -86_400 && age <= window
    }
}

/// Remembers which new collectibles the player already opened, so the pulse and the unlock moment play once per item.
/// Stored locally (newline-joined ids, capped), never sent anywhere.
@propertyWrapper struct CYAlbumSeen: DynamicProperty {
    @AppStorage("cy.album.seen") private var raw = ""
    init() {}
    var wrappedValue: Set<String> { Set(raw.split(separator: "\n").map(String.init)) }
    var projectedValue: CYAlbumSeen { self }
    func contains(_ id: String) -> Bool { wrappedValue.contains(id) }
    func mark(_ id: String) {
        guard !id.isEmpty else { return }
        var set = wrappedValue
        guard set.insert(id).inserted else { return }
        raw = Array(set.sorted().suffix(500)).joined(separator: "\n")
    }
}

// MARK: - Progress ring with count-up

/// Animatable number: SwiftUI interpolates `animatableData`, so the label counts up with the ring.
private struct CYCountUpLabel: View, Animatable {
    @Environment(\.cyPalette) private var palette
    var number: Double
    var font: Font
    var animatableData: Double {
        get { number }
        set { number = newValue }
    }
    var body: some View {
        Text(verbatim: String(Int(number.rounded())))
            .font(font).monospacedDigit()
            .foregroundStyle(palette.textPrimary)
            .contentTransition(.identity)
    }
}

/// Collection progress: gold ring fills and the count counts up together (0.9 s). `total` nil or 0 draws only the dim track and a dash,
/// never a fake zero percent. Reduce Motion: final state at once. Decorative for VoiceOver; pass the sentence as `accessibilityLabel`.
struct CYAlbumProgressRing: View {
    @Environment(\.cyPalette) private var palette
    var value: Int
    var total: Int?
    var size: CGFloat = 92
    var lineWidth: CGFloat = 9
    var accessibilityLabel: Text
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var shown = false

    private var fraction: Double {
        guard let total, total > 0 else { return 0 }
        return min(1, Double(max(0, value)) / Double(total))
    }
    private var known: Bool { (total ?? 0) > 0 }
    /// Accessibility sizes: the ring grows 1.4x (capped at 140 pt) so the count tracks the text around it (a11y-dt r3).
    private var ringSize: CGFloat { dynamicTypeSize.isAccessibilitySize ? min(size * 1.4, 140) : size }

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth) // track visible on grouped backgrounds (a11y-dt r3)
            Circle().trim(from: 0, to: shown ? fraction : 0)
                .stroke(AngularGradient(colors: [CYAlbumMotion.gold, CYAlbumMotion.amber, CYAlbumMotion.gold], center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: CYAlbumMotion.gold.opacity(shown && known ? 0.35 : 0), radius: 6)
            VStack(spacing: 0) {
                if known {
                    CYCountUpLabel(number: shown ? Double(value) : 0, font: .system(size: ringSize * 0.30, weight: .bold, design: .rounded))
                    Text(verbatim: "/ \(total ?? 0)")
                        .font(.system(size: ringSize * 0.14, weight: .semibold, design: .rounded)).monospacedDigit()
                        .foregroundStyle(palette.textTertiary)
                } else {
                    Text(verbatim: CYAlbumCopy.unknownMark)
                        .font(.system(size: ringSize * 0.30, weight: .bold, design: .rounded))
                        .foregroundStyle(palette.textTertiary)
                }
            }
            .minimumScaleFactor(0.6)
        }
        .frame(width: ringSize, height: ringSize)
        .onAppear { reveal() }
        .onChange(of: value) { _, _ in reveal() }
        .onChange(of: total) { _, _ in reveal() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func reveal() {
        if reduceMotion { shown = true; return }
        shown = false
        withAnimation(CYAlbumMotion.countUp) { shown = true }
    }
}

// MARK: - Foil sheen

extension View {
    /// Metallic highlight that sweeps once across an unlocked collectible on appear and whenever `trigger` changes.
    /// Reduce Motion: a static soft highlight in the top-left corner. `active` false (locked) draws nothing.
    func cyFoilSheen(active: Bool = true, trigger: Int = 0, cornerRadius: CGFloat = CYRadius.lg, foilStrength: Double = 1) -> some View {
        modifier(CYAlbumFoilSheen(active: active, trigger: trigger, cornerRadius: cornerRadius, foilStrength: foilStrength))
    }
}

private struct CYAlbumFoilSheen: ViewModifier {
    let active: Bool
    let trigger: Int
    let cornerRadius: CGFloat
    var foilStrength: Double = 1
    @QuestifyReduceMotion private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        // Wave 3: the gyro-driven CYFoil is the material (static highlight under Reduce Motion / Low Power);
        // the one-shot sweep below stays as the "it just arrived" beat.
        content
            .cyFoil(cornerRadius: cornerRadius, active: active, strength: foilStrength)
            .overlay {
                if active {
                    GeometryReader { proxy in
                        let width = proxy.size.width
                        if !reduceMotion {
                            Rectangle()
                                .fill(LinearGradient(colors: [.clear, .white.opacity(0.10), .white.opacity(0.48), .white.opacity(0.10), .clear],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(40, width * 0.55), height: proxy.size.height * 2.2)
                                .rotationEffect(.degrees(22))
                                .offset(x: phase * width * 1.3 + width * 0.2, y: -proxy.size.height * 0.6)
                        }
                    }
                    .blendMode(.screen)
                    .clipShape(CYFoilClip(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
            .onAppear { sweep() }
            .onChange(of: trigger) { _, _ in sweep() }
    }

    private func sweep() {
        guard active, !reduceMotion else { return }
        phase = -1
        withAnimation(CYAlbumMotion.sheen) { phase = 1 }
    }
}

// MARK: - Locked silhouette

extension View {
    /// Locked collectible: desaturated, dimmed, dashed rim and (optionally) a small lock. Colour is never the only signal,
    /// so callers still announce the locked state in text. Decorative for VoiceOver.
    func cyLockedSilhouette(_ locked: Bool, cornerRadius: CGFloat = CYRadius.lg, showsLock: Bool = true) -> some View {
        modifier(CYLockedSilhouette(locked: locked, cornerRadius: cornerRadius, showsLock: showsLock))
    }
}

private struct CYLockedSilhouette: ViewModifier {
    @Environment(\.cyPalette) private var palette
    let locked: Bool
    let cornerRadius: CGFloat
    let showsLock: Bool
    func body(content: Content) -> some View {
        content
            .saturation(locked ? 0 : 1)
            .contrast(locked ? 0.85 : 1)
            .opacity(locked ? 0.78 : 1)   // 0.78 keeps secondary text >= 4.5:1 on light surfaces too
            .overlay {
                if locked {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(palette.borderStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                        .accessibilityHidden(true)
                }
            }
            .overlay(alignment: .topTrailing) {
                if locked && showsLock {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                        .padding(7)
                        .background(palette.bgRaised, in: Circle())
                        .padding(CYSpacing.sm)
                        .accessibilityHidden(true)
                }
            }
    }
}

// MARK: - "New" pulse

/// "NEW" capsule with a gold halo that breathes three times, then rests. Static capsule under Reduce Motion.
/// Pass the localized word; the capsule is read as part of its tile.
struct CYNewPulseBadge: View {
    var text: Text
    @QuestifyReduceMotion private var reduceMotion
    @State private var breathe = false

    var body: some View {
        text
            .cyText(.micro, weight: .heavy)
            .textCase(.uppercase)
            .foregroundStyle(Color.black.opacity(0.85))
            .padding(.horizontal, CYSpacing.sm).padding(.vertical, 3)
            .background(CYAlbumMotion.gold, in: Capsule())
            .background {
                if !reduceMotion {
                    Capsule()
                        .stroke(CYAlbumMotion.gold.opacity(breathe ? 0 : 0.85), lineWidth: 2)
                        .scaleEffect(x: breathe ? 1.7 : 1.0, y: breathe ? 2.2 : 1.0)
                        .accessibilityHidden(true)
                }
            }
            .onAppear {
                guard !reduceMotion, !breathe else { return }
                withAnimation(CYAlbumMotion.pulse) { breathe = true }
            }
    }
}

extension View {
    /// Pins a `CYNewPulseBadge` to the top-leading corner when `isNew`.
    func cyNewPulse(_ isNew: Bool, text: Text) -> some View {
        overlay(alignment: .topLeading) {
            if isNew { CYNewPulseBadge(text: text).padding(CYSpacing.sm) }
        }
    }
}

// MARK: - Flip card

/// Per-face geometry: SwiftUI interpolates `angle`, so the face swap happens exactly at 90° and the back face
/// is pre-rotated to read correctly. `rotates` false (Reduce Motion) cross-fades instead.
private struct CYFlipFace: ViewModifier, Animatable {
    var angle: Double
    let isBack: Bool
    let rotates: Bool
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }
    func body(content: Content) -> some View {
        let showing = isBack ? angle >= 90 : angle < 90
        let fade = isBack ? angle / 180 : 1 - angle / 180
        content
            .opacity(rotates ? (showing ? 1 : 0) : fade)
            .rotation3DEffect(.degrees(rotates ? (isBack ? angle - 180 : angle) : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .accessibilityHidden(isBack ? angle < 90 : angle >= 90)
    }
}

/// Tap to flip. Front turns away around the Y axis with perspective and the back (details) lands in its place.
/// One spring (0.55 s), haptic `.selection` per flip. Reduce Motion: 0.18 s cross-fade, no rotation.
/// VoiceOver reads the visible face's contents and gets a named "flip" action.
struct CYFlipCard<Front: View, Back: View>: View {
    @Binding var flipped: Bool
    var flipActionTitle: Text
    @ViewBuilder var front: () -> Front
    @ViewBuilder var back: () -> Back
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        let angle: Double = flipped ? 180 : 0
        ZStack {
            front().modifier(CYFlipFace(angle: angle, isBack: false, rotates: !reduceMotion))
            back().modifier(CYFlipFace(angle: angle, isBack: true, rotates: !reduceMotion))
        }
        .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .onTapGesture { toggle() }
        .cyHaptic(.selection, trigger: flipped)
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: flipActionTitle) { toggle() }
    }

    private func toggle() {
        withAnimation(reduceMotion ? CYMotion.reduced : CYAlbumMotion.flip) { flipped.toggle() }
    }
}

// MARK: - Album pager (page turn)

/// Horizontal album: one collectible per page, view-aligned paging. Each page turns on its spine as it leaves or arrives
/// (`scrollTransition` + `rotation3DEffect`, max 42°, slight darkening like the underside of a turned page).
/// Reduce Motion: plain paging. Haptic `.selection` per page. Dots announce "page n of m" and are adjustable.
struct CYAlbumPager<Item: Identifiable, Page: View>: View {
    @Environment(\.cyPalette) private var palette
    let items: [Item]
    var height: CGFloat = 340
    var pageLabel: (Int, Int) -> Text
    @ViewBuilder var page: (Item) -> Page
    @QuestifyReduceMotion private var reduceMotion
    @State private var current: Item.ID?

    private var index: Int { items.firstIndex { $0.id == current } ?? 0 }

    var body: some View {
        VStack(spacing: CYSpacing.md) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: CYSpacing.md) {
                    ForEach(items) { item in
                        page(item)
                            .containerRelativeFrame(.horizontal)
                            .modifier(CYPageTurn(reduceMotion: reduceMotion))
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .frame(height: height)
            if items.count > 1 { dots }
        }
        .cyHaptic(.selection, trigger: current)
        .onAppear { if current == nil { current = items.first?.id } }
    }

    private var dots: some View {
        HStack(spacing: CYSpacing.sm) {
            if items.count <= 12 {
                ForEach(items.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == index ? palette.textPrimary : palette.bgRaised)
                        .frame(width: i == index ? 18 : 6, height: 6)
                }
            } else {
                Text(verbatim: "\(index + 1) / \(items.count)")
                    .cyText(.caption).monospacedDigit().foregroundStyle(palette.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
        .cyAnimation(CYMotion.standard, value: current)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(pageLabel(index + 1, items.count))
        .accessibilityAdjustableAction { direction in
            let next: Int
            switch direction {
            case .increment: next = min(items.count - 1, index + 1)
            case .decrement: next = max(0, index - 1)
            @unknown default: return
            }
            guard items.indices.contains(next) else { return }
            withAnimation(reduceMotion ? nil : CYMotion.standard) { current = items[next].id }
        }
    }
}

private struct CYPageTurn: ViewModifier {
    let reduceMotion: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view
                    .rotation3DEffect(.degrees(phase.value * CYAlbumMotion.pageTurnAngle), axis: (x: 0, y: 1, z: 0),
                                      anchor: phase.value < 0 ? .trailing : .leading, perspective: 0.7)
                    .scaleEffect(1 - abs(phase.value) * 0.06)
                    .brightness(phase.value < 0 ? phase.value * 0.22 : 0)
                    .opacity(1 - abs(phase.value) * 0.25)
            }
        }
    }
}

// MARK: - Unlock moment

extension View {
    /// Unlock moment on an existing view: light confetti from the view's centre, one ring pulse and the success haptic.
    /// Fires when `trigger` changes. Reduce Motion: haptic only (confetti and ring draw nothing).
    func cyUnlockCelebration(trigger: Int) -> some View { modifier(CYUnlockCelebration(trigger: trigger)) }
}

private struct CYUnlockCelebration: ViewModifier {
    let trigger: Int
    func body(content: Content) -> some View {
        content
            .background {
                CYRingPulse(trigger: trigger, idle: false).padding(-CYSpacing.lg).allowsHitTesting(false)
            }
            .overlay {
                CYConfettiBurst(trigger: trigger, pieces: 26)
                    .frame(width: 360, height: 460)
                    .allowsHitTesting(false)
            }
            .cyHaptic(.success, trigger: trigger)
    }
}

// MARK: - Album card chrome

private struct CYAlbumCardModifier: ViewModifier {
    @Environment(\.cyPalette) private var palette
    let padding: CGFloat
    /// Native r2: the shared card surface (system grouped secondary background, one card radius, no stroke or shadow).
    func body(content: Content) -> some View {
        content
            .cyCardSurface(padding: padding)
    }
}

extension View {
    /// Card surface shared by album pages and collection tiles: elevated continuous-corner card with no outer border.
    func cyAlbumCard(padding: CGFloat = CYSpacing.md) -> some View {
        modifier(CYAlbumCardModifier(padding: padding))
    }
}

#Preview("Album kit · player dark") {
    struct Demo: Identifiable { let id: Int }
    struct Host: View {
        @State private var flipped = false
        @State private var burst = 0
        var body: some View {
            ScrollView {
                VStack(spacing: CYSpacing.xl) {
                    CYAlbumProgressRing(value: 7, total: 12, accessibilityLabel: Text(verbatim: "7 of 12 collected"))
                    CYAlbumPager(items: [Demo(id: 1), Demo(id: 2), Demo(id: 3)], height: 240, pageLabel: { Text(verbatim: "Page \($0) of \($1)") }) { item in
                        CYCoverArt(seed: "page-\(item.id)", showsDebugLabel: false, cornerRadius: CYRadius.lg)
                            .cyFoilSheen()
                            .padding(.horizontal, CYSpacing.pageHorizontal)
                    }
                    CYFlipCard(flipped: $flipped, flipActionTitle: Text(verbatim: "Flip")) {
                        CYCoverArt(seed: "front", showsDebugLabel: false, cornerRadius: CYRadius.lg).frame(height: 200)
                    } back: {
                        Text(verbatim: "Details").frame(maxWidth: .infinity).frame(height: 200).cyAlbumCard()
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    HStack {
                        CYCoverArt(seed: "locked", showsDebugLabel: false, cornerRadius: CYRadius.lg).frame(height: 120).cyLockedSilhouette(true)
                        CYCoverArt(seed: "new", showsDebugLabel: false, cornerRadius: CYRadius.lg).frame(height: 120)
                            .cyFoilSheen().cyNewPulse(true, text: Text(verbatim: "New"))
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    CYBadgeMedal(seed: "unlock", size: 120).cyUnlockCelebration(trigger: burst).onTapGesture { burst += 1 }
                }
                .padding(.vertical, CYSpacing.xl)
            }
            .cyDomainPageBackground()
            .themeDomain(.player)
            .preferredColorScheme(.dark)
        }
    }
    return Host()
}
