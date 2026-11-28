import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix/1128c-ai-showcase step 3: environment values that link the home AI showcase and the AI creation flow to the
/// sibling AI branches without naming their types.
///
/// - `aiExperienceLink`: `fix/1128c-ai-npc-guide` installs its `AIExperienceLinking` object here (for example in
///   `AIExperienceRootEnvironment`, one line). Nil (the default) keeps the showcase on its own catalog copy and opens
///   the 漫游 tab for "Start the AI guide".
/// - `aiWeatherFacts`: `fix/1128c-ai-weather` returns `WeatherContextBoard.shared.current?.guideFacts` here. The link
///   object's `currentWeatherFacts()` wins when both are set.
/// - `aiSafetyPrecheckSource`: the pre-publish AI safety precheck (H-08b) for the project editor.
struct AISafetyPrecheckSource {
    let make: @MainActor () -> AISafetyPrecheckRunner?
}

private struct AIExperienceLinkKey: EnvironmentKey {
    static let defaultValue: (any AIExperienceLinking)? = nil
}

private struct AIWeatherFactsKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> [String: String]?)? = nil
}

private struct AISafetyPrecheckSourceKey: EnvironmentKey {
    static let defaultValue: AISafetyPrecheckSource? = nil
}

extension EnvironmentValues {
    var aiExperienceLink: (any AIExperienceLinking)? {
        get { self[AIExperienceLinkKey.self] }
        set { self[AIExperienceLinkKey.self] = newValue }
    }
    var aiWeatherFacts: (@MainActor () -> [String: String]?)? {
        get { self[AIWeatherFactsKey.self] }
        set { self[AIWeatherFactsKey.self] = newValue }
    }
    var aiSafetyPrecheckSource: AISafetyPrecheckSource? {
        get { self[AISafetyPrecheckSourceKey.self] }
        set { self[AISafetyPrecheckSourceKey.self] = newValue }
    }
}

@MainActor extension AppSession {
    /// H-08b: nil unless the Release composition granted `.publishingAISafety` (club hosts on the China host).
    func makeAISafetyPrecheckRunner() -> AISafetyPrecheckRunner? {
        guard let service = makePublishingAuxiliaryService(feature: .publishingAISafety) else { return nil }
        return AISafetyPrecheckRunner(service: service, session: { [weak self] in self?.publishingSession })
    }

    /// H-08a: nil unless `.publishingAITemplate` is granted (club hosts).
    func makeAITemplateFillRunner() -> AITemplateFillRunner? {
        guard let service = makePublishingAuxiliaryService(feature: .publishingAITemplate) else { return nil }
        let runner = AITemplateFillRunner(service: service, session: { [weak self] in self?.publishingSession })
        return runner.isConfigured ? runner : nil
    }

    /// Club hosts get the club-only creator AI (design, template fill, safety precheck).
    var aiCreationIsClubHost: Bool { publishingSession?.role == "club" }
}

/// Installed once on the player tab root (`QuestifyApp.playerTabs`). New AI environment values go here, not into
/// `QuestifyApp.swift` or `AppSession.swift`.
struct AIExperienceRootEnvironment: ViewModifier {
    @ObservedObject var session: AppSession

    func body(content: Content) -> some View {
        content
            .environment(\.aiSafetyPrecheckSource, Self.precheckSource(session))
    }

    static func precheckSource(_ session: AppSession) -> AISafetyPrecheckSource {
        AISafetyPrecheckSource(make: { [weak session] in session?.makeAISafetyPrecheckRunner() })
    }
}
