import SwiftUI

/// One row of a `CYStepChecklist`.
struct CYStepChecklistItem: Identifiable {
    enum State: Equatable { case done, current, todo }

    let id: String
    let title: Text
    let systemImage: String
    var state: State
    /// Done rows: a one-line summary on the trailing side ("周六 14:00 · 外滩"). Current row: ignored.
    var summary: Text? = nil
    /// Current row: what is happening now in words ("生成中…" / "Saving…"); shown with a small spinner (P10).
    var liveStatus: Text? = nil
    /// Start / open this step. Nil hides the button (the step is reached by its own flow).
    var action: (() -> Void)? = nil
}

/// R-steps (@dimtri_G step checklist): header with icon, title, "2 of 5 complete" and a progress ring; the current
/// step highlighted with the one primary Start (P3) and a live status line (P10); remaining steps with a quiet
/// secondary Start; finished steps folded into a collapsible "已完成 (n)" section, each with a one-line summary on
/// the trailing side (P4); optional Reset. Completion: the ring turns into a checkmark and bounces (P7).
/// Native: `DisclosureGroup`, `Button` styles, `ProgressView`, SF Symbols `symbolEffect`; Reduce Motion drops the
/// spring and bounce. VoiceOver: the header is one element ("Getting started, 2 of 5 complete"); the current row is
/// marked selected. Design pass me (components r1 R-steps).
struct CYStepChecklist: View {
    private let title: Text
    private let systemImage: String
    private let items: [CYStepChecklistItem]
    private let tint: Color
    private let startTitle: LocalizedStringKey
    private let onReset: (() -> Void)?
    private let identifier: String
    @State private var showsCompleted: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        _ title: Text,
        systemImage: String,
        items: [CYStepChecklistItem],
        tint: Color = .accentColor,
        startTitle: LocalizedStringKey = "comp.steps.start",
        showsCompletedInitially: Bool = false,
        identifier: String = "cy.steps",
        onReset: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.items = items
        self.tint = tint
        self.startTitle = startTitle
        self.identifier = identifier
        self.onReset = onReset
        _showsCompleted = State(initialValue: showsCompletedInitially)
    }

    private var done: [CYStepChecklistItem] { items.filter { $0.state == .done } }
    private var open: [CYStepChecklistItem] { items.filter { $0.state != .done } }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            header
            ForEach(open) { item in
                row(item)
            }
            if !done.isEmpty {
                completedSection
            }
            if let onReset, !done.isEmpty {
                Button("comp.steps.reset", role: .destructive, action: onReset)
                    .font(.footnote)
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier(identifier + ".reset")
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.2), value: done.count)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }

    // MARK: Header

    private var header: some View {
        CYStepProgressHeader(title, systemImage: systemImage, done: done.count, total: items.count, tint: tint,
                             identifier: identifier + ".header")
    }

    // MARK: Open rows

    @ViewBuilder
    private func row(_ item: CYStepChecklistItem) -> some View {
        let isCurrent = item.state == .current
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.md) {
                rowLabel(item, isCurrent: isCurrent)
                Spacer(minLength: CYSpacing.sm)
                startButton(item, isCurrent: isCurrent)
            }
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                rowLabel(item, isCurrent: isCurrent)
                startButton(item, isCurrent: isCurrent)
            }
        }
        .padding(.vertical, isCurrent ? CYSpacing.md : CYSpacing.xs)
        .padding(.horizontal, isCurrent ? CYSpacing.md : 0)
        .background {
            if isCurrent {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.12))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityIdentifier(identifier + ".step." + item.id)
    }

    private func rowLabel(_ item: CYStepChecklistItem, isCurrent: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Image(systemName: isCurrent ? item.systemImage : "circle")
                .symbolVariant(isCurrent ? .fill : .none)
                .foregroundStyle(isCurrent ? tint : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                item.title
                    .font(isCurrent ? .body.weight(.semibold) : .body)
                    .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if isCurrent, let status = item.liveStatus {
                    HStack(spacing: CYSpacing.xs) {
                        ProgressView()
                            .controlSize(.mini)
                            .accessibilityHidden(true)
                        status
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier(identifier + ".status")
                }
            }
        }
    }

    @ViewBuilder
    private func startButton(_ item: CYStepChecklistItem, isCurrent: Bool) -> some View {
        if let action = item.action {
            if isCurrent {
                Button(action: action) { Text(startTitle) }
                    .buttonStyle(.borderedProminent)
                    .tint(tint)
                    .controlSize(.small)
                    .accessibilityIdentifier(identifier + ".start." + item.id)
            } else {
                Button(action: action) { Text(startTitle) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .accessibilityIdentifier(identifier + ".start." + item.id)
            }
        }
    }

    // MARK: Completed

    private var completedSection: some View {
        DisclosureGroup(isExpanded: $showsCompleted) {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                ForEach(done) { item in
                    completedRow(item)
                }
            }
            .padding(.top, CYSpacing.xs)
        } label: {
            Text("comp.steps.completed \(done.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText(value: Double(done.count)))
        }
        .tint(.secondary)
        .accessibilityIdentifier(identifier + ".completed")
    }

    private func completedRow(_ item: CYStepChecklistItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(tint)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : done.count)
                .accessibilityHidden(true)
            item.title
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: CYSpacing.sm)
            if let summary = item.summary {
                summary
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { item.action?() }
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("comp.steps.done"))
        .accessibilityAddTraits(item.action == nil ? [] : .isButton)
        .accessibilityIdentifier(identifier + ".done." + item.id)
    }
}

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

private struct CYStepChecklistPreviewBody: View {
    var body: some View {
        Form {
            Section {
                CYStepChecklist(
                    Text("comp.steps.preview.title"),
                    systemImage: "sparkles",
                    items: [
                        CYStepChecklistItem(id: "a", title: Text("publishModes.wizard.step.basic"), systemImage: "info.circle", state: .done,
                                            summary: Text(verbatim: "Sat 14:00 · The Bund"), action: {}),
                        CYStepChecklistItem(id: "b", title: Text("publishModes.wizard.step.content"), systemImage: "photo", state: .current,
                                            liveStatus: Text("comp.steps.status.saving"), action: {}),
                        CYStepChecklistItem(id: "c", title: Text("publishModes.wizard.step.ticket"), systemImage: "ticket", state: .todo, action: {}),
                    ],
                    showsCompletedInitially: true,
                    onReset: {}
                )
            }
        }
    }
}
#Preview("StepChecklist · player") { CYStepChecklistPreviewBody().themeDomain(.player) }
