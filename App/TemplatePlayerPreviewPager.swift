import SwiftUI

/// Screens r4 · Figma 238:25435 – 238:25821 `PlayerPreviewView` (CF-63, C2 A12). The creator's one look at how the
/// gameplay feels to a player: five steps (到达 · 剧情 · 任务 · 成功 · 失败) chosen with a segmented control, paged by
/// swipe or a tap on the content. Native r2: system controls only; the moments keep their haptics
/// (`.sensoryFeedback`): correct pick `.success`, wrong pick and 失败 `.error`, the medal `.impact(weight: .heavy)`.
/// The nav (玩家视角预览 + ✕) stays on all five steps (owned by the sheet).
struct TemplatePlayerPreviewPager: View {
    enum Step: Int, CaseIterable, Identifiable {
        case arrival, story, task, success, failure
        var id: Int { rawValue }
        var titleKey: String {
            switch self {
            case .arrival: return "config.preview.step.arrival"
            case .story: return "config.preview.step.story"
            case .task: return "config.preview.step.task"
            case .success: return "config.preview.step.success"
            case .failure: return "config.preview.step.failure"
            }
        }
    }

    let draft: TemplateAuthoringDraft

    @State private var step: Step = .arrival

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            progress
            TabView(selection: $step) {
                ForEach(Step.allCases) { item in
                    page(item)
                        .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 340)
            .animation(.default, value: step)
        }
        .accessibilityIdentifier("config.preview.pager")
    }

    // MARK: Steps (segmented control; each step tappable)

    private var progress: some View {
        Picker(selection: $step) {
            ForEach(Step.allCases) { item in
                ConfigR4Text.text(item.titleKey).tag(item)
            }
        } label: { ConfigR4Text.text(step.titleKey) }
        .cyAdaptiveSegmented()
    }

    // MARK: Pages

    @ViewBuilder private func page(_ item: Step) -> some View {
        let isCurrent = item == step
        switch item {
        case .arrival:
            PlayerPreviewArrivalPage(draft: draft, isCurrent: isCurrent) { advance(from: item) }
        case .story:
            PlayerPreviewStoryPage(draft: draft, isCurrent: isCurrent) { advance(from: item) }
        case .task:
            PlayerPreviewTaskPage(draft: draft, isCurrent: isCurrent) { correct in step = correct ? .success : .failure }
        case .success:
            PlayerPreviewSuccessPage(draft: draft, isCurrent: isCurrent) { advance(from: item) }
        case .failure:
            PlayerPreviewFailurePage(isCurrent: isCurrent) { step = .task }
        }
    }

    private func advance(from item: Step) {
        guard let next = Step(rawValue: item.rawValue + 1) else { return }
        step = next
    }
}

// MARK: - Shared pieces

/// The page content inside the host's form row (no card chrome of its own). Tapping it skips to the next beat.
private struct PlayerPreviewCard<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

private struct PlayerPreviewTapHint: View {
    var body: some View {
        ConfigR4Text.text("config.preview.tapHint")
            .font(.footnote)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
    }
}

// MARK: - 到达

private struct PlayerPreviewArrivalPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let next: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: next) {
                PlayerPreviewCard {
                    Label { ConfigR4Text.text("config.preview.arrived") } icon: { Image(systemName: "mappin.and.ellipse") }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    title
                    if !draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: draft.description)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            PlayerPreviewTapHint()
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var title: some View {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            ConfigR4Text.text("config.preview.untitled").font(.title3.bold()).foregroundStyle(.tertiary)
        } else {
            Text(verbatim: trimmed).font(.title3.bold()).foregroundStyle(.primary)
        }
    }
}

// MARK: - 剧情

