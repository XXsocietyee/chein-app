import SwiftUI

/// The always-available guide during roam and play: a toolbar button (sparkles + the data-file identity) that opens
/// a half sheet with "now" (place / stop / weather), this visit's reviewed lines, and the owner's prompts.
/// Read-aloud on every line. No free chat: roam chat stays closed on the server (BE `chatOn()` false, planning §5.1).
struct AIGuideToolbarButton: View {
    let surface: StoryGuideSurface
    var journal: AIGuideJournal?
    let open: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        Button(action: open) {
            Label { AIGuideIdentityText(surface: surface) } icon: {
                Image(systemName: "sparkles").symbolEffect(.bounce, value: journal?.arrivals ?? 0)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: journal?.arrivals ?? 0)
        .accessibilityIdentifier("aiGuide.open." + surface.rawValue)
    }
}

/// The guide's neutral identity from the content file (「漫游提示」 / 「游玩提示」), or the localized fallback.
struct AIGuideIdentityText: View {
    let surface: StoryGuideSurface
    @Environment(\.locale) private var locale

    var body: some View {
        let line = AIStoryContent.text(surface == .roam ? .guideRoamIdentity : .guidePlayIdentity, locale: locale)
        if line.isEmpty { Text("aiGuide.open") } else { Text(verbatim: line) }
    }
}

struct AIGuideSheet: View {
    let context: AIGuideContext
    var journal: AIGuideJournal?
    @State private var voice = AIVoiceOut()
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private var language: StoryContentLanguage { AIStoryContent.language(locale) }
    private var entries: [AIGuideEntry] { journal?.entries ?? [] }
    private var weather: StoryGuideWeather? { context.weather ?? AIGuideWeatherMapping.weather(journal?.mapWeather) }
    private var prompts: [AIGuideEntry] {
        let lines = AIStoryContent.catalog?.guidePrompts(for: context.surface, weather: weather, node: context.nodeKind, language: language) ?? []
        return lines.enumerated().map { AIGuideEntry(id: "prompt-\($0.offset)", kind: .prompt, text: $0.element, place: nil) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section { AIGuideNowSection(context: context, weather: weather, speaking: voice.speakingID != nil) }
                if !entries.isEmpty {
                    Section("aiGuide.section.walk") {
                        ForEach(entries) { entry in
                            AIGuideLineRow(entry: entry, animates: entry.id == entries.first?.id, voice: voice)
                        }
                    }
                }
                Section {
                    if prompts.isEmpty && entries.isEmpty {
                        AIGuideQuietRow()
                    }
                    ForEach(prompts) { entry in
                        AIGuideLineRow(entry: entry, animates: false, voice: voice)
                    }
                } header: {
                    Text("aiGuide.section.notes")
                } footer: {
                    Text("aiGuide.disclosure")
                }
            }
            .navigationTitle(Text(verbatim: identity))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }.accessibilityIdentifier("aiGuide.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onDisappear { voice.stop() }
        .accessibilityIdentifier("aiGuide.sheet." + context.surface.rawValue)
    }

    private var identity: String {
        let line = AIStoryContent.text(context.surface == .roam ? .guideRoamIdentity : .guidePlayIdentity, locale: locale)
        return line.isEmpty ? appLocalized("aiGuide.open", locale: locale) : line
    }
}

/// "Now": the formless presence mark, the place or stop, and the weather of the current cell.
struct AIGuideNowSection: View {
    let context: AIGuideContext
    let weather: StoryGuideWeather?
    let speaking: Bool

    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            AIGuidePresenceMark(active: speaking)
            Text("aiGuide.section.now").cyText(.body).foregroundStyle(CYColor.textPrimary)
        }
        if let place = context.place, !place.isEmpty {
            LabeledContent { Text(verbatim: place) } label: { Text("aiGuide.context.place") }
        }
        if let stop = context.stop, !stop.isEmpty {
            LabeledContent { Text(verbatim: stop) } label: { Text("aiGuide.context.stop") }
        }
        if let weather {
            LabeledContent {
                Label { Text(LocalizedStringKey("aiGuide.weather." + weather.rawValue)) } icon: {
                    Image(systemName: AIGuideWeatherMapping.symbol(weather))
                }
            } label: { Text("aiGuide.context.weather") }
        }
    }
}

struct AIGuideQuietRow: View {
    @Environment(\.locale) private var locale

    var body: some View {
        let line = AIStoryContent.text(.guideQuiet, locale: locale)
        if !line.isEmpty {
            Text(verbatim: line).cyText(.body).foregroundStyle(CYColor.textSecondary)
        }
    }
}

/// One guide line: its source label, the text (typing reveal for the newest reviewed line) and read-aloud.
struct AIGuideLineRow: View {
    let entry: AIGuideEntry
    let animates: Bool
    let voice: AIVoiceOut

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(entry.labelKey).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                AITypingRevealText(text: entry.text, animates: animates)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let place = entry.place, !place.isEmpty {
                    Text(verbatim: place).cyText(.meta).foregroundStyle(CYColor.textTertiary)
                }
            }
            Spacer(minLength: 0)
            AIReadAloudButton(id: entry.id, text: entry.text, voice: voice)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Read aloud / stop for one line. 44 pt target.
struct AIReadAloudButton: View {
    let id: String
    let text: String
    let voice: AIVoiceOut

    var body: some View {
        let speaking = voice.speakingID == id
        Button { voice.toggle(id: id, text: text) } label: {
            Image(systemName: speaking ? "stop.circle" : "speaker.wave.2")
                .symbolEffect(.variableColor.iterative, isActive: speaking)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(speaking ? "aiGuide.stopReading" : "aiGuide.readAloud"))
        .accessibilityIdentifier("aiGuide.readAloud")
    }
}
