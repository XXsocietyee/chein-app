import SwiftUI

/// Interactive scratch-off card (`cy-scratch` port) with haptics, Reduce Motion bypass, and accessible fallback reveal button.
@MainActor struct CYScratchCard<Content: View>: View {
    let coverLabel: String?
    let threshold: Double
    let enabled: Bool
    let externallyRevealed: Bool
    let onReveal: (Double) -> Void
    @ViewBuilder let content: () -> Content

    @State private var tracker: CYScratchProgressTracker
    @State private var lastDragPoint: CGPoint?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        coverLabel: String? = nil,
        threshold: Double = CYScratchProgressTracker.defaultThreshold,
        enabled: Bool = true,
        revealed: Bool = false,
        onReveal: @escaping (Double) -> Void = { _ in },
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.coverLabel = coverLabel
        self.threshold = CYScratchProgressTracker.clampThreshold(threshold)
        self.enabled = enabled
        self.externallyRevealed = revealed
        self.onReveal = onReveal
        self.content = content
        self._tracker = State(initialValue: CYScratchProgressTracker(threshold: threshold))
    }

    private var isRevealed: Bool {
        externallyRevealed || tracker.revealed || reduceMotion
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            ZStack {
                content()
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .padding(CYSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                            .fill(CYNight.glassFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                            .strokeBorder(CYNight.glassEdgeTop)
                    )

                if !isRevealed {
                    GeometryReader { proxy in
                        Canvas { context, size in
                            context.fill(
                                Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: CYRadius.md),
                                with: .color(CYNight.ink2)
                            )
                            context.blendMode = .destinationOut
                            let scaleX = size.width / max(1, tracker.width)
                            let scaleY = size.height / max(1, tracker.height)
                            for segment in tracker.segments {
                                var path = Path()
                                path.move(to: CGPoint(x: segment.from.x * scaleX, y: segment.from.y * scaleY))
                                path.addLine(to: CGPoint(x: segment.to.x * scaleX, y: segment.to.y * scaleY))
                                context.stroke(
                                    path,
                                    with: .color(.black),
                                    style: StrokeStyle(
                                        lineWidth: segment.radius * 2 * max(scaleX, scaleY),
                                        lineCap: .round,
                                        lineJoin: .round
                                    )
                                )
                            }
                        }
                        .compositingGroup()
                        .overlay {
                            VStack(spacing: CYSpacing.xs) {
                                Image(systemName: "hand.draw.fill")
                                    .font(CYTypography.sectionTitle)
                                    .foregroundStyle(CYNight.textSecondary)
                                    .accessibilityHidden(true)
                                Text(verbatim: (coverLabel?.isEmpty == false ? coverLabel : nil) ?? "")
                                    .font(CYTypography.bodyMedium)
                                    .foregroundStyle(CYNight.textPrimary)
                                if coverLabel?.isEmpty != false {
                                    Text("playkit.scratch.coverPrompt")
                                        .font(CYTypography.bodyMedium)
                                        .foregroundStyle(CYNight.textPrimary)
                                }
                            }
                            .allowsHitTesting(false)
                            .opacity(tracker.progress > 0.25 ? 0.35 : 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    guard enabled else { return }
                                    let from = lastDragPoint ?? value.startLocation
                                    let to = value.location
                                    lastDragPoint = to
                                    let scaleX = tracker.width / max(1, proxy.size.width)
                                    let scaleY = tracker.height / max(1, proxy.size.height)
                                    let p1 = CYScratchProgressTracker.Point(x: from.x * scaleX, y: from.y * scaleY)
                                    let p2 = CYScratchProgressTracker.Point(x: to.x * scaleX, y: to.y * scaleY)
                                    UIKitHapticsDriver.ensureInstalled()
                                    if tracker.stamp(from: p1, to: p2, radius: 22) {
                                        HapticsService.shared.play(.scratchReveal)
                                        onReveal(max(threshold, tracker.progress))
                                    } else {
                                        HapticsService.shared.play(.scratchRub)
                                    }
                                }
                                .onEnded { _ in
                                    lastDragPoint = nil
                                }
                        )
                    }
                    .frame(minHeight: 140)
                    .accessibilityHidden(true)
                }
            }
            .accessibilityIdentifier("playkit.scratchCard.surface")

            if !isRevealed {
                CYPillButton("playkit.scratch.revealDirect", style: .secondary) {
                    UIKitHapticsDriver.ensureInstalled()
                    if tracker.revealAll() {
                        HapticsService.shared.play(.scratchReveal)
                        onReveal(1.0)
                    }
                }
                .disabled(!enabled)
                .accessibilityIdentifier("playkit.scratchCard.revealDirect")
            }
        }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced && !externallyRevealed && !tracker.revealed && enabled {
                if tracker.revealAll() {
                    onReveal(1.0)
                }
            }
        }
    }
}
