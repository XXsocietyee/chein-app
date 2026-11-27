import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// P21 (design-principles, owner 11-27): a running roam / city run / game session lives in a compact bar just above the
// tab bar on every tab (title, one live value, one control) and expands into the full-screen HUD with a zoom morph;
// swiping down collapses it. Native pattern (Apple Music now playing), not MP chrome (OWNER RULE 2).
// State: the same values the Live Activity shows (`QuestLiveActivityCenter` is the only run owner and feeds this store),
// so the bar, the HUD, the island and the Lock Screen read one object (P5). Controls call the Live Activity buttons'
// pause / resume (`QuestLiveActivityCenter.toggleRun`), which are the in-app pause / resume calls.
//
// Motion spec (receipt): tap the bar → the bar zooms into the full-screen HUD (`matchedTransitionSource` +
// `.navigationTransition(.zoom)`, the bar keeps identity as the source) → tab bar and the tab's title stay put under the
// cover → system zoom timing (no custom curve) → swipe down / 收起 zooms back into the bar; Reduce Motion: crossfade.

/// What is running now, as last published to the Live Activity. Runs only (roam, play); story audio has its own player.
@MainActor @Observable final class ActiveSessionStore {
    static let shared = ActiveSessionStore()

    struct Entry: Equatable {
        let kind: QuestLiveActivityKind
        let key: String
        var title: String?
        var content: QuestLiveActivityContent
    }

    private(set) var entries: [QuestLiveActivityKind: Entry] = [:]
    /// The run's own full-screen screen is up (roam live screen, city run, free explore map); the bar then hides.
    private(set) var roamScreenVisible = false
    private(set) var playScreenVisible = false

    private init() {}

    /// A play session wins over a paused walk: it is the one the player is in.
    var current: Entry? {
        if let play = entries[.play], play.content.status != .finished { return play }
        if let roam = entries[.roam], roam.content.status != .finished { return roam }
        return nil
    }

    /// The bar for the current run, unless that run's own screen is on screen.
    var visibleEntry: Entry? {
        guard let entry = current else { return nil }
        if entry.kind == .roam && roamScreenVisible { return nil }
        if entry.kind == .play && playScreenVisible { return nil }
        return entry
    }

    func update(_ descriptor: QuestLiveActivityDescriptor, content: QuestLiveActivityContent) {
        guard descriptor.kind == .roam || descriptor.kind == .play else { return }
        let entry = Entry(kind: descriptor.kind, key: descriptor.key, title: descriptor.title, content: content)
        if entries[descriptor.kind] != entry { entries[descriptor.kind] = entry }
    }

    func end(kind: QuestLiveActivityKind, key: String?) {
        guard let entry = entries[kind] else { return }
        if let key, key != entry.key { return }
        entries[kind] = nil
    }

    func setRoamScreenVisible(_ visible: Bool) {
        if roamScreenVisible != visible { roamScreenVisible = visible }
    }

    func setPlayScreenVisible(_ visible: Bool) {
        if playScreenVisible != visible { playScreenVisible = visible }
    }
}

/// The one live value: the running clock (`Text(timerInterval:)`, ticks by itself, P2), else the frozen elapsed time
/// with 已暂停, else the distance to the next stop.
struct ActiveSessionLiveValue: View {
    let entry: ActiveSessionStore.Entry

    var body: some View {
        Group {
            if let interval = entry.content.timerInterval {
                Text(timerInterval: interval, countsDown: false)
            } else if entry.content.status == .paused {
                Text("playx.phase.paused") + Text(verbatim: " · " + QuestLiveActivityText.elapsed(entry.content.elapsedSeconds))
            } else if let meters = entry.content.nextDistanceMeters {
                Text(verbatim: QuestLiveActivityText.distance(meters))
            } else {
                Text(verbatim: QuestLiveActivityText.elapsed(entry.content.elapsedSeconds))
            }
        }
        .monospacedDigit()
    }
}

