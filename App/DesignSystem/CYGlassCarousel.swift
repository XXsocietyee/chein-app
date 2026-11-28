import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Glass carousel kit: a centred portrait card, refractive glass slivers for the neighbours, a colour-matched backdrop and a
// scrub handle. Presentation only; the caller owns data, navigation and network. Spec: docs/release/motion-spec-carousel.md.
// Every moving piece is gated on Reduce Motion, every blur/material on Reduce Transparency.

// MARK: - Model

/// One carousel card. `id` must be unique and stable; `seed` drives the generated art and the backdrop hue.
struct CYCarouselSlide: Identifiable, Hashable {
    enum Kind: Hashable { case event, ticket }
    let id: String
    var seed: String
    var title: String
    var date: String?
    var place: String?
    var badge: String?
    var imageURL: URL?
    var kind: Kind = .event
    var dimmed = false
    /// MP default cover when the slide has no https cover (round 4 image parity); nil keeps the generated art.
    var fallback: CYCarouselFallback? = nil
}

/// Shipped MP default covers a carousel slide can fall back to (Hashable stand-in for `Image`).
enum CYCarouselFallback: Hashable {
    /// `/images/index-figma/reco-hero.jpg` (MP index.wxml:105, 编辑精选).
    case recoHero
    /// `/images/route_city_cover.png` (MP index.wxml:151/188, 附近活动 / 即将上线).
    case routeCityCover
    /// `/images/home-route-city-placeholder.jpg` (MP index.wxml:216/253, the stream cards).
    case homeRouteCityPlaceholder
    var image: Image {
        switch self {
        case .recoHero: return MPAsset.BannerCover.recoHero
        case .routeCityCover: return MPAsset.BannerCover.routeCityCover
        case .homeRouteCityPlaceholder: return MPAsset.BannerCover.homeRouteCityPlaceholder
        }
    }
}

// MARK: - State machine

/// Interaction state, local to the carousel. Load phases (loading/empty/failed) are not carousel states: `CYCarouselRail`
/// renders them through `CYPhaseView`.
enum CYCarouselState: Equatable {
    case idle(selected: String)
    case dragging(from: String)
    case settling(to: String)
}

enum CYCarouselEvent: Equatable {
    case dragBegan
    case dragEnded(predicted: String)
    case settled(String)
    case tappedSliver(String)
    /// The list was replaced; `ids` is the new order.
    case itemsChanged(ids: [String])
}

extension CYCarouselState {
    var selected: String {
        switch self { case .idle(let s): return s; case .dragging(let f): return f; case .settling(let t): return t }
    }
    var isIdle: Bool { if case .idle = self { return true } else { return false } }

    /// Pure transition function; anything not listed is ignored.
    func reduce(_ event: CYCarouselEvent) -> CYCarouselState {
        switch (self, event) {
        case (.idle(let s), .dragBegan): return .dragging(from: s)
        case (.dragging(let f), .dragEnded(let p)): return p == f ? .idle(selected: f) : .settling(to: p)
        case (.settling, .settled(let t)), (.idle, .settled(let t)), (.dragging, .settled(let t)): return .idle(selected: t)
        case (.idle, .tappedSliver(let n)): return .settling(to: n)
        case (_, .itemsChanged(let ids)): return .idle(selected: ids.contains(selected) ? selected : (ids.first ?? ""))
        default: return self
        }
    }
}

// MARK: - Layout

/// Geometry shared by the rail, the cards and the skeleton so nothing jumps when content arrives.
struct CYCarouselMetrics: Equatable {
    var width: CGFloat
    var peek: CGFloat { width <= 375 ? 24 : 28 }
    var gutter: CGFloat { CYSpacing.lg }
    var cardWidth: CGFloat { max(160, min(width - 2 * (peek + gutter), width * 0.74, 320)) }
    var cardHeight: CGFloat { cardWidth * 4 / 3 }
    var margin: CGFloat { max(0, (width - cardWidth) / 2) }
    static let handleRow: CGFloat = 24
    var railHeight: CGFloat { cardHeight + CYSpacing.xl + Self.handleRow + CYSpacing.md }
    /// Before the first measurement the rail assumes an iPhone 17 width.
    static let fallbackWidth: CGFloat = 402
}

// MARK: - Carousel

struct CYGlassCarousel: View {
    let slides: [CYCarouselSlide]
    let railLabel: LocalizedStringKey
    let metrics: CYCarouselMetrics
    let onOpen: (String) -> Void

