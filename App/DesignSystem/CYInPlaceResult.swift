import SwiftUI

// In-place results (xrefs-1 B.0 "in place", Adopt 2 and Adopt 8; Figma `Player/Button State=Done`, `Player/Toast`
// Progress / Done, section 原地结果 `456:6742`). A result changes the control that caused it; it never pushes a new
// screen. One capsule carries the whole verb: Default → Pressed → Loading (spinner + 正在…) → Done (check + 已…).
// Shared by the player, editor, merchant and club pages: use these instead of swapping screens for a result.

/// The phase of an in-place result.
enum CYResultPhase: Equatable, Sendable {
    case idle, loading, done
}

/// `Player/Button` with its Loading and Done states in the same capsule.
///
/// - Press: dip to 0.97 (`CYMotion.press`), release `CYMotion.release` (from `CYPillButtonStyle`).
/// - Loading: a spinner and the 正在… label replace the idle label inside the capsule; a second tap is ignored.
/// - Done: a check enters (scale 0.25 → 1, opacity, blur 4 → 0, 300 ms) with the 已… label; one success haptic;
///   VoiceOver announces the done label. The caller dismisses its sheet after `CYMotion.Delay.sheetDismiss`.
/// - Failure: the caller sets `.idle` again (spring `release`) and shows one inline error line.
/// - The width follows the label on `CYMotion.standard`; Reduce Motion cross-fades in 200 ms and keeps the width.
struct CYResultButton: View {
    private let titles: [CYResultPhase: Text]
    private let spoken: [CYResultPhase: String]
    private let systemImage: String?
    private let style: CYPillStyle
    private let size: CYPillSize
    private let fullWidth: Bool
    private let phase: CYResultPhase
    private static func becameDone(_ old: CYResultPhase, _ new: CYResultPhase) -> Bool { new == .done }
    private let action: () -> Void
    private var identifierValue: String?

    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette

    /// Localized keys for the three labels (e.g. 确认圈地 / 正在确认 / 已圈下).
    init(_ title: LocalizedStringKey, loading: LocalizedStringKey, done: LocalizedStringKey, systemImage: String? = nil,
         phase: CYResultPhase, style: CYPillStyle = .primary, size: CYPillSize = .regular, fullWidth: Bool = true,
         action: @escaping () -> Void) {
        titles = [.idle: Text(title), .loading: Text(loading), .done: Text(done)]
        spoken = [:]
        self.systemImage = systemImage; self.phase = phase; self.style = style; self.size = size
        self.fullWidth = fullWidth; self.action = action
    }

    /// Already-resolved copy (City copy, server strings).
    init(verbatim title: String, loading: String, done: String, systemImage: String? = nil,
         phase: CYResultPhase, style: CYPillStyle = .primary, size: CYPillSize = .regular, fullWidth: Bool = true,
         action: @escaping () -> Void) {
        titles = [.idle: Text(verbatim: title), .loading: Text(verbatim: loading), .done: Text(verbatim: done)]
        spoken = [.idle: title, .loading: loading, .done: done]
        self.systemImage = systemImage; self.phase = phase; self.style = style; self.size = size
        self.fullWidth = fullWidth; self.action = action
    }

    /// The stable test identifier lives on the Button itself.
    func identifier(_ value: String) -> Self { var copy = self; copy.identifierValue = value; return copy }

    var body: some View {
        Button {
            guard phase == .idle else { return }
            action()
        } label: {
            ZStack {
                if reduceMotion {
                    // Reduce Motion: no width change, so the widest label sizes the capsule in every phase.
                    ForEach([CYResultPhase.idle, .loading, .done], id: \.self) { content(for: $0).hidden() }
                }
                content(for: phase)
                    .id(phase)
                    .transition(.opacity)
            }
        }
        .buttonStyle(CYPillButtonStyle(style: style, fullWidth: fullWidth, size: size))
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: phase)
        .cyHaptic(.success, trigger: phase, where: Self.becameDone)
        .onChange(of: phase) { _, new in
            guard new == .done, let text = spoken[.done] else { return }
            AccessibilityNotification.Announcement(text).post()
        }
        .accessibilityLabel(titles[phase] ?? Text(verbatim: ""))
        .accessibilityAddTraits(phase == .loading ? .updatesFrequently : [])
        .accessibilityIdentifier(identifierValue ?? "")
    }

    @ViewBuilder private func content(for phase: CYResultPhase) -> some View {
        HStack(spacing: CYSpacing.sm) {
            switch phase {
            case .idle:
                if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            case .loading:
                ProgressView().controlSize(.small)
                    .tint(CYPillButtonStyle.tokens(style: style, isEnabled: true, in: palette).foreground)
            case .done:
                Image(systemName: "checkmark")
                    .accessibilityHidden(true).fontWeight(.bold)
                    .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace).combined(with: .scale(scale: 0.25)))
            }
            titles[phase]
        }
    }
}

