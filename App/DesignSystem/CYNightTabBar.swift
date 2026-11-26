import SwiftUI

/// Sliding selection pill for the root tab bar ("胶囊先伸展，再落位"): it stretches toward the destination for 120 ms,
/// springs into the new slot, then relaxes. Neutral selection (ink at 12%), per the design hand-off r1 PL-01. It sits over the native `TabView` bar as a
/// non-interactive, accessibility-hidden indicator, so the native tab buttons keep their taps, identifiers and VoiceOver.
/// Reduce Motion: the pill crossfades between slots. Spec: design-wave3 §4.5.
/// Native r2 (2026-11-26): no longer mounted by the app shell (the system tab bar draws selection); design fixtures only.
struct CYNightTabBar: View {
    let selection: RootTab
    var tabs: [RootTab] = RootTab.playerTabs
    var isHidden: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.cyTabBarHidden) private var isTabBarHidden
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var rm
    @Namespace private var pillNS
    @State private var landed: RootTab?
    @State private var stretch: CGFloat = 1
    @State private var anchor: UnitPoint = .leading
    @State private var task: Task<Void, Never>?

    private let barHeight: CGFloat = 44
    private let pillHeight: CGFloat = 34

    init(selection: RootTab, tabs: [RootTab] = RootTab.playerTabs, isHidden: Bool = false) {
        self.selection = selection
        self.tabs = tabs
        self.isHidden = isHidden
        // While `landed` is nil, the capsule follows `selection` and the first change snaps. Seed it so every change stretches, then springs.
        _landed = State(initialValue: .some(selection))
    }

    var body: some View {
        // The outer reader keeps the real bottom safe area; the inner one ignores it to span the screen. Reading the inset from
        // the ignoring reader gives 0 and drops the pill below the floating bar (outside it, under the icons).
        if !isHidden {
            if !isTabBarHidden {
                GeometryReader { outer in
                    let bottomInset = outer.safeAreaInsets.bottom
                    pillLayer(bottomInset: bottomInset).ignoresSafeArea()
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .onChange(of: selection) { old, new in
                    guard !rm else { landed = new; return }
                    let right = (tabs.firstIndex(of: new) ?? 0) >= (tabs.firstIndex(of: old) ?? 0)
                    task?.cancel()
                    task = Task { @MainActor in
                        anchor = right ? .leading : .trailing
                        withAnimation(.easeOut(duration: CYMotion.Duration.instant)) { stretch = 1.35 }
                        try? await Task.sleep(for: .milliseconds(120))
                        if Task.isCancelled { return }
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { landed = new }
                        try? await Task.sleep(for: .milliseconds(70))
                        if Task.isCancelled { return }
                        anchor = right ? .trailing : .leading
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.62)) { stretch = 1 }
                    }
                }
            }
        }
    }

    private func pillLayer(bottomInset: CGFloat) -> some View {
        GeometryReader { g in
            if sizeClass == .compact, !tabs.isEmpty {
                // iOS 26+ floats the bar with a side margin; the items share the width inside it, so the pill must too.
                let inset: CGFloat = { if #available(iOS 26, *) { return 29 } else { return 0 } }()
                let slot = (g.size.width - inset * 2) / CGFloat(tabs.count)
                let y = g.size.height - bottomInset - barHeight / 2
                let current = landed ?? selection
                // Slots share the same inset width as the floating bar. One matchedGeometry capsule
                // springs from the old slot to the new one; the side margin stays put.
                HStack(spacing: 0) {
                    ForEach(tabs, id: \.self) { tab in
                        ZStack {
                            if rm {
                                pill(width: slot - 20).opacity(tab == selection ? 1 : 0)
                            } else if tab == current {
                                pill(width: slot - 20)
                                    .scaleEffect(x: stretch, anchor: anchor)
                                    .matchedGeometryEffect(id: "tab", in: pillNS)
                            }
                        }
                        .frame(width: slot, height: pillHeight)
                    }
                }
                .padding(.horizontal, inset)
                .frame(width: g.size.width)
                .position(x: g.size.width / 2, y: y)
                .animation(rm ? CYMotion.reduced : nil, value: selection)
            }
        }
    }

    /// PL-01 (design hand-off r1): neutral selection. The capsule is ink at 12% behind a full-opacity Semibold icon and
    /// label, so the selected tab never renders as a blank white pill (white glyph on a white fill) and no violet glow.
    private func pill(width: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(palette.tabSelectedCapsule)
            .frame(width: max(width, 40), height: pillHeight)
    }
}

@MainActor @Observable
final class CYTabBarVisibility {
    private var hiddenTokens: Set<UUID> = []

    var isHidden: Bool { !hiddenTokens.isEmpty }

    func hide(_ token: UUID) {
        hiddenTokens.insert(token)
    }

    func show(_ token: UUID) {
        hiddenTokens.remove(token)
    }
}

private struct CYTabBarVisibilityKey: EnvironmentKey {
    static let defaultValue: CYTabBarVisibility? = nil
}

extension EnvironmentValues {
    var cyTabBarVisibility: CYTabBarVisibility? {
        get { self[CYTabBarVisibilityKey.self] }
        set { self[CYTabBarVisibilityKey.self] = newValue }
    }
}

extension View {
    /// E2E-20261113b N3: on iOS 26 the floating tab bar does not shrink the tab content's safe area, so bottom rows and
    /// pinned actions (play panel stations, the activity "More info" row, club entries) ended up under it. Each tab root
    /// reserves the bar's height; the bar itself is outside this padding.
    func cyFloatingTabBarClearance() -> some View {
        modifier(CYFloatingTabBarClearance())
    }
}

private struct CYFloatingTabBarClearance: ViewModifier {
    @Environment(\.cyTabBarVisibility) private var visibility
    @Environment(\.cyTabBarHidden) private var isTabBarHidden
    func body(content: Content) -> some View {
        let baseClearance = isTabBarHidden ? 0 : CYFloatingTabBarClearanceKey.height
        let clearance = (visibility?.isHidden == true) ? 0 : baseClearance
        if #available(iOS 26, *) {
            // Native r2: the system scroll edge effect only; no painted fade under the bar.
            content.safeAreaPadding(.bottom, clearance).environment(\.cyTabBarClearance, clearance)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else { content }
    }
}

/// Height a self-sizing bottom panel (the map scaffold) reserves for the floating tab bar inside a tab. Zero outside tabs.
struct CYFloatingTabBarClearanceKey: EnvironmentKey {
    static let height: CGFloat = 72
    /// The part of the clearance above the bar's own top edge, left transparent so the fade ends at the bar.
    static let barOverlap: CGFloat = 12
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var cyTabBarClearance: CGFloat {
        get { self[CYFloatingTabBarClearanceKey.self] }
        set { self[CYFloatingTabBarClearanceKey.self] = newValue }
    }
}
