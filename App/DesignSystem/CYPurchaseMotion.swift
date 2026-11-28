import SwiftUI

// Purchase motion kit (e4 hero). Spec: docs/release/motion-spec-purchase.md.
// Builds on CYMotion / CYHaptics only; every moving piece is gated on Reduce Motion through `@QuestifyReduceMotion`.

// MARK: - Animated price

/// Amount text whose digits roll when the value changes (`contentTransition(.numericText)`).
/// Reduce Motion: a 0.18 s cross-fade. Always one line, monospaced digits, scales down to 0.7 before truncating.
struct CYAnimatedPrice: View {
    let text: String
    var font: Font = CYTypography.data2XL
    var color: Color? = nil
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Text(verbatim: text)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color ?? palette.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(reduceMotion ? .opacity : .numericText())
            .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: text)
    }
}

// MARK: - Result mark (checkmark draw-on, failure cross, pending arc)

/// The single stroked glyph used by every result: a ring draws on, then the mark strokes in (`Path.trim`).
/// `.failure` adds one short nudge after the X lands; `.pending` rotates an open arc.
/// Decorative: hidden from VoiceOver, the title next to it carries the meaning. Reduce Motion: drawn complete at once.
struct CYResultMark: View {
    enum Kind: Equatable { case success, failure, pending }
    var kind: Kind
    var size: CGFloat = 120
    /// Draws when this flips to true (default: on appear).
    var trigger: Bool = true

    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @State private var ring: CGFloat = 0
    @State private var stroke: CGFloat = 0
    @State private var bloom = false
    @State private var nudge: CGFloat = 0
    @State private var spin = false

    private var tint: Color {
        switch kind {
        case .success: return palette.success
        case .failure: return palette.danger
        case .pending: return palette.warning
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .scaleEffect(bloom ? 1 : 0.82)
            if kind == .pending {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(tint, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                    .rotationEffect(.degrees(spin ? 270 : -90))
            } else {
                Circle()
                    .trim(from: 0, to: ring)
                    .stroke(tint, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                CYMarkShape(kind: kind)
                    .trim(from: 0, to: stroke)
                    .stroke(tint, style: StrokeStyle(lineWidth: size * 0.075, lineCap: .round, lineJoin: .round))
                    .padding(size * 0.29)
            }
        }
        .frame(width: size, height: size)
        .offset(x: nudge)
        .accessibilityHidden(true)
        .onAppear { if trigger { draw() } }
        .onChange(of: trigger) { _, new in if new { draw() } }
        .onChange(of: kind) { _, _ in draw() }
    }

    private func draw() {
        if reduceMotion {
            ring = 1; stroke = 1; bloom = true; spin = false
            return
        }
        if kind == .pending {
            ring = 1; stroke = 0; bloom = true
            spin = false
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
            return
        }
        ring = 0; stroke = 0; bloom = false; nudge = 0
        withAnimation(.easeOut(duration: CYMotion.Duration.emphasized)) { ring = 1; bloom = true }
        withAnimation(.easeInOut(duration: 0.4).delay(0.2)) { stroke = 1 }
        if kind == .failure {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(620))
                nudge = 7
                withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) { nudge = 0 }
            }
        }
    }
}

/// Check or cross as one path so `trim` strokes it in order.
struct CYMarkShape: Shape {
    var kind: CYResultMark.Kind
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width, h = rect.height
        switch kind {
        case .success, .pending:
            p.move(to: CGPoint(x: rect.minX + w * 0.08, y: rect.minY + h * 0.55))
            p.addLine(to: CGPoint(x: rect.minX + w * 0.38, y: rect.minY + h * 0.84))
            p.addLine(to: CGPoint(x: rect.minX + w * 0.94, y: rect.minY + h * 0.22))
        case .failure:
            p.move(to: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.16))
            p.addLine(to: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.84))
            p.move(to: CGPoint(x: rect.minX + w * 0.84, y: rect.minY + h * 0.16))
            p.addLine(to: CGPoint(x: rect.minX + w * 0.16, y: rect.minY + h * 0.84))
        }
        return p
    }
}

// MARK: - Pay button