// MARK: - Toast that changes state

/// A toast's state. The capsule stays on screen while the phase changes (Progress → Done), so the result reads as the
/// same object changing, not a second toast.
struct CYResultToastState: Equatable, Sendable {
    enum Phase: Equatable, Sendable { case progress, done, failed }
    var phase: Phase
    /// Already-localized message (正在报名… / 报名成功).
    var message: String
    /// Trailing action shown on Done only (查看).
    var actionTitle: String?

    init(_ phase: Phase, _ message: String, actionTitle: String? = nil) {
        self.phase = phase; self.message = message; self.actionTitle = actionTitle
    }
}

/// `Player/Toast` Progress / Done. Origin: the leading icon. The icon swaps in place, the title cross-fades (200 ms),
/// the trailing action enters last (+300 ms, blurReplace). The capsule width grows once on `CYMotion.standard`.
struct CYResultToast: View {
    let state: CYResultToastState
    private static func becameDone(_ old: CYResultToastState.Phase, _ new: CYResultToastState.Phase) -> Bool { new == .done }
    private static func becameFailed(_ old: CYResultToastState.Phase, _ new: CYResultToastState.Phase) -> Bool { new == .failed }
    var onAction: (() -> Void)?

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var showsAction = false
    @ScaledMetric(relativeTo: .body) private var iconSize: CGFloat = 20

    var body: some View {
        HStack(spacing: CYSpacing.sm) {
            ZStack {
                switch state.phase {
                case .progress:
                    ProgressView().controlSize(.small).tint(palette.textSecondary).transition(.opacity)
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(palette.success)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace).combined(with: .scale(scale: 0.25)))
                case .failed:
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(palette.warning)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace).combined(with: .scale(scale: 0.25)))
                }
            }
            .cyText(.cardTitle)
            .frame(width: iconSize, height: iconSize)
            .accessibilityHidden(true)

            Text(verbatim: state.message)
                .cyText(.bodyCompact)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            if showsAction, let title = state.actionTitle, let onAction {
                Button(action: onAction) {
                    Text(verbatim: title)
                        .cyText(.label, weight: .bold)
                        .foregroundStyle(palette.textPrimary)
                        .padding(.horizontal, CYSpacing.sm)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
            }
        }
        .padding(.leading, CYSpacing.lg)
        .padding(.trailing, showsAction ? CYSpacing.xs : CYSpacing.lg)
        .padding(.vertical, showsAction ? 0 : CYSpacing.s2_5)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .background(Capsule(style: .continuous).fill(palette.bgElevated))
        .overlay(Capsule(style: .continuous).strokeBorder(palette.borderStrong, lineWidth: 0.5))
        .shadow(color: CYColor.floatShadowColor, radius: 16, x: 0, y: 8)
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: state)
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: showsAction)
        .task(id: state) {
            guard state.phase == .done, state.actionTitle != nil else { showsAction = false; return }
            try? await Task.sleep(for: .seconds(CYMotion.Delay.toastAction))
            guard !Task.isCancelled else { return }
            showsAction = true
        }
        .cyHaptic(.success, trigger: state.phase, where: Self.becameDone)
        .cyHaptic(.error, trigger: state.phase, where: Self.becameFailed)
        .onChange(of: state) { _, new in
            guard new.phase != .progress else { return }
            AccessibilityNotification.Announcement(new.message).post()
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cy.result.toast")
    }
}

private struct CYResultToastModifier: ViewModifier {
    @Binding var state: CYResultToastState?
    let dwell: Double
    let onAction: (() -> Void)?
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let current = state {
                CYResultToast(state: current, onAction: onAction.map { action in { action(); state = nil } })
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.bottom, CYSpacing.xxl)
                    .transition(reduceMotion ? .opacity : .asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity).animation(CYMotion.hide)))
                    .task(id: current) {
                        // Progress waits for its answer; a result dwells, longer when it carries an action.
                        guard current.phase != .progress else { return }
                        let seconds = current.actionTitle == nil ? dwell : dwell + 1
                        try? await Task.sleep(for: .seconds(seconds))
                        guard !Task.isCancelled else { return }
                        withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.hide) { state = nil }
                    }
            }
        }
        // Enter on the sheet spring; the same capsule retargets when the phase changes (it never leaves to show it).
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.sheet, value: state != nil)
    }
}

