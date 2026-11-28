import SwiftUI

// Share composer (e3 share hero): a live card carousel with a springy template switcher, background swatches,
// story / portrait / square ratio and a caption field. The caller owns the content, the privacy toggles (`controls`) and the
// export actions (`actions`), so the kit never decides what leaves the device.
// Motion: viewAligned paging, neighbours scale to 0.92 and fade; selection haptic on template, ratio and tint.
// Reduce Motion: no scale or spring, instant page change, 0.18 s cross-fades only.
// The carousel IS the live preview: style changes re-render SwiftUI, never a bitmap; `ImageRenderer` runs only on prepare.

struct CYShareComposer<Controls: View, Actions: View>: View {
    let content: CYShareCardContent
    @Binding var style: CYShareCardStyle
    @Binding var caption: String
    var captionLimit = 80
    var captionPlaceholder: String
    var accessibilityPrefix = "share.composer"
    @ViewBuilder var controls: () -> Controls
    @ViewBuilder var actions: () -> Actions

    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @QuestifyReduceMotion private var reduceMotion
    @State private var scrolledTemplate: CYShareCardTemplate?
    @FocusState private var captionFocused: Bool

    private var animation: Animation? { reduceMotion ? CYMotion.reduced : CYMotion.standard }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xl) {
            carousel
            templateChips
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                ratioPicker
                swatches
            }
            captionField
            controls()
            actions()
        }
        .onAppear { scrolledTemplate = style.template }
        .onChange(of: scrolledTemplate) { _, value in
            guard let value, value != style.template else { return }
            withAnimation(animation) { style.template = value }
        }
        .onChange(of: style.template) { _, value in
            guard scrolledTemplate != value else { return }
            withAnimation(animation) { scrolledTemplate = value }
        }
        .cyHaptic(.selection, trigger: style.template)
        .cyHaptic(.selection, trigger: style.tint)
        .cyHaptic(.selection, trigger: style.ratio)
    }

    // MARK: Carousel

    private var carousel: some View {
        let reduce = reduceMotion
        return ScrollView(.horizontal) {
            HStack(spacing: CYSpacing.lg) {
                ForEach(CYShareCardTemplate.allCases) { template in
                    CYShareCardPreview(content: content, style: style.with(template: template))
                        .containerRelativeFrame(.horizontal) { length, _ in max(160, length - 96) }
                        .scrollTransition(.interactive, axis: .horizontal) { view, phase in
                            view
                                .scaleEffect(reduce || phase.isIdentity ? 1 : 0.92)
                                .opacity(phase.isIdentity ? 1 : 0.65)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                        .overlay(alignment: .topTrailing) {
                            if template == style.template {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.white, palette.success)
                                    .padding(CYSpacing.md)
                                    .transition(.opacity)
                                    .accessibilityHidden(true)
                            }
                        }
                        .id(template)
                        .accessibilityAddTraits(template == style.template ? AccessibilityTraits([.isSelected, .isImage]) : AccessibilityTraits.isImage)
                        .accessibilityHint(Text(verbatim: template.name(locale)))
                        .accessibilityIdentifier(accessibilityPrefix + ".card." + template.rawValue)
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, CYSpacing.sm)
        }
        .contentMargins(.horizontal, 48, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledTemplate)
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .animation(animation, value: style.template)
        // Ratio: the artboard frame (640 / 450 / 360 pt scaled) and its siblings reflow with `standard`; tint: the card ground cross-fades `quick`.
        .animation(animation, value: style.ratio)
        .animation(reduce ? CYMotion.reduced : .easeInOut(duration: CYMotion.Duration.quick), value: style.tint)
        .accessibilityIdentifier(accessibilityPrefix + ".carousel")
    }

    // MARK: Template chips

    private var templateChips: some View {
        let layout = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        return layout {
            ForEach(CYShareCardTemplate.allCases) { template in
                let selected = template == style.template
                Button {
                    withAnimation(animation) { style.template = template }
                } label: {
                    Label { Text(verbatim: template.name(locale)) } icon: { Image(systemName: template.symbol) }
                        .font(CYTypography.label.weight(.semibold))
                        .foregroundStyle(selected ? palette.textPrimary : palette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(selected ? palette.bgRaised : palette.bgElevated, in: Capsule(style: .continuous))
                        .overlay(Capsule(style: .continuous).strokeBorder(selected ? palette.borderStrong : palette.borderSubtle, lineWidth: 1))
                }
                .buttonStyle(.cyPressable)
                .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
                .accessibilityIdentifier(accessibilityPrefix + ".template." + template.rawValue)
            }
        }
    }

    // MARK: Ratio

    private var ratioPicker: some View {
        Picker(selection: $style.ratio) {
            ForEach(CYShareCardRatio.allCases) { ratio in
                Text(verbatim: ratio.name(locale)).tag(ratio)
            }
        } label: {
            Text(verbatim: locale.pick("尺寸", "Size"))
        }
        .cyAdaptiveSegmented()
        .accessibilityIdentifier(accessibilityPrefix + ".ratio")
    }

    // MARK: Swatches

    private var swatches: some View {
        ScrollView(.horizontal) {
            HStack(spacing: CYSpacing.md) {
                ForEach(CYShareCardTint.pickable) { tint in
                    let selected = tint == style.tint
                    Button {
                        withAnimation(animation) { style.tint = tint }
                    } label: {
                        Circle()
                            .fill(LinearGradient(colors: [tint.primary, tint.secondary], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 36, height: 36)
                            .overlay {
                                if selected {
                                    Image(systemName: "checkmark").font(.footnote.weight(.bold)).foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.5), radius: 1)
                                }
                            }
                            .padding(4)
                            .overlay(Circle().strokeBorder(selected ? palette.textPrimary : .clear, lineWidth: 2))
                            .scaleEffect(selected && !reduceMotion ? 1.08 : 1)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: tint.name(locale)))
                    .accessibilityAddTraits(selected ? AccessibilityTraits.isSelected : AccessibilityTraits())
                    .accessibilityIdentifier(accessibilityPrefix + ".tint." + tint.rawValue)
                }
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.hidden)
        .animation(animation, value: style.tint)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(verbatim: locale.pick("背景颜色", "Background color")))
    }

    // MARK: Caption

    private var captionField: some View {
        VStack(alignment: .trailing, spacing: CYSpacing.xs) {
            TextField(text: $caption, axis: .vertical) {
                Text(verbatim: captionPlaceholder)
            }
            .lineLimit(1...3)
            .cyText(.body)
            .foregroundStyle(palette.textPrimary)
            .focused($captionFocused)
            .submitLabel(.done)
            .onSubmit { captionFocused = false }
            .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.md)
            .frame(minHeight: 48)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).strokeBorder(captionFocused ? palette.borderStrong : palette.borderSubtle, lineWidth: 1))
            .onChange(of: caption) { _, value in
                // No newlines in a one-line caption; clamp to the limit without surprising the cursor.
                let flat = value.replacingOccurrences(of: "\n", with: " ")
                let clamped = flat.count > captionLimit ? String(flat.prefix(captionLimit)) : flat
                if clamped != value { caption = clamped }
            }
            .accessibilityIdentifier(accessibilityPrefix + ".caption")
            Text(verbatim: "\(caption.count)/\(captionLimit)")
                .cyText(.micro).monospacedDigit()
                .foregroundStyle(palette.textTertiary)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Previews (synthetic)

#Preview("Share composer · player dark") {
    ScrollView {
        CYShareComposer(content: CYShareCardContent(kind: .route, eyebrow: "Official route", title: "Old Town Lantern Walk", subtitle: nil, place: nil,
                                                     stats: [CYShareStat("Duration", "1 h 35 min"), CYShareStat("Distance", "3.2 km"), CYShareStat("Stops", "4")],
                                                     silhouette: [CGPoint(x: 0.1, y: 0.7), CGPoint(x: 0.4, y: 0.3), CGPoint(x: 0.9, y: 0.2)],
                                                     artSeed: "lantern", artSymbol: "point.topleft.down.to.point.bottomright.curvepath", brand: "城瘾", debugArt: true),
                        style: .constant(CYShareCardStyle()), caption: .constant(""), captionPlaceholder: "Add a caption") {
            Toggle(isOn: .constant(false)) { Text(verbatim: "Show place name") }
        } actions: {
            CYPillButton(verbatim: "Share image", systemImage: "square.and.arrow.up") {}
        }
        .padding(.horizontal, CYSpacing.lg)
    }
    .background(CYColor.bgPage.ignoresSafeArea())
    .roleTheme(.player)
}
