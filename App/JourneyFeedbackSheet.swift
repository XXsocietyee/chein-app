import SwiftUI

/// §九 U08-02 post-game problem feedback, opened from the battle report.
/// Category + optional stop + text go to `POST /api/play/feedback/submit` tied to this run.
/// No answers, private clues or photos are attached. Only a server receipt says "received";
/// an unknown answer locks the text and offers the same-request check, never a fresh send.
@MainActor struct JourneyFeedbackSheet: View {
    let nodes: [JourneyNodeRow]
    let state: JourneyFeedbackState
    let onSubmit: (PostGameFeedbackCategory, String?, String) -> Void
    let onRecheck: () -> Void
    let onReset: () -> Void
    let onClose: () -> Void

    @State private var category: PostGameFeedbackCategory = .place
    @State private var nodeID: String?
    @State private var text = ""
    @Environment(\.offlineWriteSession) private var offlineWriteSession

    private var locked: Bool {
        switch state {
        case .sending, .unconfirmed: true
        default: false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    if case .received = state { received } else { form }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
            }
            .background(CYNight.ink0)
            .navigationTitle(Text("mp.feedback.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.close", action: onClose).accessibilityIdentifier("journeyFeedback.close")
                }
            }
        }
        .cySheet(detents: [.large])
    }

    @ViewBuilder private var form: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text("mp.feedback.category").cyText(.label).foregroundStyle(CYColor.textSecondary)
            Picker(selection: $category) {
                Text("mp.feedback.category.place").tag(PostGameFeedbackCategory.place)
                Text("mp.feedback.category.question").tag(PostGameFeedbackCategory.question)
                Text("mp.feedback.category.other").tag(PostGameFeedbackCategory.other)
            } label: { Text("mp.feedback.category") }
            .pickerStyle(.segmented)
            .disabled(locked)
            .accessibilityIdentifier("journeyFeedback.category")
        }
        if !nodes.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("mp.feedback.node").cyText(.label).foregroundStyle(CYColor.textSecondary)
                Picker(selection: $nodeID) {
                    Text("mp.feedback.node.none").tag(String?.none)
                    ForEach(nodes) { node in
                        (node.name.map { Text(verbatim: $0) } ?? Text("mp.report.node")).tag(Optional(node.id))
                    }
                } label: { Text("mp.feedback.node") }
                .pickerStyle(.menu)
                .tint(CYColor.textPrimary)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .disabled(locked)
                .accessibilityIdentifier("journeyFeedback.node")
            }
        }
        VStack(alignment: .trailing, spacing: CYSpacing.xs) {
            TextField(text: $text, axis: .vertical) { Text("mp.feedback.placeholder") }
                .lineLimit(4...8)
                .padding(CYSpacing.lg)
                .background(CYNight.ink1, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .disabled(locked)
                .onChange(of: text) { _, value in
                    let scalars = value.unicodeScalars
                    if scalars.count > PostGameFeedbackDraft.maxContent {
                        text = String(String.UnicodeScalarView(scalars.prefix(PostGameFeedbackDraft.maxContent)))
                    }
                }
                .accessibilityLabel(Text("mp.feedback.text"))
                .accessibilityIdentifier("journeyFeedback.text")
            Text("mp.feedback.count \(text.unicodeScalars.count) \(PostGameFeedbackDraft.maxContent)")
                .cyText(.caption).monospacedDigit().foregroundStyle(CYColor.textTertiary)
        }
        status
        CYScreenOfflineWriteBanner(
            routes: ["/api/play/feedback/submit"],
            session: offlineWriteSession.session
        )
        footer
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .editing(let problem?):
            MPInlineError(text: problemText(problem)).accessibilityIdentifier("journeyFeedback.problem")
        case .unconfirmed:
            MPInlineError(text: Text("mp.feedback.unconfirmed")).accessibilityIdentifier("journeyFeedback.unconfirmed")
        case .refused(let message):
            MPInlineError(text: message.map { Text(verbatim: $0) } ?? Text("mp.feedback.refused"))
                .accessibilityIdentifier("journeyFeedback.refused")
        default:
            EmptyView()
        }
    }

    @ViewBuilder private var footer: some View {
        switch state {
        case .sending:
            HStack(spacing: CYSpacing.sm) {
                ProgressView()
                Text("mp.feedback.sending").cyText(.label)
            }
            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journeyFeedback.sending")
        case .unconfirmed:
            CYPillButton("mp.feedback.recheck", action: onRecheck).accessibilityIdentifier("journeyFeedback.recheck")
        default:
            CYPillButton("mp.feedback.submit") { onSubmit(category, nodeID, text) }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("journeyFeedback.submit")
        }
    }

    private var received: some View {
        VStack(spacing: CYSpacing.lg) {
            Image(systemName: "checkmark.circle").font(CYTypography.dataXL).foregroundStyle(CYNight.lantern)
                .accessibilityHidden(true)
            Text("mp.feedback.received").cyText(.bodyMedium).multilineTextAlignment(.center)
                .accessibilityIdentifier("journeyFeedback.received")
            HStack(spacing: CYSpacing.md) {
                CYPillButton("mp.feedback.another", style: .secondary) {
                    text = ""; nodeID = nil; onReset()
                }
                .accessibilityIdentifier("journeyFeedback.another")
                CYPillButton("action.done", action: onClose).accessibilityIdentifier("journeyFeedback.done")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, CYSpacing.xl)
    }

    private func problemText(_ problem: PostGameFeedbackDraft.Problem) -> Text {
        switch problem {
        case .empty: Text("mp.feedback.problem.empty")
        case .tooLong: Text("mp.feedback.problem.tooLong")
        case .noRun, .badNode: Text("mp.feedback.refused")
        }
    }
}