enum ActiveSessionCopy {
    static func titleKey(_ kind: QuestLiveActivityKind) -> LocalizedStringKey {
        kind == .roam ? "activeSession.roam.title" : "activeSession.play.title"
    }

    static func symbol(_ kind: QuestLiveActivityKind) -> String {
        kind == .roam ? "figure.walk" : "flag.checkered"
    }
}

/// The compact bar: icon tile, title + live value (tap = expand), one control (pause / resume).
struct ActiveSessionMiniBar: View {
    let entry: ActiveSessionStore.Entry
    let onExpand: () -> Void

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            Button(action: onExpand) {
                HStack(spacing: CYSpacing.md) {
                    Image(systemName: ActiveSessionCopy.symbol(entry.kind))
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        .frame(width: 36, height: 36)
                        .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        title
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        ActiveSessionLiveValue(entry: entry)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityElement(children: .combine)
            .accessibilityHint(Text("activeSession.expand.hint"))
            .accessibilityIdentifier("activeSession.miniBar.expand")
            ActiveSessionRunToggle(entry: entry, prominent: false)
        }
        .padding(.leading, CYSpacing.md)
        .padding(.trailing, CYSpacing.xs)
        .padding(.vertical, CYSpacing.xs)
        .frame(minHeight: 56)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("activeSession.miniBar")
    }

    @ViewBuilder private var title: some View {
        if let name = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            Text(verbatim: name)
        } else {
            Text(ActiveSessionCopy.titleKey(entry.kind))
        }
    }
}

/// Pause / resume: the same call as the Live Activity button. Hidden when the run cannot be toggled from outside.
struct ActiveSessionRunToggle: View {
    let entry: ActiveSessionStore.Entry
    let prominent: Bool

    var body: some View {
        if let pauses = entry.content.runToggle(kind: entry.kind) {
            if prominent {
                Button { toggle(pauses) } label: { label(pauses).frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("activeSession.hud.toggle")
            } else {
                Button { toggle(pauses) } label: { label(pauses).labelStyle(.iconOnly).font(.title3) }
                    .buttonStyle(.borderless)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("activeSession.miniBar.toggle")
            }
        }
    }

    private func label(_ pauses: Bool) -> Label<Text, Image> {
        Label(LocalizedStringKey(pauses ? "playx.run.pause" : "playx.run.resume"), systemImage: pauses ? "pause.fill" : "play.fill")
    }

    private func toggle(_ pauses: Bool) {
        _ = QuestLiveActivityCenter.shared.toggleRun(kind: entry.kind, pause: pauses)
    }
}

/// The expanded HUD for a game / city run whose own screen is elsewhere in the stack: the play HUD's 下一站 card,
/// the clock as the hero value (P1), one primary (pause / resume, P3). A roam expands into its own live screen instead.
struct ActiveSessionPlayHUD: View {
    let entry: ActiveSessionStore.Entry
    @Environment(\.locale) private var locale

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.xl) {
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text(ActiveSessionCopy.titleKey(entry.kind))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let name = entry.title?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                        Text(verbatim: name)
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                    Text("roam.live.stat.time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ActiveSessionLiveValue(entry: entry)
                        .font(.largeTitle.weight(.bold))
                        .accessibilityIdentifier("activeSession.hud.value")
                }
                .accessibilityElement(children: .combine)
                if let stop = nextStop {
                    PlayHUDNextStopCard(stop: stop)
                }
                ActiveSessionRunToggle(entry: entry, prominent: true)
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("activeSession.hud")
    }

    private var nextStop: PlayHUDNextStop? {
        guard let name = entry.content.stopName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        let chinese = locale.language.languageCode?.identifier == "zh"
        let distance = entry.content.nextDistanceMeters.map { PlayHUDGeometry.distanceText(Double($0), chinese: chinese) }
        var clues: (done: Int, total: Int)?
        if let done = entry.content.cluesSolved, let total = entry.content.cluesTotal, total > 0 { clues = (done, total) }
        return PlayHUDNextStop(name: name, distanceText: distance, arrowDegrees: nil, elapsedText: nil, clues: clues)
    }
}

