import SwiftUI

/// Screens r4 · Figma 238:25435 – 238:25821 `PlayerPreviewView` (CF-63, C2 A12). The creator's one look at how the
/// gameplay feels to a player: five steps (到达 · 剧情 · 任务 · 成功 · 失败) under a five-segment progress bar, paged by
/// swipe or a tap on the content. Each step plays its real moment once when it becomes current, and a tap skips it:
/// - step change: the pager slides; the progress segment fills on `CYMotion.standard` (220–300 ms); no haptic;
/// - 到达: the arrival card rises 24 pt and fades in on `CYMotion.moment` (.42 / .8);
/// - 剧情: beats fade up 12 pt one by one (120 ms, then shrinking gaps);
/// - 任务 (选择题): a tile presses (.97), then resolves: correct → neutral border turns `success` and a check draws
///   (`.success`); wrong → the tile shakes 3 × 6 pt in 240 ms (`.error`);
/// - 成功: 任务完成 (no exclamation mark), the medal lands on the stamp spring `CYMotion.seal` with `.impactHeavy`;
/// - 失败: the card shakes once (`.error`).
/// Reduce Motion: fades only, haptics kept. The nav (玩家视角预览 + ✕) stays on all five steps (owned by the sheet).
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

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var step: Step = .arrival

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            progress
            TabView(selection: $step) {
                ForEach(Step.allCases) { item in
                    page(item)
                        .padding(.horizontal, CYSpacing.xxs)
                        .tag(item)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(minHeight: 340)
            .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: step)
        }
        .accessibilityIdentifier("config.preview.pager")
    }

    // MARK: Progress (five segments, each tappable)

    private var progress: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.xs) {
                ForEach(Step.allCases) { item in
                    Button { step = item } label: {
                        Capsule()
                            .fill(item.rawValue <= step.rawValue ? palette.selection : palette.borderSubtle)
                            .frame(height: 4)
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(ConfigR4Text.text(item.titleKey))
                    .accessibilityAddTraits(item == step ? .isSelected : [])
                }
            }
            .cyAnimation(CYMotion.standard, value: step)
            ConfigR4Text.text(step.titleKey)
                .cyText(.label)
                .foregroundStyle(palette.textSecondary)
                .contentTransition(.opacity)
        }
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

/// A content card on the page (content layer: no glass). Tapping it skips to the next beat.
private struct PlayerPreviewCard<Content: View>: View {
    @Environment(\.cyPalette) private var palette
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) { content }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.cardFill, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(palette.borderSubtle))
    }
}

private struct PlayerPreviewTapHint: View {
    @Environment(\.cyPalette) private var palette
    var body: some View {
        ConfigR4Text.text("config.preview.tapHint")
            .cyText(.meta)
            .foregroundStyle(palette.textTertiary)
            .frame(maxWidth: .infinity)
    }
}

/// Horizontal shake: `shakes` full swings of `amplitude` pt over one unit of `progress` (0 → 1).
struct PlayerPreviewShake: GeometryEffect {
    var amplitude: CGFloat = 6
    var shakes: CGFloat = 3
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amplitude * sin(progress * .pi * 2 * shakes), y: 0))
    }
}

private enum PlayerPreviewMotion {
    /// CF-63: the wrong-answer shake, 3 × 6 pt in 240 ms.
    static let shake = Animation.linear(duration: 0.24)
    /// CF-63 story beats: the first gap is the spec's 120 ms, later gaps shrink and the tail arrives together
    /// (emil choreograph: no uniform stagger; product UI total stays ~300 ms).
    static let beats: [Double] = [0, 0.12, 0.2, 0.26, 0.3]
}

// MARK: - 到达

private struct PlayerPreviewArrivalPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let next: () -> Void
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: CYSpacing.md) {
            Button(action: next) {
                PlayerPreviewCard {
                    Label { ConfigR4Text.text("config.preview.arrived") } icon: { Image(systemName: "mappin.and.ellipse") }
                        .cyText(.label)
                        .foregroundStyle(palette.textSecondary)
                    title
                    if !draft.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(verbatim: draft.description)
                            .cyText(.body)
                            .foregroundStyle(palette.textSecondary)
                    }
                }
            }
            .buttonStyle(.cyPressable)
            .offset(y: shown || reduceMotion ? 0 : 24)
            .opacity(shown ? 1 : 0)
            PlayerPreviewTapHint()
            Spacer(minLength: 0)
        }
        .onAppear { play() }
        .onChange(of: isCurrent) { _, current in
            if current { play() } else { var instant = Transaction(); instant.disablesAnimations = true; withTransaction(instant) { shown = false } }
        }
    }

    @ViewBuilder private var title: some View {
        let trimmed = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            ConfigR4Text.text("config.preview.untitled").cyText(.sectionTitle).foregroundStyle(palette.textTertiary)
        } else {
            Text(verbatim: trimmed).cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
        }
    }

    private func play() {
        guard isCurrent, !shown else { return }
        withAnimation(CYMotion.resolve(CYMotion.moment, reduceMotion: reduceMotion)) { shown = true }
    }
}

