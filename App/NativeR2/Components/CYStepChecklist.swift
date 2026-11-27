import SwiftUI

/// One step of a `CYStepChecklist`. Titles and summaries arrive already localized (callers use `appLocalized` or MP copy).
struct CYChecklistStep: Identifiable, Equatable {
    enum State: Equatable { case done, current, todo, locked }
    let id: String
    let title: String
    var state: State
    /// Done: a one-line summary on the trailing side ("苏州河 · 10:00"). Current: the live status ("生成中…").
    var detail: String? = nil
    /// Done: an SF Symbol "thumbnail" on the trailing side when there is no summary.
    var thumbnailSymbol: String? = nil
    /// False hides 开始 on this step (nothing to start from here, e.g. staff verify a ticket).
    var startable: Bool = true
}

/// Pure counts behind the header ("2 of 5 complete", ring fraction).
enum CYStepChecklistMath {
    static func doneCount(_ steps: [CYChecklistStep]) -> Int { steps.filter { $0.state == .done }.count }
    static func fraction(_ steps: [CYChecklistStep]) -> Double {
        steps.isEmpty ? 0 : Double(doneCount(steps)) / Double(steps.count)
    }
    /// The step to highlight: the first `.current`, else the first `.todo`; nil when every step is done or locked.
    static func currentID(_ steps: [CYChecklistStep]) -> String? {
        (steps.first { $0.state == .current } ?? steps.first { $0.state == .todo })?.id
    }
}

/// Components r1 R-steps (owner reference: step checklist card). Header with icon, title, "2 of 5 complete" and a
/// `CYRing`; the current step highlighted with an inline 开始 and its live status; remaining steps with a secondary 开始;
/// a collapsible 已完成 (n) section whose rows carry a one-line summary or symbol thumbnail; 重置; and, once every step is
/// done, the caller's result card. Motion: the ring fills with a spring, a completed row's checkmark bounces
/// (`symbolEffect(.bounce)`), the done section collapses with an animation — all off under Reduce Motion.
/// Used by the publish wizards, the city-orientation run, the first-roam card and event check-in.
struct CYStepChecklist<Result: View>: View {
    private let title: LocalizedStringKey
    private let systemImage: String
    private let steps: [CYChecklistStep]
    private let tint: Color
    private let startTitle: LocalizedStringKey
    private let onStart: ((String) -> Void)?
    private let onReset: (() -> Void)?
    private let result: Result
    @State private var doneExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: LocalizedStringKey, systemImage: String, steps: [CYChecklistStep], tint: Color = CYColor.brand,
         startTitle: LocalizedStringKey = "comp.steps.start", onStart: ((String) -> Void)? = nil,
         onReset: (() -> Void)? = nil, @ViewBuilder result: () -> Result) {
        self.title = title; self.systemImage = systemImage; self.steps = steps; self.tint = tint
        self.startTitle = startTitle; self.onStart = onStart; self.onReset = onReset; self.result = result()
    }

    private var doneSteps: [CYChecklistStep] { steps.filter { $0.state == .done } }
    private var openSteps: [CYChecklistStep] { steps.filter { $0.state != .done } }
    private var currentID: String? { CYStepChecklistMath.currentID(steps) }
    private var allDone: Bool { !steps.isEmpty && doneSteps.count == steps.count }
    private var fraction: Double { CYStepChecklistMath.fraction(steps) }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            header
            ForEach(openSteps) { step in openRow(step) }
            if !doneSteps.isEmpty { doneSection }
            if allDone { result.transition(resultTransition) }
            if let onReset, !doneSteps.isEmpty {
                Button(role: .destructive) { onReset() } label: {
                    Label("comp.steps.reset", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .cyText(.label)
                .accessibilityLabel(Text("comp.steps.reset"))
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: steps)
        .accessibilityElement(children: .contain)
    }

    private var resultTransition: AnyTransition { reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity) }

    private var header: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text("comp.steps.progress \(doneSteps.count) \(steps.count)")
                    .cyText(.meta, monospacedDigit: true)
                    .foregroundStyle(CYColor.textSecondary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: CYSpacing.sm)
            CYRing(progress: fraction, label: title, tint: tint, diameter: 44, lineWidth: 5)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func openRow(_ step: CYChecklistStep) -> some View {
        let isCurrent = step.id == currentID
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: step.state == .locked ? "lock.fill" : (isCurrent ? "circle.inset.filled" : "circle"))
                .foregroundStyle(isCurrent ? tint : CYColor.textTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: step.title)
                    .cyText(isCurrent ? .bodyMedium : .body)
                    .foregroundStyle(step.state == .locked ? CYColor.textTertiary : CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if isCurrent, let status = step.detail {
                    Label {
                        Text(verbatim: status)
                    } icon: {
                        ProgressView().controlSize(.mini)
                    }
                    .cyText(.caption)
                    .foregroundStyle(tint)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            if let onStart, step.state != .locked, step.startable {
                if isCurrent {
                    Button(startTitle) { onStart(step.id) }
                        .buttonStyle(.borderedProminent)
                        .tint(tint)
                        .controlSize(.small)
                        .accessibilityLabel(Text(startTitle) + Text(verbatim: " · " + step.title))
                } else {
                    Button(startTitle) { onStart(step.id) }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel(Text(startTitle) + Text(verbatim: " · " + step.title))
                }
            }
        }
        .padding(isCurrent ? CYSpacing.sm : 0)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(tint.opacity(0.12))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(stateKey(step, current: isCurrent)))
    }

    private var doneSection: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) { doneExpanded.toggle() }
            } label: {
                HStack {
                    Text("comp.steps.done \(doneSteps.count)").cyText(.label)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(doneExpanded ? 0 : -90))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(CYColor.textSecondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityLabel(Text("comp.steps.done \(doneSteps.count)"))
            .accessibilityValue(Text(doneExpanded ? "comp.steps.expanded" : "comp.steps.collapsed"))
            if doneExpanded {
                ForEach(doneSteps) { step in doneRow(step) }
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func doneRow(_ step: CYChecklistStep) -> some View {
        HStack(spacing: CYSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(CYColor.successText)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : doneSteps.count)
                .accessibilityHidden(true)
            Text(verbatim: step.title)
                .cyText(.body)
                .foregroundStyle(CYColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: CYSpacing.sm)
            if let summary = step.detail {
                Text(verbatim: summary).cyText(.caption).foregroundStyle(CYColor.textTertiary).lineLimit(1)
            } else if let symbol = step.thumbnailSymbol {
                Image(systemName: symbol)
                    .foregroundStyle(tint)
                    .frame(width: 28, height: 28)
                    .background(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).fill(tint.opacity(0.12)))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("comp.steps.state.done"))
    }

    private func stateKey(_ step: CYChecklistStep, current: Bool) -> LocalizedStringKey {
        if current { return "comp.steps.state.current" }
        switch step.state {
        case .done: return "comp.steps.state.done"
        case .locked: return "comp.steps.state.locked"
        case .current, .todo: return "comp.steps.state.todo"
        }
    }
}

extension CYStepChecklist where Result == EmptyView {
    init(_ title: LocalizedStringKey, systemImage: String, steps: [CYChecklistStep], tint: Color = CYColor.brand,
         startTitle: LocalizedStringKey = "comp.steps.start", onStart: ((String) -> Void)? = nil,
         onReset: (() -> Void)? = nil) {
        self.init(title, systemImage: systemImage, steps: steps, tint: tint, startTitle: startTitle,
                  onStart: onStart, onReset: onReset) { EmptyView() }
    }
}

/// The final result card a checklist shows once every step is done.
struct CYStepChecklistResultCard: View {
    let title: LocalizedStringKey
    var message: String? = nil
    var systemImage: String = "checkmark.seal.fill"
    var tint: Color = CYColor.successText
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                if let message { Text(verbatim: message).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.md)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(tint.opacity(0.12)))
        .accessibilityElement(children: .combine)
    }
}