/// Primary pay CTA: 56 pt capsule, scale 0.96 on the press spring with a medium impact on touch-down (the primary
/// commit), label swaps to a spinner while `processing` (and the button is disabled). Reduce Motion: dim, no scale.
struct CYPayButton: View {
    let title: String
    var amount: String? = nil
    var processing = false
    var systemImage: String? = "lock.fill"
    /// Spoken while processing ("processing").
    var processingLabel: String = ""
    let action: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: CYSpacing.sm) {
                    if let systemImage { Image(systemName: systemImage).font(.body.weight(.semibold)) }
                    Text(verbatim: title)
                    if let amount {
                        Text(verbatim: amount)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(processing ? 0 : 1)
                if processing {
                    ProgressView().tint(palette.actionPrimaryFg).transition(.opacity)
                }
            }
            .cyText(.bodyMedium)
            .foregroundStyle(isEnabled || processing ? palette.actionPrimaryFg : palette.textDisabled)
            .padding(.horizontal, CYSpacing.xl)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule(style: .continuous).fill(isEnabled || processing ? palette.actionPrimaryBg : palette.bgSurfaceSubtle))
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(CYPayPressStyle())
        .disabled(processing)
        .cyAnimation(value: processing)
        .accessibilityLabel(Text(verbatim: amount.map { "\(title) \($0)" } ?? title))
        .accessibilityValue(Text(verbatim: processing ? processingLabel : ""))
    }
}

/// Press feel for the pay button: `cyPressEffect` at 0.96 plus `.impactMedium` on touch-down.
struct CYPayPressStyle: ButtonStyle {
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.cyPressHandled, true)
            .cyPressEffect(configuration.isPressed && isEnabled, scale: 0.96, reduceMotion: reduceMotion)
            .cyHaptic(.impactMedium, trigger: configuration.isPressed && isEnabled, where: CYHapticTransition.turnedOn)
    }
}

// MARK: - Pinned buy bar

/// Pinned purchase bar: a price pill that toggles the order summary, and one primary CTA.
/// Material background (solid elevated surface under Reduce Transparency). Stacks vertically at accessibility sizes.
/// The pill's chevron flips and its fill lifts while `summaryOpen`; the summary itself is the caller's sheet.
struct CYBuyBar: View {
    var priceText: String?
    /// Small caption above the amount ("Total").
    let priceCaption: String
    /// VoiceOver suffix for the pill ("order summary").
    let summaryLabel: String
    let ctaTitle: String
    var ctaSystemImage: String? = nil
    var processing = false
    var processingLabel: String = ""
    @Binding var summaryOpen: Bool
    let onCTA: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @QuestifyReduceMotion private var reduceMotion

    private var stacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.md))
        layout {
            pill
            CYPayButton(title: ctaTitle, processing: processing, systemImage: ctaSystemImage, processingLabel: processingLabel, action: onCTA)
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.md)
        .background {
            ZStack {
                if reduceTransparency { palette.bgElevated } else { Rectangle().fill(.bar) }
            }
            .overlay(alignment: .top) { Divider().overlay(palette.borderSubtle) }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var pill: some View {
        Button {
            summaryOpen.toggle()
        } label: {
            HStack(spacing: CYSpacing.sm) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(verbatim: priceCaption).cyText(.meta).foregroundStyle(palette.textTertiary)
                    CYAnimatedPrice(text: priceText ?? "—", font: CYTypography.dataXL)
                }
                Image(systemName: "chevron.up")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(palette.textSecondary)
                    .rotationEffect(.degrees(summaryOpen && !reduceMotion ? 180 : 0))
            }
            .padding(.horizontal, CYSpacing.md)
            .padding(.vertical, CYSpacing.xs)
            .frame(minHeight: 56, alignment: .leading)
            .frame(maxWidth: stacked ? CGFloat.infinity : nil, alignment: .leading)
            .background(
                Capsule(style: .continuous).fill(summaryOpen ? palette.actionSecondaryBg : .clear)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.cyPressable)
        .cyAnimation(value: summaryOpen)
        .accessibilityLabel(Text(verbatim: "\(priceCaption) \(priceText ?? "—"), \(summaryLabel)"))
        .accessibilityAddTraits(summaryOpen ? .isSelected : [])
    }
}