    @State private var selectedID: String?
    @State private var state: CYCarouselState = .idle(selected: "")
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.locale) private var locale

    /// The backdrop follows the interaction state: it holds during a drag and switches when the swipe lands.
    private var backdropID: String { state.selected }

    var body: some View {
        ZStack(alignment: .top) {
            CYCarouselBackdrop(seed: slides.first { $0.id == backdropID }?.seed, reduceTransparency: reduceTransparency, reduceMotion: reduceMotion)
            VStack(spacing: CYSpacing.xl) {
                scroller
                if slides.count > 1 {
                    CYScrubHandle(ids: slides.map(\.id), selectedID: $selectedID, locale: locale)
                        .frame(height: CYCarouselMetrics.handleRow)
                }
            }
            .padding(.top, CYSpacing.md)
        }
        .frame(height: metrics.railHeight)
        .cyHaptic(.selection, trigger: selectedID, where: CYHapticTransition.bothSet)
        .onAppear { if selectedID == nil { selectedID = slides.first?.id; state = .idle(selected: slides.first?.id ?? "") } }
        .onChange(of: slides.map(\.id)) { _, ids in
            state = state.reduce(.itemsChanged(ids: ids))
            if selectedID == nil || !ids.contains(selectedID ?? "") { selectedID = ids.first }
        }
        .onChange(of: selectedID) { _, new in
            guard let new else { return }
            state = state.reduce(.settled(new))
            announce(new)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(railLabel))
    }

    private var scroller: some View {
        CYGlassGroup {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: metrics.gutter) {
                    ForEach(slides) { slide in
                        slideView(slide)
                            .id(slide.id)
                    }
                }
                .scrollTargetLayout()
            }
        }
        .contentMargins(.horizontal, metrics.margin, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .scrollPosition(id: $selectedID)
        .scrollClipDisabled()
        .simultaneousGesture(
            DragGesture(minimumDistance: 6)
                .onChanged { _ in if state.isIdle { state = state.reduce(.dragBegan) } }
                .onEnded { _ in state = state.reduce(.dragEnded(predicted: selectedID ?? state.selected)) }
        )
    }

    private func slideView(_ slide: CYCarouselSlide) -> some View {
        let position = (slides.firstIndex(of: slide) ?? 0) + 1
        let reduced = reduceMotion
        return Button {
            if slide.id == (selectedID ?? state.selected) {
                onOpen(slide.id)
            } else {
                state = state.reduce(.tappedSliver(slide.id))
                withAnimation(reduceMotion ? nil : CYMotion.standard) { selectedID = slide.id }
            }
        } label: {
            CYCarouselCard(slide: slide, size: CGSize(width: metrics.cardWidth, height: metrics.cardHeight))
                // Glass only over neighbours: the focused card keeps its caption crisp (also when scroll phases are not evaluated, e.g. fixtures).
                .overlay { if slide.id != (selectedID ?? state.selected) { CYGlassSliver() } }
                .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                    view.scaleEffect(reduced ? 1 : 1 - abs(phase.value) * 0.08)
                }
        }
        .buttonStyle(QuestifyCardButtonStyle())
        .accessibilityLabel(Text(verbatim: spokenLabel(slide, position: position)))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("carousel.card.\(slide.id)")
    }

    private func spokenLabel(_ slide: CYCarouselSlide, position: Int) -> String {
        let n = slides.count
        let parts = [slide.title, slide.date, slide.place, appLocalized("carousel.position \(position) \(n)", locale: locale)]
        return parts.compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private func announce(_ id: String) {
        #if canImport(UIKit)
        guard let i = slides.firstIndex(where: { $0.id == id }) else { return }
        UIAccessibility.post(notification: .pageScrolled, argument: appLocalized("carousel.position \(i + 1) \(slides.count)", locale: locale))
        #endif
    }
}

// MARK: - Card

/// Portrait card: art (parallax), optional badge, bottom caption over a scrim. Ticket cards cut the stub notches and draw the perforation.
struct CYCarouselCard: View {
    let slide: CYCarouselSlide
    let size: CGSize
    @Environment(\.colorSchemeContrast) private var contrast