#Preview("CYStepChecklist") {
    let steps: [CYChecklistStep] = [
        .init(id: "basic", title: "基本信息", state: .done, detail: "苏州河夜行"),
        .init(id: "content", title: "活动内容", state: .current, detail: "生成中…"),
        .init(id: "ticket", title: "票务与合作", state: .todo)
    ]
    return ScrollView {
        CYStepChecklist("comp.steps.preview", systemImage: "square.and.pencil", steps: steps,
                        onStart: { _ in }, onReset: { }) {
            CYStepChecklistResultCard(title: "comp.steps.allDone")
        }
        .cyCard()
        .padding()
    }
    .cyDomainPageBackground()
    .themeDomain(.player)
}

// Design pass me: header-only variant for wizards that keep their own step buttons.

/// The checklist header on its own (icon, title, "2 of 5 complete", ring that becomes a bouncing checkmark), for
/// wizards that keep their own step pages but should still say where the player is (P4).
struct CYStepProgressHeader: View {
    private let title: Text
    private let systemImage: String
    private let done: Int
    private let total: Int
    private let tint: Color
    private let identifier: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(_ title: Text, systemImage: String, done: Int, total: Int, tint: Color = .accentColor, identifier: String = "cy.steps.header") {
        self.title = title
        self.systemImage = systemImage
        self.done = max(0, min(done, total))
        self.total = max(total, 0)
        self.tint = tint
        self.identifier = identifier
    }

    private var isFinished: Bool { total > 0 && done == total }

    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(minWidth: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Text("comp.steps.progress \(done) \(total)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(done)))
            }
            Spacer(minLength: CYSpacing.sm)
            CYRing(progress: CYRingMath.fraction(done, of: total), label: "comp.steps.ring", tint: tint, diameter: 40, lineWidth: 5) {
                ringCenter
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(Text("comp.steps.progress \(done) \(total)"))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var ringCenter: some View {
        if isFinished {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : done)
                .accessibilityHidden(true)
        } else {
            Text(verbatim: "\(done)/\(total)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: Double(done)))
                .accessibilityHidden(true)
        }
    }
}