/// Puts the bar above the tab bar of one tab and owns its expand / collapse. Applied to every player tab root.
struct ActiveSessionMiniBarHost: ViewModifier {
    let isTabBarHidden: Bool
    /// The roam's own full-screen live screen (shared controller), used as its expanded HUD.
    let roamHUD: () -> AnyView
    @State private var store = ActiveSessionStore.shared
    @State private var expanded: ActiveSessionStore.Entry?
    @QuestifyReduceMotion private var reduceMotion
    @Namespace private var zoom

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isTabBarHidden, let entry = store.visibleEntry {
                    ActiveSessionMiniBar(entry: entry) { present(entry) }
                        .modifier(ActiveSessionZoomSource(namespace: zoom, enabled: !reduceMotion))
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                        .padding(.bottom, CYSpacing.xs)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .smooth, value: store.visibleEntry?.kind)
            .fullScreenCover(item: $expanded) { entry in
                ActiveSessionExpandedHUD(entry: entry, roamHUD: roamHUD) { present(nil) }
                    .modifier(ActiveSessionZoomDestination(namespace: zoom, enabled: !reduceMotion))
            }
            .onChange(of: store.current?.key) { _, key in
                if key == nil { expanded = nil }
            }
    }

    /// Reduce Motion: no zoom and no slide; the cover appears without animation and its content fades in (crossfade).
    private func present(_ entry: ActiveSessionStore.Entry?) {
        var transaction = Transaction()
        transaction.disablesAnimations = reduceMotion
        withTransaction(transaction) { expanded = entry }
    }
}

extension ActiveSessionStore.Entry: Identifiable {
    var id: String { key }
}

/// Full-screen HUD with 收起 top-leading; swiping down collapses (the zoom transition's interactive dismiss on iOS 18+,
/// plus an explicit drag on the play HUD).
struct ActiveSessionExpandedHUD: View {
    let entry: ActiveSessionStore.Entry
    let roamHUD: () -> AnyView
    let onCollapse: () -> Void
    @State private var store = ActiveSessionStore.shared
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false

    var body: some View {
        NavigationStack {
            Group {
                if entry.kind == .roam {
                    roamHUD()
                } else {
                    ActiveSessionPlayHUD(entry: store.entries[entry.kind] ?? entry)
                        // iOS 17 / Reduce Motion have no interactive zoom dismiss: a downward swipe collapses here.
                        // Not on the roam screen, where vertical drags belong to the map and its sheet.
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 24).onEnded { value in
                                if value.translation.height > 120 && abs(value.translation.width) < value.translation.height { onCollapse() }
                            }
                        )
                        .navigationTitle(Text(ActiveSessionCopy.titleKey(entry.kind)))
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onCollapse) { Label("activeSession.collapse", systemImage: "chevron.down") }
                        .accessibilityIdentifier("activeSession.hud.collapse")
                }
            }
        }
        .opacity(reduceMotion && !shown ? 0 : 1)
        .onAppear {
            if reduceMotion { withAnimation(.easeInOut(duration: 0.2)) { shown = true } } else { shown = true }
        }
    }
}

/// iOS 18+: the bar is the zoom source. Off under Reduce Motion (crossfade instead).
struct ActiveSessionZoomSource: ViewModifier {
    let namespace: Namespace.ID
    let enabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18, *), enabled {
            content.matchedTransitionSource(id: "activeSession.miniBar", in: namespace)
        } else {
            content
        }
    }
}

struct ActiveSessionZoomDestination: ViewModifier {
    let namespace: Namespace.ID
    let enabled: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18, *), enabled {
            content.navigationTransition(.zoom(sourceID: "activeSession.miniBar", in: namespace))
        } else {
            content
        }
    }
}
