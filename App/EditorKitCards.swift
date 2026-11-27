import SwiftUI

// Design hand-off r1 · Editor/Card, Editor/Card Footer, Editor/Section Bar, Editor/Save Chip,
// Editor/Step Bar and Editor/Bottom Bar (CF-17, CF-22, CF-44, CF-47, CF-48, CF-58).

/// `Editor/Card`: a white card whose header shows a one-line summary while collapsed (CF-44).
struct EditorCard<Content: View>: View {
    let title: Text
    var summary: Text? = nil
    @Binding var isCollapsed: Bool
    var showsError: Bool = false
    var accessibilityID: String? = nil
    @ViewBuilder let content: () -> Content

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Button {
                withAnimation(EditorKitMotion.reveal(reduceMotion: reduceMotion)) { isCollapsed.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: CYSpacing.xs) {
                            title.cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                            if showsError {
                                Circle().fill(palette.danger).frame(width: 6, height: 6)
                                    .accessibilityLabel(EditorKitText.text("editorKit.card.hasError"))
                            }
                        }
                        if isCollapsed, let summary {
                            summary.font(.subheadline).foregroundStyle(palette.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: CYSpacing.sm)
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.textTertiary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 180))
                        .accessibilityHidden(true)
                }
                .frame(minHeight: EditorKitMetric.hit)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(EditorKitText.text(isCollapsed ? "editorKit.card.collapsed" : "editorKit.card.expanded"))
            .modifier(EditorOptionalIdentifier(identifier: accessibilityID))
            .sensoryFeedback(.selection, trigger: isCollapsed)
            if !isCollapsed {
                content().transition(.opacity)
            }
        }
        .editorCardSurface()
    }
}

/// `Editor/Card Footer`: the two standard rows at the end of every gameplay card, in this order:
/// 次数上限 (stepper) with a 不限次数 switch that hides it, then 奖励 in 积分 (CF-47, CF-48).
struct EditorCardFooter: View {
    @Binding var limit: EditorAttemptLimit
    @Binding var reward: Int?
    var rewardRange: ClosedRange<Int> = 0...1000
    var showsLimit: Bool = true
    var surface: EditorKitSurface = .onCard
    var idPrefix: String = "editorKit.cardFooter"

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    private var limitedCount: Int? {
        if case .limited(let count) = limit { return count }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Divider().overlay(palette.borderSubtle)
            if showsLimit {
                EditorSwitchRow(
                    label: EditorKitText.text("editorKit.cardFooter.unlimited"),
                    isOn: Binding(
                        get: { limit.isUnlimited },
                        set: { value in withAnimation(EditorKitMotion.reveal(reduceMotion: reduceMotion)) { limit = limit.settingUnlimited(value) } }
                    ),
                    accessibilityID: idPrefix + ".unlimited"
                )
                if let count = limitedCount {
                    HStack {
                        EditorKitText.text("editorKit.cardFooter.limit").cyText(.body).foregroundStyle(palette.textPrimary)
                        Spacer(minLength: CYSpacing.sm)
                        EditorStepper(
                            value: Binding(get: { count }, set: { limit = .limited(EditorNumber.clamp($0, to: EditorAttemptLimit.range)) }),
                            range: EditorAttemptLimit.range,
                            unit: .times
                        )
                    }
                    .frame(minHeight: EditorKitMetric.switchRowMinHeight)
                    .transition(.opacity)
                    .accessibilityIdentifier(idPrefix + ".limit")
                }
            }
            EditorNumberRow(
                label: EditorKitText.text("editorKit.cardFooter.reward"),
                value: $reward,
                unit: .points,
                range: rewardRange,
                surface: surface,
                rangeError: Text("editorKit.cardFooter.rewardRange \(rewardRange.lowerBound) \(rewardRange.upperBound)", tableName: EditorKitText.table),
                accessibilityID: idPrefix + ".reward"
            )
        }
    }
}

/// `Editor/Section Bar`: sticky under the nav; current item underlined, red dot on sections with an
/// error, tap to jump (CF-44).
struct EditorSectionBar: View {
    let outline: EditorOutline
    let onSelect: (EditorOutlineSection) -> Void

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @Namespace private var underline

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(EditorOutlineSection.allCases) { section in
                    let state = outline.state(section)
                    Button { onSelect(section) } label: {
                        VStack(spacing: 4) {
                            HStack(spacing: 3) {
                                EditorKitText.text(section.key)
                                    .font(.subheadline.weight(state == .current ? .semibold : .regular))
                                    .foregroundStyle(state == .current ? palette.textPrimary : palette.textSecondary)
                                if state == .error {
                                    Circle().fill(palette.danger).frame(width: 6, height: 6).accessibilityHidden(true)
                                } else if state == .done {
                                    Image(systemName: "checkmark").font(.caption.weight(.bold))
                                        .foregroundStyle(palette.textTertiary).accessibilityHidden(true)
                                }
                            }
                            ZStack {
                                Capsule().fill(Color.clear).frame(height: 2)
                                if state == .current || (state == .error && outline.current == section) {
                                    Capsule().fill(palette.textPrimary).frame(height: 2)
                                        .matchedGeometryEffect(id: "editorKit.sectionBar.underline", in: underline)
                                }
                            }
                        }
                        .padding(.horizontal, CYSpacing.s2_5)
                        .frame(minHeight: EditorKitMetric.sectionBarHeight)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(EditorKitText.text(section.key))
                    .accessibilityValue(EditorKitText.text("editorKit.outline.state." + state.rawValue))
                    .accessibilityAddTraits(outline.current == section ? [.isSelected] : [])
                    .accessibilityIdentifier("editorKit.sectionBar." + section.rawValue)
                }
            }
            .padding(.horizontal, CYSpacing.md)
            .animation(reduceMotion ? nil : .easeOut(duration: EditorMotionSpec.revealSeconds), value: outline.current)
        }
        .frame(maxWidth: .infinity)
        .background(palette.bgPage)
        .overlay(alignment: .bottom) { Divider().overlay(palette.borderSubtle) }
        .sensoryFeedback(.selection, trigger: outline.current)
    }
}