extension View {
    /// Shows a toast that changes state in place (Progress → Done / failed) while `state` is non-nil. A result
    /// (`.done`, `.failed`) clears itself after `dwell` seconds (one more when it carries an action).
    func cyResultToast(_ state: Binding<CYResultToastState?>, dwell: Double = 2.5, onAction: (() -> Void)? = nil) -> some View {
        modifier(CYResultToastModifier(state: state, dwell: dwell, onAction: onAction))
    }
}

// MARK: - Numbers that win the page

extension View {
    /// The moment's number headline (`t-hero` 48 bold rounded, tabular, Dynamic Type): the dice total, a balance.
    func cyHeroNumberFont() -> some View { modifier(CYHeroNumberFont()) }
}

private struct CYHeroNumberFont: ViewModifier {
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 48
    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
    }
}

/// A number with a short-lived delta chip (xrefs-1 B.1: "one balance number with a −N chip"). The number rolls to its
/// new value (`cyNumericRoll`); the chip shows the change and fades 200 ms after the roll ends.
struct CYDeltaNumber: View {
    let value: Int64
    /// The pending or just-applied change (−120). nil or 0 shows no chip.
    var delta: Int64? = nil
    /// Keep the chip on screen (a quote that is not yet applied); false fades it once the roll lands.
    var holdsDelta = true
    var font: Font = .title3.weight(.bold)
    var leading: AnyView? = nil

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var chipVisible = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            if let leading { leading }
            Text(value, format: .number)
                .font(font)
                .foregroundStyle(palette.textPrimary)
                .cyNumericRoll(Double(value))
            if let delta, delta != 0, chipVisible {
                Text(verbatim: delta > 0 ? "+\(delta)" : "−\(-delta)")
                    .cyText(.label, weight: .semibold, monospacedDigit: true)
                    .foregroundStyle(delta > 0 ? palette.success : palette.textSecondary)
                    .padding(.horizontal, CYSpacing.sm).padding(.vertical, 2)
                    .background(palette.bgRaised, in: Capsule())
                    .transition(.opacity)
            }
        }
        .task(id: "\(value)-\(delta ?? 0)-\(holdsDelta)") {
            guard !holdsDelta else { chipVisible = true; return }
            try? await Task.sleep(for: .seconds(CYMotion.Duration.numericRoll + CYMotion.Duration.hide))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.hide) { chipVisible = false }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Stats without a box

/// `Player/Stat Tile Emphasis=Plain` (xrefs-1 Adopt 4, Figma `453:1412`): numbers in a row with 1 pt dividers and no
/// tile, number 22 pt bold tabular over an 11 pt label. A number rolls only when its value really changes.
struct CYPlainStat: Identifiable {
    let id: String
    let value: String
    let label: String
    /// The number behind `value`, so it rolls on change (nil: plain swap).
    var rollValue: Double? = nil
    var action: (() -> Void)? = nil
    var accessibilityIdentifier: String? = nil
}

struct CYPlainStatRow: View {
    let stats: [CYPlainStat]
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var dividerHeight: CGFloat = 28

