import SwiftUI

@MainActor final class PublishingAIPromptController: ObservableObject {
    @Published private var generation = UUID()
    private var active = false
    func activate() { generation = UUID(); active = true }
    func retire() { active = false; generation = UUID() }
    func canSelect(in flow: PublishingAIDraftFlow) -> Bool { active && flow.canUseIdeaSuggestion }
    func action(_ suggestion: PublishingAIPromptSuggestion, languageCode: String,
                flow: PublishingAIDraftFlow, applied: @escaping () -> Void = {}) -> () -> Void {
        let token = generation
        let select = flow.ideaSuggestionAction(suggestion,languageCode:languageCode)
        return { [weak self, weak flow] in
            guard let self, let flow, token == self.generation, self.canSelect(in:flow), select() else { return }
            self.generation = UUID(); applied()
        }
    }
}

/// The Form row renders actions only. Its recycling never retires the stable sheet owner.
@MainActor struct PublishingAIPromptControls: View {
    @ObservedObject var controller: PublishingAIPromptController
    let flow: PublishingAIDraftFlow
    let applied: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var body: some View {
        if flow.candidate == nil {
            VStack(alignment: .leading, spacing: Theme.Space.s2) {
                Text("creatorAIPrompts.title",tableName:"CreatorAIPrompts")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: Theme.Space.s2) {
                        promptButtons(fullWidth: true)
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.Space.s2) {
                            promptButtons(fullWidth: false)
                        }
                        .padding(.vertical, CYSpacing.xxs)
                    }
                }
            }.accessibilityIdentifier("creatorAIPrompts.options")
        }
    }
    @ViewBuilder private func promptButtons(fullWidth: Bool) -> some View {
        ForEach(PublishingAIPromptSuggestion.allCases) { suggestion in
            Button(action:controller.action(suggestion,languageCode:locale.identifier,flow:flow,applied:applied)) {
                Label {
                    Text(LocalizedStringKey(suggestion.titleKey),tableName:"CreatorAIPrompts")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName:"sparkles")
                        .accessibilityHidden(true)
                }
                .font(.subheadline)
                .frame(maxWidth: fullWidth ? .infinity : nil, alignment: .leading)
            }.buttonStyle(.bordered).buttonBorderShape(.capsule).disabled(!controller.canSelect(in:flow))
                .accessibilityIdentifier("creatorAIPrompts.select." + suggestion.rawValue)
        }
    }
}

@MainActor struct PublishingAIPromptLifetime: ViewModifier {
    @ObservedObject var controller: PublishingAIPromptController
    @Environment(\.scenePhase) private var scenePhase
    func body(content: Content) -> some View {
        content
            .onAppear { if scenePhase == .active { controller.activate() } else { controller.retire() } }
            .onChange(of:scenePhase) { _,phase in
                if phase == .active { controller.activate() } else { controller.retire() }
            }
            .onDisappear { controller.retire() }
    }
}
