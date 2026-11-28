import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix/1128c-ai-showcase step 1 (owner 11-28 ~12:25 UTC: "highlight AI in our homepage. We have AI NPCs, AI guides,
/// and various weather systems"). Level B · Crafted (brief OWNER RULE 3): system components plus one designed object,
/// a hero card. It sits at the head of the MP 编辑精选 block (OWNER RULE 1: the MP order is kept; 编辑精选 follows it).
///
/// Live example: the guide's suggestion for today, chosen by the current weather when the weather branch has
/// observed one, and a reviewed nearby NPC when the guide branch offers one. Copy is data: the catalog keys in
/// `Localizable.xcstrings` (en + zh-Hans), or the guide branch's content file through `AIExperienceLinking`.
@MainActor struct HomeAIShowcaseCard: View {
    let weather: AIShowcaseWeather?
    let suggestion: AIShowcaseSuggestionText
    let nearbyNPC: AIShowcaseNPC?
    let onStartGuide: () -> Void
    let onChatWithNPC: ((AIShowcaseNPC) -> Void)?
    let creationDestination: () -> AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HomeAIShowcaseHeader()
            HomeAIShowcaseExample(weather: weather, suggestion: suggestion)
            if let nearbyNPC {
                HomeAIShowcaseNPCRow(npc: nearbyNPC, onChat: onChatWithNPC)
            }
            HomeAIShowcaseActions(onStartGuide: onStartGuide, creationDestination: creationDestination)
            Text("aiShowcase.disclosure")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeAIShowcase")
    }
}

/// A suggestion is either a catalog key (localized here) or reviewed server / content-file text (shown verbatim).
enum AIShowcaseSuggestionText: Equatable {
    case catalog(String)
    case reviewed(String)

    var text: Text {
        switch self {
        case .catalog(let key): return Text(LocalizedStringKey(key))
        case .reviewed(let value): return Text(verbatim: value)
        }
    }
}

/// Art band + title: the sparkles glyph on the brand tint is the card's one piece of imagery.
@MainActor private struct HomeAIShowcaseHeader: View {
    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: "sparkles")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(CYColor.brand)
                .frame(width: 56, height: 56)
                .background(CYColor.brandSoft, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("aiShowcase.eyebrow")
                    .font(.caption)
                    .foregroundStyle(CYColor.brand)
                Text("aiShowcase.title")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text("aiShowcase.subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Today's suggestion, with the weather it was chosen for.
@MainActor private struct HomeAIShowcaseExample: View {
    let weather: AIShowcaseWeather?
    let suggestion: AIShowcaseSuggestionText

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack(spacing: CYSpacing.sm) {
                Label {
                    Text("aiShowcase.today")
                } icon: {
                    Image(systemName: AIShowcaseCatalog.symbol(for: weather))
                        .symbolRenderingMode(.multicolor)
                        .symbolEffect(.bounce, value: weather?.condition)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                if let weather {
                    Text(LocalizedStringKey(AIShowcaseCatalog.weatherLabelKey(weather.condition)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let temperature = weather.temperatureC {
                        Text(Measurement(value: Double(temperature), unit: UnitTemperature.celsius),
                             format: .measurement(width: .abbreviated, usage: .weather))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }
            }
            suggestion.text
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("homeAIShowcase.suggestion")
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgSurfaceSubtle, in: RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A reviewed nearby NPC (guide branch): name, place, one line, one tap to chat.
@MainActor private struct HomeAIShowcaseNPCRow: View {
    let npc: AIShowcaseNPC
    let onChat: ((AIShowcaseNPC) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: "person.wave.2.fill")
                .font(.title3)
                .foregroundStyle(CYColor.brand)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("aiShowcase.nearbyNPC")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(verbatim: npc.name)
                    .font(.headline)
                if let place = npc.placeName, !place.isEmpty {
                    Text(verbatim: place)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: npc.line)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if let onChat {
                Button {
                    onChat(npc)
                } label: {
                    Text("aiShowcase.chatWith \(npc.name)")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("homeAIShowcase.chatNPC")
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// One prominent action (start the guide) and one secondary entry to AI creation.
@MainActor private struct HomeAIShowcaseActions: View {
    let onStartGuide: () -> Void
    let creationDestination: () -> AnyView

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.md) { buttons }
            VStack(alignment: .leading, spacing: CYSpacing.sm) { buttons }
        }
    }

    @ViewBuilder private var buttons: some View {
        Button(action: onStartGuide) {
            Label("aiShowcase.startGuide", systemImage: "figure.walk.motion")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityHint(Text("aiShowcase.startGuide.hint"))
        .accessibilityIdentifier("homeAIShowcase.startGuide")
        NavigationLink {
            creationDestination()
        } label: {
            Label("aiShowcase.create", systemImage: "wand.and.stars")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .accessibilityHint(Text("aiShowcase.create.hint"))
        .accessibilityIdentifier("homeAIShowcase.create")
    }
}

/// Session host: resolves the live example from the sibling branches' link values, falls back to the catalog.
@MainActor struct SessionHomeAIShowcase: View {
    @EnvironmentObject private var session: AppSession
    @Environment(\.aiExperienceLink) private var link
    @Environment(\.aiWeatherFacts) private var weatherFacts
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @State private var weather: AIShowcaseWeather?
    @State private var dayOfYear = 1

    var body: some View {
        HomeAIShowcaseCard(
            weather: weather,
            suggestion: Self.suggestion(link: link, weather: weather, dayOfYear: dayOfYear),
            nearbyNPC: link?.nearbyNPC,
            onStartGuide: startGuide,
            onChatWithNPC: Self.chatAction(link),
            creationDestination: creationDestination
        )
        .task(id: scenePhase) { refresh() }
    }

    private func refresh() {
        weather = AIShowcaseWeather(guideFacts: link?.currentWeatherFacts() ?? weatherFacts?())
        dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
    }

    private func startGuide() {
        if let link, link.canStartGuide {
            link.startGuide()
        } else if rootTabSwitch.isAvailable {
            // The reviewed roam prompt layer (planning audit R-18) runs on 漫游; that is the guide until the
            // ai-npc-guide branch installs its own launcher.
            rootTabSwitch(.roam)
        }
    }

    private func creationDestination() -> AnyView {
        AnyView(SessionAICreationHubView().environmentObject(session))
    }

    static func chatAction(_ link: (any AIExperienceLinking)?) -> ((AIShowcaseNPC) -> Void)? {
        guard let link else { return nil }
        return { (npc: AIShowcaseNPC) -> Void in link.chatWithNPC(npc) }
    }

    static func suggestion(link: (any AIExperienceLinking)?, weather: AIShowcaseWeather?, dayOfYear: Int) -> AIShowcaseSuggestionText {
        if let reviewed = link?.todaySuggestion(for: weather)?.trimmingCharacters(in: .whitespacesAndNewlines), !reviewed.isEmpty {
            return .reviewed(reviewed)
        }
        return .catalog(AIShowcaseCatalog.suggestionKey(for: weather, dayOfYear: dayOfYear))
    }
}