// MARK: - 剧情

private struct PlayerPreviewStoryPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let next: () -> Void
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
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
        VStack(spacing: CYSpacing.md) {
            Button {
                // Tap skips: reveal everything, then the next tap moves on.
                if revealed < lines.count { revealed = lines.count } else { next() }
            } label: {
                PlayerPreviewCard {
                    if lines.isEmpty {
                        ConfigR4Text.text("config.preview.story.none")
                            .cyText(.body)
                            .foregroundStyle(palette.textSecondary)
                    } else {
                        ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                            Text(verbatim: line)
                                .cyText(.body)
                                .foregroundStyle(palette.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .opacity(index < revealed ? 1 : 0)
                                .offset(y: index < revealed || reduceMotion ? 0 : 12)
                                .animation(beatAnimation(index), value: revealed)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            PlayerPreviewTapHint()
            Spacer(minLength: 0)
        }
        .onAppear { if isCurrent { revealed = lines.count } }
        .onChange(of: isCurrent) { _, current in
            if current { revealed = lines.count } else { var instant = Transaction(); instant.disablesAnimations = true; withTransaction(instant) { revealed = 0 } }
        }
    }

    /// Each beat fades up 220 ms after the one above it on `PlayerPreviewMotion.beats` (hiding is instant, off screen).
    private func beatAnimation(_ index: Int) -> Animation? {
        guard revealed > 0 else { return nil }
        return CYMotion.resolve(.easeOut(duration: CYMotion.Duration.quick), reduceMotion: reduceMotion)
            .delay(reduceMotion ? 0 : CYMotion.Stagger.delay(index, in: PlayerPreviewMotion.beats))
    }
}

// MARK: - 任务

private struct PlayerPreviewTaskPage: View {
    let draft: TemplateAuthoringDraft
    let isCurrent: Bool
    let resolved: (_ correct: Bool) -> Void
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var picked: String?
    /// Counts wrong picks; the shake animates one whole unit per pick (sin is 0 at every integer).
    @State private var shake: CGFloat = 0
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
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            PlayerPreviewCard {
                Label { Text(LocalizedStringKey(draft.validationMethod.labelKey)) } icon: {
                    Image(systemName: TemplateGameplayPickerSheet.symbol(draft.validationMethod))
                }
                .cyText(.label)
                .foregroundStyle(palette.textSecondary)
                if let question = draft.questionName?.trimmingCharacters(in: .whitespacesAndNewlines), !question.isEmpty {
                    Text(verbatim: question).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                }
                if draft.validationMethod == .choice, !options.isEmpty {
                    ConfigR4Text.text("config.preview.task.pick").cyText(.meta).foregroundStyle(palette.textTertiary)
                    ForEach(options) { option in tile(option) }
                } else {
                    HStack(spacing: CYSpacing.sm) {
                        Button { resolved(true) } label: { ConfigR4Text.text("config.preview.task.showSuccess") }
                        Button { resolved(false) } label: { ConfigR4Text.text("config.preview.task.showFailure") }
                    }
                    .buttonStyle(.bordered)
                    .tint(palette.textPrimary)
                    .cyText(.label)
                }
            }
            Spacer(minLength: 0)
        }
        .cyHaptic(.success, trigger: correctTicks)
        .cyHaptic(.error, trigger: wrongTicks)
        .onChange(of: isCurrent) { _, current in if current { picked = nil } }
    }

    private func tile(_ option: Option) -> some View {
        let isPicked = picked == option.letter
        let isCorrect = answer == option.letter
        let border: Color = isPicked ? (isCorrect ? palette.success : palette.danger) : palette.borderSubtle
        return Button { pick(option.letter) } label: {
            HStack(spacing: CYSpacing.md) {
                Text(verbatim: option.letter).cyText(.label).foregroundStyle(palette.textSecondary)
                Text(verbatim: option.text).cyText(.body).foregroundStyle(palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if isPicked && isCorrect {
                    Image(systemName: "checkmark")
                        .foregroundStyle(palette.success)
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, CYSpacing.md)
            .frame(minHeight: 52)
            .background(palette.inputIdleBg, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(border, lineWidth: isPicked ? 1.5 : 1))
            .modifier(PlayerPreviewShake(progress: isPicked && !isCorrect && !reduceMotion ? shake : 0))
        }
        .buttonStyle(.cyPressable)
        .disabled(picked != nil)
        .accessibilityAddTraits(isPicked ? .isSelected : [])
    }

    private func pick(_ letter: String) {
        let correct = answer == letter
        withAnimation(CYMotion.resolve(.easeOut(duration: CYMotion.Duration.quick), reduceMotion: reduceMotion)) { picked = letter }
        if correct { correctTicks += 1 } else {
            wrongTicks += 1
            if !reduceMotion { withAnimation(PlayerPreviewMotion.shake) { shake += 1 } }
        }
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
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var checkDrawn: CGFloat = 0
    @State private var medalLanded = false
    @State private var landings = 0

    private var medal: String? {
        guard draft.rewardEnabled, let name = draft.medalName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { return nil }
        return name
    }

    var body: some View {
        VStack(spacing: CYSpacing.md) {
            Button(action: next) {
                PlayerPreviewCard {
                    HStack(spacing: CYSpacing.md) {
                        ZStack {
                            Circle().strokeBorder(palette.success.opacity(0.35), lineWidth: 2)
                            PlayerPreviewCheckShape()
                                .trim(from: 0, to: checkDrawn)
                                .stroke(palette.success, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                .padding(CYSpacing.md)
                        }
                        .frame(width: 48, height: 48)
                        .accessibilityHidden(true)
                        ConfigR4Text.text("config.preview.success.title")
                            .cyText(.sectionTitle)
                            .foregroundStyle(palette.textPrimary)
                    }
                    if let feedback = draft.feedbackText?.trimmingCharacters(in: .whitespacesAndNewlines), !feedback.isEmpty {
                        Text(verbatim: feedback).cyText(.body).foregroundStyle(palette.textSecondary)
                    }
                    if let medal {
                        Label { Text(verbatim: medal) } icon: { Image(systemName: "rosette") }
                            .cyText(.label)
                            .foregroundStyle(palette.textPrimary)
                            .padding(.horizontal, CYSpacing.md)
                            .frame(minHeight: 32)
                            .background(palette.bgRaised, in: Capsule())
                            .scaleEffect(medalLanded || reduceMotion ? 1 : 0.6)
                            .opacity(medalLanded ? 1 : 0)
                    }
                }
            }
            .buttonStyle(.plain)
            PlayerPreviewTapHint()
            Spacer(minLength: 0)
        }
        .cyHaptic(.impactHeavy, trigger: landings)
        .onAppear { play() }
        .onChange(of: isCurrent) { _, current in
            if current { play() } else { var instant = Transaction(); instant.disablesAnimations = true; withTransaction(instant) { checkDrawn = 0; medalLanded = false } }
        }
    }

    private func play() {
        guard isCurrent, checkDrawn == 0 else { return }
        withAnimation(CYMotion.resolve(.easeOut(duration: CYMotion.Duration.quick), reduceMotion: reduceMotion)) { checkDrawn = 1 }
        guard medal != nil else { return }
        withAnimation(CYMotion.resolve(CYMotion.seal, reduceMotion: reduceMotion).delay(CYMotion.Duration.quick)) { medalLanded = true }
        Task { @MainActor in
            // Haptic at the stamp's peak, not at the start.
            try? await Task.sleep(nanoseconds: 380_000_000)
            if isCurrent { landings += 1 }
        }
    }
}

private struct PlayerPreviewCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

// MARK: - 失败

private struct PlayerPreviewFailurePage: View {
    let isCurrent: Bool
    let retry: () -> Void
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var shake: CGFloat = 0
    @State private var shakes = 0

    var body: some View {
        VStack(spacing: CYSpacing.md) {
            PlayerPreviewCard {
                Label { ConfigR4Text.text("config.preview.failure.title") } icon: { Image(systemName: "xmark.circle") }
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                ConfigR4Text.text("config.preview.failure.detail")
                    .cyText(.body)
                    .foregroundStyle(palette.textSecondary)
                Button(action: retry) { ConfigR4Text.text("config.preview.retry") }
                    .buttonStyle(.bordered)
                    .tint(palette.textPrimary)
                    .cyText(.label)
            }
            .modifier(PlayerPreviewShake(progress: reduceMotion ? 0 : shake))
            Spacer(minLength: 0)
        }
        .cyHaptic(.error, trigger: shakes)
        .onChange(of: isCurrent) { _, current in
            guard current else { return }
            shakes += 1
            if !reduceMotion { withAnimation(PlayerPreviewMotion.shake) { shake += 1 } }
        }
    }
}
