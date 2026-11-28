import SwiftUI

/// OWNER RULE 3 level A for NPC / guide moments: the character is present (a soft breathing ring while it is
/// "thinking" or speaking), its words arrive with a typing reveal, and a light haptic marks a finished line.
/// Reduce Motion: no breathing, the whole line at once.

/// The formless guide mark (no face, no name): a tinted sparkles glyph. Breathes while `active`.
struct AIGuidePresenceMark: View {
    var active: Bool = false
    var size: CGFloat = 36
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Image(systemName: "sparkles")
            .font(.body.weight(.semibold))
            .foregroundStyle(CYColor.brand)
            .frame(width: size, height: size)
            .background(CYColor.brand.opacity(0.12), in: Circle())
            .modifier(AIPresenceBreathing(active: active && !reduceMotion))
            .accessibilityHidden(true)
    }
}

/// The in-store NPC's avatar with the same presence ring.
struct AINPCPresenceAvatar: View {
    let name: String
    var active: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CYAvatarView(name: name, size: .lg, isOnline: true)
            .modifier(AIPresenceBreathing(active: active && !reduceMotion))
    }
}

/// A slow scale + ring pulse while active; nothing otherwise.
struct AIPresenceBreathing: ViewModifier {
    let active: Bool
    @State private var inhale = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && inhale ? 1.06 : 1)
            .overlay(Circle().stroke(CYColor.brand.opacity(active && inhale ? 0.35 : 0), lineWidth: 2)
                .scaleEffect(active && inhale ? 1.18 : 1))
            .onAppear { breathe(active) }
            .onChange(of: active) { _, now in breathe(now) }
    }

    private func breathe(_ on: Bool) {
        if on {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { inhale = true }
        } else {
            withAnimation(.easeOut(duration: 0.2)) { inhale = false }
        }
    }
}

/// Reveals `text` a few characters at a time (about one second for any length). The server already reviewed the
/// whole text (BE `NpcChatResp.safeText`); this is presentation only, so VoiceOver always gets the full line.
struct AITypingRevealText: View {
    let text: String
    /// Set false to show the whole line at once (an older message, or one already revealed).
    var animates: Bool = true
    @State private var visible = 0
    @State private var finished = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(verbatim: text)
            .opacity(0)
            .overlay(alignment: .topLeading) {
                Text(verbatim: String(text.prefix(shownCount)))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: text))
            .sensoryFeedback(.impact(weight: .light), trigger: finished)
            .task(id: text) { await reveal() }
    }

    private var shownCount: Int { animates && !reduceMotion ? visible : text.count }

    private func reveal() async {
        let total = text.count
        guard animates, !reduceMotion, total > 0 else { visible = total; return }
        visible = 0
        let step = max(1, total / 40)
        var shown = 0
        while shown < total {
            try? await Task.sleep(nanoseconds: 25_000_000)
            if Task.isCancelled { return }
            shown = min(total, shown + step)
            visible = shown
        }
        finished += 1
    }
}