private struct PlayerPreviewStoryPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let next: () -> Void
    @State private var revealed = 0

    private var beats: [String] {
        guard draft.storyEnabled else { return [] }
        let fromBeats = ((try? draft.storyBeats()) ?? []).map(\.text).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if !fromBeats.isEmpty { return fromBeats }
        if let story = try? draft.preparedStoryText(), !story.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return [story] }
        return []
    }

    var body: some View {
        let lines = beats
        VStack(spacing: 12) {
            Button {
                // Tap skips: reveal everything, then the next tap moves on.
                if revealed < lines.count { revealed = lines.count } else { next() }
            } label: {
                PlayerPreviewCard {
                    if lines.isEmpty {
                        ConfigR4Text.text("config.preview.story.none")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(verbatim: line)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .opacity(index < revealed ? 1 : 0)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            PlayerPreviewTapHint()
            Spacer(minLength: 0)
        }
        .onAppear { if isCurrent { revealed = lines.count } }
        .onChange(of: isCurrent) { _, current in revealed = current ? lines.count : 0 }
    }
}

// MARK: - 任务

private struct PlayerPreviewTaskPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let resolved: (_ correct: Bool) -> Void
    @State private var picked: String?
    @State private var correctTicks = 0
    @State private var wrongTicks = 0

    private struct Option: Identifiable { let letter: String; let text: String; var id: String { letter } }

    private var options: [Option] {
        let raw: [(String, String?)] = [("A", draft.questionA), ("B", draft.questionB), ("C", draft.questionC), ("D", draft.questionD)]
        return raw.compactMap { letter, text in
            guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            return Option(letter: letter, text: text)
        }
    }

    private var answer: String? {
        guard let raw = draft.correctAnswer?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), !raw.isEmpty else { return nil }
        return raw
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlayerPreviewCard {
                Label { Text(LocalizedStringKey(draft.validationMethod.labelKey)) } icon: {
                    Image(systemName: TemplateGameplayPickerSheet.symbol(draft.validationMethod))
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let question = draft.questionName?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty {
                    Text(verbatim: question).font(.headline)
                }
                if draft.validationMethod == .choice, !options.isEmpty {
                    ConfigR4Text.text("config.preview.task.pick").font(.footnote).foregroundStyle(.tertiary)
                    ForEach(options) { option in tile(option) }
                } else {
                    HStack(spacing: 8) {
                        Button { resolved(true) } label: { ConfigR4Text.text("config.preview.task.showSuccess") }
                        Button { resolved(false) } label: { ConfigR4Text.text("config.preview.task.showFailure") }
                    }
                    .buttonStyle(.bordered)
                }
            }
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.success, trigger: correctTicks)
        .sensoryFeedback(.error, trigger: wrongTicks)
        .onChange(of: isCurrent) { _, current in if current { picked = nil } }
    }

    private func tile(_ option: Option) -> some View {
        let isPicked = picked == option.letter
        let isCorrect = answer == option.letter
        return Button { pick(option.letter) } label: {
            HStack(spacing: 12) {
                Text(verbatim: option.letter).foregroundStyle(.secondary)
                Text(verbatim: option.text).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isPicked {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? CYColor.successText : CYColor.dangerText)
                }
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(picked != nil)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private func pick(_ letter: String) {
        let correct = answer == letter
        picked = letter
        if correct { correctTicks += 1 } else { wrongTicks += 1 }
        // Let the result read for a beat, then move to the matching outcome page.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard picked == letter, isCurrent else { return }
            resolved(correct)
        }
    }
}

// MARK: - 成功

private struct PlayerPreviewSuccessPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let next: () -> Void
    @State private var landings = 0

    private var medal: String? {
        guard draft.rewardEnabled, let name = draft.medalName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return name
    }

    var body: some View {
        VStack(spacing: 12) {
            Button(action: next) {
                PlayerPreviewCard {
                    Label { ConfigR4Text.text("config.preview.success.title") } icon: {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    .font(.title3.bold())
                    if let feedback = draft.feedbackText?.trimmingCharacters(in: .whitespacesAndNewlines), !feedback.isEmpty {
                        Text(verbatim: feedback).foregroundStyle(.secondary)
                    }
                    if let medal {
                        Label { Text(verbatim: medal) } icon: { Image(systemName: "rosette") }
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
            PlayerPreviewTapHint()
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: landings)
        .onAppear { if isCurrent, medal != nil { landings += 1 } }
        .onChange(of: isCurrent) { _, current in if current, medal != nil { landings += 1 } }
    }
}

// MARK: - 失败

private struct PlayerPreviewFailurePage: View {
    let isCurrent: Bool
    let retry: () -> Void
    @State private var shakes = 0

    var body: some View {
        VStack(spacing: 12) {
            PlayerPreviewCard {
                Label { ConfigR4Text.text("config.preview.failure.title") } icon: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
                .font(.title3.bold())
                ConfigR4Text.text("config.preview.failure.detail")
                    .foregroundStyle(.secondary)
                Button(action: retry) { ConfigR4Text.text("config.preview.retry") }
                    .buttonStyle(.bordered)
            }
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.error, trigger: shakes)
        .onChange(of: isCurrent) { _, current in
            guard current else { return }
            shakes += 1
        }
    }
}