    var body: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.md) { ForEach(stats) { cell($0, alignment: .leading) } }
        } else {
            HStack(spacing: 0) {
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 {
                        Rectangle().fill(palette.borderSubtle).frame(width: 1, height: dividerHeight).accessibilityHidden(true)
                    }
                    cell(stat, alignment: .center).frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder private func cell(_ stat: CYPlainStat, alignment: HorizontalAlignment) -> some View {
        let body = VStack(alignment: alignment, spacing: 2) {
            Text(verbatim: stat.value)
                .cyText(.sheetTitle)
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
                .modifier(CYOptionalNumericRoll(value: stat.rollValue))
            Text(verbatim: stat.label)
                .cyText(.caption)
                .foregroundStyle(palette.textTertiary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
        }
        if let action = stat.action {
            Button(action: action) { body.contentShape(Rectangle()) }
                .buttonStyle(.cyPressable)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(stat.accessibilityIdentifier ?? "")
        } else {
            body.accessibilityElement(children: .combine)
                .accessibilityIdentifier(stat.accessibilityIdentifier ?? "")
        }
    }
}

private struct CYOptionalNumericRoll: ViewModifier {
    let value: Double?
    @ViewBuilder func body(content: Content) -> some View {
        if let value { content.cyNumericRoll(value) } else { content.monospacedDigit() }
    }
}

// MARK: - Driving a result

/// Runs `work` behind a result button: idle → loading → done (held `CYMotion.Delay.sheetDismiss`) → `onDone`, or back
/// to idle on failure (returns the error for the caller's inline line). Keeps the spinner on screen for at least
/// 300 ms, so a fast answer never flashes.
@MainActor
enum CYResultRunner {
    static func run<T>(_ phase: Binding<CYResultPhase>, minimumLoading: Double = 0.3,
                       work: () async throws -> T) async -> Result<T, Error> {
        guard phase.wrappedValue == .idle else { return .failure(CancellationError()) }
        phase.wrappedValue = .loading
        let start = ContinuousClock.now
        do {
            let value = try await work()
            let floor = Duration.milliseconds(Int(minimumLoading * 1000))
            let elapsed = ContinuousClock.now - start
            if elapsed < floor { try? await Task.sleep(for: floor - elapsed) }
            phase.wrappedValue = .done
            return .success(value)
        } catch {
            phase.wrappedValue = .idle
            return .failure(error)
        }
    }
}

#if DEBUG
private struct CYInPlaceResultPreview: View {
    @State private var phase: CYResultPhase = .idle
    @State private var toast: CYResultToastState?
    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            CYResultButton(verbatim: "确认圈地 · 120 积分", loading: "正在确认", done: "已圈下", phase: phase) {
                Task { _ = await CYResultRunner.run($phase) { try await Task.sleep(for: .seconds(1)) } }
            }
            CYResultButton(verbatim: "报名", loading: "正在报名", done: "已报名", phase: phase, fullWidth: false) {}
            Button("Reset") { phase = .idle; toast = CYResultToastState(.progress, "正在报名…") }
            Button("Done") { toast = CYResultToastState(.done, "报名成功", actionTitle: "查看") }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cyDomainPageBackground()
        .cyResultToast($toast) {}
    }
}
#Preview("In-place result") { CYInPlaceResultPreview().themeDomain(.player) }
#endif

// MARK: - Streak row

/// `Player/Streak Row` (xrefs-1 Adopt 6, Figma `453:1504`): seven 24 pt day discs with weekday letters, the run of lit
/// days ending today in ink, unlit in ink-3, today's letter bold. Neutral colours only (selected states are neutral).
/// When today lights up: one symbol bounce on today's disc and one light impact; the other six never move.
struct CYStreakRow: View {
    /// Consecutive days including today; nil hides the row (unknown is never drawn as zero).
    let streakDays: Int
    private static func grew(_ old: Int, _ new: Int) -> Bool { new > old }
    var today = Date()
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 24

    private var days: [Date] {
        let calendar = Calendar.current
        return (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                let isToday = index == 6
                let lit = 6 - index < streakDays
                VStack(spacing: 4) {
                    Image(systemName: lit ? "flame.fill" : "flame")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(lit ? palette.actionPrimaryFg : palette.textTertiary)
                        .frame(width: disc, height: disc)
                        .background(lit ? palette.textPrimary : palette.bgRaised, in: Circle())
                        .symbolEffect(.bounce, options: .nonRepeating, value: isToday && lit && !reduceMotion ? streakDays : 0)
                    Text(verbatim: weekday(day))
                        .font(CYTypography.caption.weight(isToday ? .bold : .regular))
                        .foregroundStyle(isToday ? palette.textPrimary : palette.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cyHaptic(.impactLight, trigger: streakDays, where: Self.grew)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: locale.language.languageCode?.identifier == "zh"
                                 ? "连续探索 \(streakDays) 天" : "\(streakDays)-day exploring streak"))
        .accessibilityIdentifier("cy.streak.row")
    }

    private func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("EEEEE")
        return formatter.string(from: date)
    }
}

// MARK: - Moment seal

/// `Moment/Art` Seal at 96 pt (skill-r2 SR2-07 / SR2-11): the one playful object of a result moment (结算, 俱乐部已创建).
/// Lands from 1.6× and −24° to 1× and −8° on `CYMotion.seal`, with one heavy impact. Reduce Motion: it fades in place.
struct CYMomentSeal: View {
    let text: Text
    let landed: Bool
    private static func didLand(_ old: Bool, _ new: Bool) -> Bool { new }
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 96

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(LinearGradient(colors: [CYCityPalette.coin, CYCityPalette.gold], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.5), lineWidth: 3)
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.18), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .padding(size * 0.1)
            text
                .cyText(.sectionTitle)
                .foregroundStyle(Color.black.opacity(0.75))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .padding(.horizontal, size * 0.14)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(landed || reduceMotion ? -8 : -24))
        .scaleEffect(landed || reduceMotion ? 1 : 1.6)
        .opacity(landed ? 1 : 0)
        .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
        .animation(reduceMotion ? CYMotion.reduced : CYMotion.seal, value: landed)
        .cyHaptic(.impactHeavy, trigger: landed, where: Self.didLand)
        .accessibilityHidden(true)
    }
}