    private var notchY: CGFloat { size.height * 0.72 }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CYCarouselArt(seed: slide.seed, imageURL: slide.imageURL, fallback: slide.fallback)
            LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                   .init(color: .black.opacity(contrast == .increased ? 0.92 : 0.78), location: 1)],
                           startPoint: .top, endPoint: .bottom)
            CYCarouselCaption(title: slide.title, date: slide.date, place: slide.place, contrast: contrast)
            if slide.kind == .ticket {
                Path { p in
                    p.move(to: CGPoint(x: 22, y: notchY)); p.addLine(to: CGPoint(x: size.width - 22, y: notchY))
                }
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                .accessibilityHidden(true)
            }
        }
        .overlay(alignment: .topLeading) {
            if let badge = slide.badge, !badge.isEmpty {
                Text(verbatim: badge)
                    .cyText(.meta, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, CYSpacing.sm + 2).padding(.vertical, CYSpacing.xs)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(CYSpacing.md)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(cardShape, style: FillStyle(eoFill: true))
        .overlay { cardShape.stroke(.white.opacity(0.14), lineWidth: 1) }
        .opacity(slide.dimmed ? 0.62 : 1)
        .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
    }

    private var cardShape: AnyShape {
        slide.kind == .ticket
            ? AnyShape(TicketStubShape(notchY: notchY, radius: CYRadius.xl))
            : AnyShape(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
    }
}

/// Art with parallax: moves slower than the card, clipped by the card. A https cover wins over generated art.
struct CYCarouselArt: View {
    let seed: String
    var imageURL: URL?
    var fallback: CYCarouselFallback? = nil
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        let reduced = reduceMotion
        art
            .scaleEffect(1.12)   // headroom so the parallax offset never exposes an edge
            .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view.offset(x: reduced ? 0 : phase.value * 32)
            }
    }
    @ViewBuilder private var art: some View {
        if let imageURL, imageURL.scheme?.lowercased() == "https" {
            AsyncImage(url: imageURL) { phase in
                if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
            }
        } else if let fallback {
            fallback.image.resizable().scaledToFill().accessibilityHidden(true)
        } else {
            CYCoverArt(seed: seed, showsDebugLabel: false).drawingGroup()
        }
    }
    @ViewBuilder private var placeholder: some View {
        if let fallback {
            fallback.image.resizable().scaledToFill().accessibilityHidden(true)
        } else {
            CYCoverArt(seed: seed, showsDebugLabel: false)
        }
    }
}

/// Title, date, place. Slides opposite to the card and fades out by |phase| 0.55.
struct CYCarouselCaption: View {
    let title: String
    var date: String?
    var place: String?
    var contrast: ColorSchemeContrast = .standard
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        let reduced = reduceMotion
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: title).cyText(.sectionTitle).lineLimit(2)
            if let date, !date.isEmpty { Text(verbatim: date).cyText(.meta).monospacedDigit() }
            if let place, !place.isEmpty { Text(verbatim: place).cyText(.meta).opacity(contrast == .increased ? 1 : 0.85).lineLimit(1) }
        }
        .foregroundStyle(.white)
        .padding(CYSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .scrollTransition(.interactive, axis: .horizontal) { view, phase in
            view.offset(x: reduced ? 0 : -phase.value * 18)
                .opacity(reduced ? 1 : max(0, 1 - abs(phase.value) / 0.55))
        }
    }
}

// MARK: - Glass

/// Refractive sliver over a neighbour card: hidden at rest, fades in with |phase|. Glass on iOS 26, material before; solid under
/// Reduce Transparency. Never hit-tested (the card's button handles the tap) and hidden from VoiceOver.
struct CYGlassSliver: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @QuestifyReduceMotion private var reduceMotion
    /// Native r2: no glass sliver. Draws nothing.
    var body: some View {
        EmptyView()
    }
    @ViewBuilder private var sliverFill: some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
        if reduceTransparency {
            shape.fill(Color.black.opacity(0.55))
        } else if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular.tint(.white.opacity(0.06)), in: shape)
        } else {
            shape.fill(.ultraThinMaterial)
                .overlay(shape.fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .leading, endPoint: .trailing)))
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
        }
    }
}

/// One `GlassEffectContainer` for the rail on iOS 26 so adjacent slivers blend while paging; passthrough before.
struct CYGlassGroup<Content: View>: View {
    @ViewBuilder let content: Content
    /// Native r2: no glass container; passthrough.
    var body: some View {
        content
    }
}

// MARK: - Backdrop

/// Gradient from the active card's seed hue, blurred once and flattened. Crossfades on settle (never per scroll frame).
struct CYCarouselBackdrop: View {
    var seed: String?
    var reduceTransparency = false
    var reduceMotion = false

    private var hue: Double? { seed.map { Double(CYCoverArt.stableHash($0) % 360) / 360 } }

    /// Native r2: no tinted, blurred gradient backdrop. Clear.
    var body: some View {
        Color.clear
            .accessibilityHidden(true)
    }