/// `Editor/Save Chip`: a 12 pt icon plus two characters; detail (本机 / 云端 times) in a popover on tap (CF-22).
struct EditorSaveChip: View {
    let state: EditorSaveState
    var detail: Text? = nil
    @State private var showsDetail = false
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Button { if detail != nil { showsDetail = true } } label: {
            HStack(spacing: 4) {
                Image(systemName: state.symbol)
                    .font(.caption.weight(.bold))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)
                EditorKitText.text(state.key).cyText(.bodyMedium)
            }
            .foregroundStyle(state.usesErrorColour ? palette.danger : palette.textSecondary)
            .padding(.horizontal, CYSpacing.s2_5)
            .padding(.vertical, 5)
            .background(Capsule(style: .continuous).fill(state.usesErrorColour ? palette.dangerSoft : palette.brandSoft))
            .editorHitTarget()
        }
        .buttonStyle(.plain)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.14), value: state)
        .accessibilityLabel(EditorKitText.text(state.key))
        .accessibilityIdentifier("editorKit.saveChip")
        .popover(isPresented: $showsDetail) {
            (detail ?? Text(verbatim: EditorUnknown.dash))
                .cyText(.bodyCompact)
                .padding(CYSpacing.md)
                .presentationCompactAdaptation(.popover)
        }
    }
}

/// `Editor/Step Bar`: three tappable segments under the nav (CF-58). A segment opens once visited.
struct EditorStepBar: View {
    @Binding var progress: EditorStepProgress
    let labels: [Text]
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        HStack(spacing: CYSpacing.s1_5) {
            ForEach(0..<progress.count, id: \.self) { index in
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: EditorMotionSpec.revealSeconds)) { _ = progress.select(index) }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Capsule()
                            .fill(progress.isFilled(index) ? palette.textPrimary : palette.bgStrong)
                            .frame(height: 4)
                        if labels.indices.contains(index) {
                            labels[index]
                                .font(.footnote.weight(index == progress.current ? .semibold : .regular))
                                .foregroundStyle(index == progress.current ? palette.textPrimary : palette.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: EditorKitMetric.hit, alignment: .topLeading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!progress.canSelect(index))
                .accessibilityLabel(labels.indices.contains(index) ? labels[index] : Text(verbatim: String(index + 1)))
                .accessibilityValue(Text("editorKit.step.value \(index + 1) \(progress.count)", tableName: EditorKitText.table))
                .accessibilityAddTraits(index == progress.current ? [.isSelected] : [])
                .accessibilityIdentifier("editorKit.stepBar.\(index)")
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.xs)
    }
}

/// `Editor/Bottom Bar`: one primary pill; the rest are grey secondaries. The primary is never disabled
/// for missing data: it jumps to the first problem instead (CF-17). At accessibility sizes the
/// secondaries move into a "⋯" menu beside the full-width primary (CF-67).
struct EditorBottomBar<Secondary: View>: View {
    let primaryTitle: Text
    var primaryEnabled: Bool = true
    var primaryBusy: Bool = false
    var primaryID: String? = nil
    let primary: () -> Void
    @ViewBuilder let secondary: () -> Secondary

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(palette.borderSubtle)
            HStack(spacing: CYSpacing.s2_5) {
                if dynamicTypeSize.isAccessibilitySize {
                    Menu { secondary() } label: {
                        Image(systemName: "ellipsis").font(.body.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                            .frame(width: EditorKitMetric.closeVisual, height: EditorKitMetric.closeVisual)
                            .background(Circle().fill(palette.brandSoft))
                            .editorHitTarget()
                    }
                    .accessibilityLabel(EditorKitText.text("editorKit.more"))
                } else {
                    secondary()
                }
                Button(action: primary) {
                    Group {
                        if primaryBusy {
                            ProgressView()
                        } else {
                            primaryTitle
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!primaryEnabled || primaryBusy)
                .modifier(EditorOptionalIdentifier(identifier: primaryID))
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.top, CYSpacing.s2_5)
            .padding(.bottom, CYSpacing.sm)
        }
        .background(palette.bgElevated.ignoresSafeArea(edges: .bottom))
    }
}
