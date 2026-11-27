import SwiftUI

/// mp-journey r3: MP `pages/play/index` `.navbubble` (途中 NPC 气泡). On the way to the current stop the walked share of
/// the distance is reported to `JourneyAmbientCoordinator.navigationProgress`, which reads `/api/play/companionLine`
/// once at 50 % and once at 90 % (MP `_updateNav`). The line shows as one quiet capsule (star + text, first 20
/// characters as in MP) and clears itself after 3.5 s.
struct PlayNavBubbleOverlay: ViewModifier {
    let model: JourneyAmbientCoordinator?
    let nodeID: Int?
    let meters: Double?

    func body(content: Content) -> some View {
        if let model {
            content.modifier(PlayNavBubbleHost(model: model, nodeID: nodeID, meters: meters))
        } else {
            content
        }
    }
}

private struct PlayNavBubbleHost: ViewModifier {
    @Bindable var model: JourneyAmbientCoordinator
    let nodeID: Int?
    let meters: Double?
    @State private var startNode: Int?
    @State private var startMeters: Double?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let line = model.line {
                    Label {
                        Text(verbatim: PlayNavBubbleText.short(line))
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "sparkle")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: .capsule)
                    .padding(.top, 56)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("journey.companion.bubble")
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: model.line)
            .onChange(of: meters) { _, value in report(value) }
            .onChange(of: model.line) { _, value in
                guard let value else { return }
                AccessibilityNotification.Announcement(value).post()
            }
            .task(id: model.line) {
                while !Task.isCancelled, model.line != nil {
                    model.tick(now: Date())
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
    }

    private func report(_ value: Double?) {
        guard let nodeID, let value, value.isFinite, value >= 0 else { return }
        if startNode != nodeID {
            startNode = nodeID
            startMeters = value
            return
        }
        guard let start = startMeters, start > 0 else { return }
        let fraction = min(max(1 - value / start, 0), 1)
        Task { await model.navigationProgress(nodeID: nodeID, fraction: fraction, now: Date()) }
    }
}

enum PlayNavBubbleText {
    /// MP: `text.length > 20 ? text.slice(0, 20) + '…' : text`.
    static func short(_ text: String) -> String {
        text.count > 20 ? String(text.prefix(20)) + "…" : text
    }
}