    @ViewBuilder private var layer: some View {
        if reduceTransparency {
            CYColor.bgElevated.overlay(tint(saturation: 0.5, brightness: 0.4).opacity(0.12))
        } else {
            ZStack {
                LinearGradient(colors: [tint(saturation: 0.55, brightness: 0.30), tint(saturation: 0.6, brightness: 0.12, shift: 0.14)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [tint(saturation: 0.6, brightness: 0.7).opacity(0.35), .clear],
                               center: UnitPoint(x: 0.5, y: 0.35), startRadius: 0, endRadius: 320)
            }
            .blur(radius: 40)
            .drawingGroup()
        }
    }

    private func tint(saturation: Double, brightness: Double, shift: Double = 0) -> Color {
        guard let hue else { return CYColor.bgRaised }   // neutral while loading, empty or failed
        return Color(hue: (hue + shift).truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: brightness)
    }
}

// MARK: - Scrub handle

/// 24 pt thumb on a thin track under the card. Drag maps the position to the nearest slide; VoiceOver adjusts it in steps.
struct CYScrubHandle: View {
    let ids: [String]
    @Binding var selectedID: String?
    let locale: Locale
    @Environment(\.colorSchemeContrast) private var contrast
    @QuestifyReduceMotion private var reduceMotion

    private var index: Int { ids.firstIndex { $0 == selectedID } ?? 0 }

    var body: some View {
        GeometryReader { geo in
            let track = geo.size.width * 0.6
            let progress = ids.count > 1 ? CGFloat(index) / CGFloat(ids.count - 1) : 0
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(contrast == .increased ? 0.5 : 0.25)).frame(width: track, height: 2)
                Circle().fill(.white.opacity(0.9)).frame(width: 24, height: 24)
                    .offset(x: progress * track - 12)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                let originX = (geo.size.width - track) / 2
                let fraction = min(max((value.location.x - originX) / max(track, 1), 0), 1)
                let target = ids[Int((fraction * CGFloat(ids.count - 1)).rounded())]
                if target != selectedID { withAnimation(reduceMotion ? nil : CYMotion.standard) { selectedID = target } }
            })
        }
        .frame(minHeight: 44)
        .accessibilityElement()
        .accessibilityLabel(Text("carousel.scrub"))
        .accessibilityValue(Text(verbatim: appLocalized("carousel.position \(index + 1) \(ids.count)", locale: locale)))
        .accessibilityAdjustableAction { direction in
            let step = direction == .increment ? 1 : -1
            let next = min(max(index + step, 0), ids.count - 1)
            selectedID = ids[next]
        }
        .accessibilityIdentifier("carousel.scrub")
    }
}

// MARK: - Rail (load phases + layout)

/// Rail wrapper: measures its width, keeps one frame for skeleton / empty / failed / content so nothing jumps, and falls back
/// to the vertical list at accessibility Dynamic Type sizes.
struct CYCarouselRail<Fallback: View>: View {
    let phase: CYPhase<[CYCarouselSlide], Error>
    let railLabel: LocalizedStringKey
    var emptyMessage: LocalizedStringKey = "carousel.empty"
    let onOpen: (String) -> Void
    @ViewBuilder var accessibilityFallback: () -> Fallback

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var width: CGFloat = 0

    private var metrics: CYCarouselMetrics { CYCarouselMetrics(width: width > 0 ? width : CYCarouselMetrics.fallbackWidth) }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            accessibilityFallback()
        } else {
            Group {
                if phase.isLoading {
                    CYCarouselSkeleton(metrics: metrics)
                } else {
                    CYPhaseView(phase: phase, skeletonRows: 1, loadingLabel: "carousel.loading", emptyMessage: emptyMessage,
                                failureMessage: "carousel.error") { slides in
                        CYGlassCarousel(slides: slides, railLabel: railLabel, metrics: metrics, onOpen: onOpen)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: metrics.railHeight)
            .background(GeometryReader { proxy in
                Color.clear
                    .onAppear { width = proxy.size.width }
                    .onChange(of: proxy.size.width) { _, new in width = new }
            })
        }
    }
}

/// Loading silhouette: one card at the real card size on the neutral backdrop, so content arrives without a layout jump.
struct CYCarouselSkeleton: View {
    let metrics: CYCarouselMetrics
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack(alignment: .top) {
            CYCarouselBackdrop(seed: nil, reduceTransparency: reduceTransparency, reduceMotion: true)
            RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
                .fill(CYColor.bgRaised)
                .overlay { CYSkeleton().padding(CYSpacing.lg).frame(maxHeight: .infinity, alignment: .bottom) }
                .frame(width: metrics.cardWidth, height: metrics.cardHeight)
                .padding(.top, CYSpacing.md)
        }
        .frame(height: metrics.railHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("carousel.loading"))
    }
}
