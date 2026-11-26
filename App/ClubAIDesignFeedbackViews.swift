import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor final class ClubAIDesignFeedbackModel: ObservableObject {
    @Published private(set) var revision = 0
    private(set) var state = ClubAIDesignFeedbackState()
    func bind(_ context: ClubAIDesignFeedbackContext) { state.bind(context) }
    func appear() { state.appear(); revision += 1 }
    func leave() { state.leave(); revision += 1 }
    func copy(_ permit: ClubAIDesignFeedbackState.Permit,
              current: () -> ClubAIDesignFeedbackContext?,
              generating: () -> Bool,
              write: (String) -> Bool) {
        guard let before = current(), let attempt = state.beginCopy(permit, current: before, generating: generating()) else { return }
        revision += 1
        let succeeded = write(attempt.text)
        state.completeCopy(attempt, succeeded: succeeded, current: current(), generating: generating())
        revision += 1
    }
    static func writeClipboard(_ text: String) -> Bool {
        #if canImport(UIKit)
        let board = UIPasteboard.general
        let before = board.changeCount
        // changeCount is not pasteboard content. hasStrings would be a content probe.
        LocalPasteboard.copy(text, to: board)
        return board.changeCount != before
        #else
        return false
        #endif
    }
}

/// Embedded in the club AI form. The parent screen owns `context.ai.title`; chips stay secondary.
@MainActor struct ClubAIDesignIdeaChips: View {
    let clubID: Int
    let session: PublishingSession?
    @Binding var idea: String
    @Binding var operationID: UUID
    @Binding var generating: Bool
    @Environment(\.scenePhase) private var scenePhase
    @QuestifyReduceMotion private var reduceMotion
    @StateObject private var model = ClubAIDesignFeedbackModel()
    private var context: ClubAIDesignFeedbackContext {
        .init(clubID: clubID, session: session, operationID: operationID)
    }
    var body: some View {
        let value = context
        let _ = model.revision
        let _ = model.bind(value)
        let permit = model.state.permit(value, generating: generating)
        // One row: a caption, then each idea as a small system bordered button.
        VStack(alignment: .leading, spacing: 8) {
            Text("club.aiFeedback.ideas")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            ForEach(ClubAIDesignIdea.allCases) { chip in
                Button {
                    guard scenePhase == .active, let permit,
                          let replacement = model.state.choose(chip, permit: permit, current: context, generating: generating) else { return }
                    if !reduceMotion { CYHaptics.selection.play() }
                    idea = replacement
                } label: { Label(chip.text, systemImage: "sparkles") }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(permit == nil || scenePhase != .active)
                .accessibilityIdentifier("club.aiFeedback.idea." + chip.rawValue)
                .accessibilityLabel(Text(verbatim: chip.text))
                .accessibilityHint(Text("club.aiFeedback.ideas"))
            }
        }
        .padding(.vertical, 4)
        .themeDomain(.player)
        .onAppear { model.appear() }
        .onDisappear { model.leave() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.appear() } else { model.leave() }
        }
    }
}

@MainActor enum ClubAIDesignPromoSnapshot {
    static func current(clubID: Int, session: PublishingSession?, operationID: UUID,
                        generating: Bool, flow: ClubAIDesignFlow,
                        expectedGeneration: Int, expectedCopy: String) -> ClubAIDesignFeedbackContext? {
        // result asks the flow's live identity provider; a cached session alone is insufficient.
        guard !generating, !flow.busy, let result = flow.result,
              flow.resultGeneration == expectedGeneration,
              result.promoCopy.utf8.elementsEqual(expectedCopy.utf8), !expectedCopy.isEmpty else { return nil }
        return .init(clubID: clubID, session: session, operationID: operationID,
                     resultGeneration: expectedGeneration, promoCopy: expectedCopy)
    }
}

/// Embedded copy row. Adopt/generate on the parent stays the screen's primary; copy is secondary.
@MainActor struct ClubAIDesignPromoFeedback: View {
    let clubID: Int
    let session: PublishingSession?
    let flow: ClubAIDesignFlow
    let resultGeneration: Int
    let promoCopy: String
    @Binding var operationID: UUID
    @Binding var generating: Bool
    @Environment(\.scenePhase) private var scenePhase
    @QuestifyReduceMotion private var reduceMotion
    @StateObject private var model = ClubAIDesignFeedbackModel()
    private var context: ClubAIDesignFeedbackContext {
        .init(clubID: clubID, session: session, operationID: operationID,
              resultGeneration: resultGeneration, promoCopy: promoCopy)
    }
    private func current() -> ClubAIDesignFeedbackContext? {
        guard scenePhase == .active else { return nil }
        return ClubAIDesignPromoSnapshot.current(clubID: clubID, session: session,
            operationID: operationID, generating: generating, flow: flow,
            expectedGeneration: resultGeneration, expectedCopy: promoCopy)
    }
    var body: some View {
        let value = context
        let _ = model.revision
        let _ = model.bind(value)
        let permit = model.state.permit(value, generating: generating)
        if !promoCopy.isEmpty {
            Section {
                Button {
                    guard let permit else { return }
                    model.copy(permit, current: current, generating: { generating }, write: ClubAIDesignFeedbackModel.writeClipboard)
                    if !reduceMotion {
                        if model.state.phase == .copied { CYHaptics.success.play() }
                        if model.state.phase == .failed { CYHaptics.warning.play() }
                    }
                } label: { Label("club.aiFeedback.copy", systemImage: "doc.on.doc") }
                .disabled(permit == nil || current() == nil || model.state.phase == .copying)
                .accessibilityIdentifier("club.aiFeedback.copy")
                .accessibilityLabel(Text("club.aiFeedback.copy"))
                if current() != nil {
                    if model.state.phase == .copied {
                        Label { Text("club.aiFeedback.copied") } icon: { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityIdentifier("club.aiFeedback.copied")
                            .accessibilityLabel(Text("club.aiFeedback.copied"))
                    }
                    if model.state.phase == .failed {
                        Label {
                            Text("club.aiFeedback.failed")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange).accessibilityHidden(true)
                        }
                        .accessibilityIdentifier("club.aiFeedback.failed")
                    }
                }
            }
            .themeDomain(.player)
            .cyAnimation(value: model.revision)
            .onAppear { model.appear() }
            .onDisappear { model.leave() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.appear() } else { model.leave() }
            }
        }
    }
}
