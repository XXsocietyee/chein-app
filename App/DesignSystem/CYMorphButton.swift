import SwiftUI

/// desdivj-style button that changes state in place: idle label, working (orbit dots), done (green check).
/// The width is fixed by the idle label (an invisible sizer), so nothing jumps between states.
/// Haptics: selection when the check lands, success 250 ms later, logged once per transition. Spec: design-wave3 §4.8, §5E.
enum CYMorphState: Equatable { case idle, working, done }

#if DEBUG
/// Records haptics the morph fires so a fixture video can be compared with the §3.6 table.
@MainActor enum CYHapticLog {
    private(set) static var entries: [String] = []
    static func record(_ name: String) {
        entries.append(name)
        print("[CYHaptic] \(name) #\(entries.count)")
    }
}
#endif

/// Three dots orbiting in a short arc. Reduce Motion: static dots, no travel.
struct CYMorphOrbitDots: View {
    var color: Color
    var dot: CGFloat = 7
    @QuestifyReduceMotion private var rm

    var body: some View {
        TimelineView(.animation(paused: rm)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            HStack(spacing: dot * 0.8) {
                ForEach(0..<3, id: \.self) { i in
                    let p = sin(t * 5.2 - Double(i) * 0.9)
                    Circle().fill(color).frame(width: dot, height: dot)
                        .offset(y: rm ? 0 : CGFloat(p) * -dot * 0.55)
                        .opacity(rm ? 1 : 0.55 + 0.45 * (p + 1) / 2)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

struct CYMorphButton<DoneAccessory: View>: View {
    private let title: LocalizedStringKey
    private let systemImage: String?
    private let state: CYMorphState
    private let fullWidth: Bool
    private let compact: Bool
    private let doneAccessory: DoneAccessory
    private let action: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @QuestifyReduceMotion private var rm
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 44
    @State private var pressed = false
    private var identifierValue: String?

    init(_ title: LocalizedStringKey, systemImage: String? = nil, state: CYMorphState, fullWidth: Bool = true, compact: Bool = false,
         @ViewBuilder doneAccessory: () -> DoneAccessory, action: @escaping () -> Void) {
        self.title = title; self.systemImage = systemImage; self.state = state
        self.fullWidth = fullWidth; self.compact = compact; self.doneAccessory = doneAccessory(); self.action = action
    }

    /// The stable test identifier lives on the Button itself, never on a container.
    func identifier(_ value: String) -> Self { var copy = self; copy.identifierValue = value; return copy }

    private var morph: Animation { rm ? CYMotion.reduced : .spring(response: 0.35, dampingFraction: 0.82) }

    var body: some View {
        let shape = Capsule(style: .continuous)
        Button {
            guard state == .idle else { return }
            action()
        } label: {
            ZStack {
                label.opacity(0).accessibilityHidden(true) // sizer: the idle label fixes the width in every state
                label.opacity(state == .idle ? 1 : 0).scaleEffect(state == .idle || rm ? 1 : 0.8)
                CYMorphOrbitDots(color: palette.actionPrimaryFg).opacity(state == .working ? 1 : 0)
                HStack(spacing: CYSpacing.sm) {
                    Image(systemName: "checkmark").font(.system(.body).weight(.heavy))
                        .symbolEffect(.bounce, options: .nonRepeating, value: state == .done && !rm)
                    doneAccessory
                }
                .foregroundStyle(CYNight.ink0)
                .opacity(state == .done ? 1 : 0).scaleEffect(state == .done || rm ? 1 : 0.5)
            }
            .cyText(.cardTitle)
            .foregroundStyle(isEnabled || state != .idle ? palette.actionPrimaryFg : palette.textPlaceholder)
            .padding(.horizontal, compact ? CYSpacing.xl : CYSpacing.xxl)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: compact ? compactHeight : height)
            .background {
                ZStack {
                    shape.fill(isEnabled || state != .idle ? palette.actionPrimaryBg : palette.bgSurfaceSubtle)
                    shape.fill(CYNight.verify).opacity(state == .done ? 1 : 0)
                }
            }
            .contentShape(shape)
            .scaleEffect(pressed && state == .idle && !rm ? 0.97 : 1)
        }
        .buttonStyle(CYMorphPressStyle(pressed: $pressed))
        .animation(morph, value: state)
        .onChange(of: state) { _, new in
            guard new == .done else { return }
            CYHaptics.selection.play()
            #if DEBUG
            CYHapticLog.record("selection")
            #endif
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                CYHaptics.success.play()
                #if DEBUG
                CYHapticLog.record("success")
                #endif
            }
        }
        .accessibilityIdentifier(identifierValue ?? "")
        .accessibilityLabel(Text(state == .done ? "club.membership.joined" : state == .working ? "club.action.working" : title))
    }

    @ViewBuilder private var label: some View {
        HStack(spacing: CYSpacing.sm) {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            Text(title)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension CYMorphButton where DoneAccessory == EmptyView {
    init(_ title: LocalizedStringKey, systemImage: String? = nil, state: CYMorphState, fullWidth: Bool = true, compact: Bool = false, action: @escaping () -> Void) {
        self.init(title, systemImage: systemImage, state: state, fullWidth: fullWidth, compact: compact, doneAccessory: { EmptyView() }, action: action)
    }
}

private struct CYMorphPressStyle: ButtonStyle {
    @Binding var pressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.onChange(of: configuration.isPressed) { _, v in pressed = v }
    }
}

/// Club join in one place: pill morphs idle -> dots -> green check, the player's avatar flies from the pill into the
/// member strip (count rolls +1), then the pill settles into a status chip. `state` is driven by the caller.
struct CYClubJoinStage: View {
    let title: LocalizedStringKey
    var systemImage: String? = "person.badge.plus"
    var settledTitle: LocalizedStringKey = "club.membership.joined"
    var settledIcon = "checkmark"
    var settledTone: CYStatusTone = .success
    let state: CYMorphState
    let seed: String
    var memberCount: Int? = nil
    var fullWidth = true
    var identifier: String? = nil
    let action: () -> Void

    @Namespace private var ns
    @State private var flown = false
    @State private var settled = false
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var rm

    private var showsStrip: Bool { state == .done }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if showsStrip { strip.transition(.opacity) }
            ZStack {
                if settled {
                    CYStatusChip(settledTitle, tone: settledTone, systemImage: settledIcon).transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    CYMorphButton(title, systemImage: systemImage, state: state, fullWidth: fullWidth, doneAccessory: {
                        if !flown { E3Avatar(seed: "\(seed)-me", size: 24).matchedGeometryEffect(id: "me-avatar", in: ns, isSource: true) }
                    }, action: action).identifier(identifier ?? "club.join.morph")
                }
            }
            .frame(maxWidth: .infinity, alignment: fullWidth ? .center : .leading)
        }
        .task(id: state) {
            guard state == .done else { flown = false; settled = false; return }
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            withAnimation(rm ? CYMotion.reduced : CYMotion.entrance) { flown = true }
            try? await Task.sleep(for: .milliseconds(600))
            if Task.isCancelled { return }
            withAnimation(CYMotion.reduced) { settled = true }
        }
    }

    private var strip: some View {
        HStack(spacing: CYSpacing.sm) {
            HStack(spacing: -9) {
                if flown { E3Avatar(seed: "\(seed)-me", size: 28).matchedGeometryEffect(id: "me-avatar", in: ns, isSource: false).zIndex(10) }
                else { Color.clear.frame(width: 28, height: 28) }
                if let n = memberCount, n > 0 {
                    ForEach(0..<min(n, 4), id: \.self) { i in E3Avatar(seed: "\(seed)-m\(i)", size: 28) }
                }
            }
            if let n = memberCount, n >= 0 {
                Text(verbatim: ClubMemberCountLocalization.text(n + (flown ? 1 : 0), locale: locale))
                    .cyText(.meta).monospacedDigit().contentTransition(.numericText())
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
