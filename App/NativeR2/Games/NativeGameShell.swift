import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Native r2 games: the one shell every game kit uses (templates 1–6, both halves).
// Spec: docs/design/native-r2/games.md §1 on design/native-r2-games.
// Apple references: Fitness workout (one live value, one prominent action),
// Settings / Health forms (answer inputs), Maps place card (result and hint sheets).

/// The one prominent action of a game screen. It sits in the bottom safe-area bar.
struct NativeGameSubmit {
    var title: Text
    var enabled: Bool
    var busy = false
    var identifier: String
    var action: () -> Void
}

/// "第 n/N 题" for kits that ask more than one question.
struct NativeGameProgress: Equatable {
    let current: Int
    let total: Int
}

/// What the result sheet offers after the server answered.
struct NativeGameResultActions {
    var canRetry = false
    var canContinue = false
    var retry: () -> Void = {}
    var continueStory: () -> Void = {}
}

/// Pushed / sheet: an inset-grouped `List` with toolbar and bottom bar.
/// Embedded (inside the story page): no list, no toolbar; the story page owns those.
enum NativeGameShellStyle: Equatable { case list, embedded }

/// The play host hands the hint ladder down so the shell can show it as a toolbar button.
struct NativeGameHelpContext {
    let model: PlayHelpLadderModel
    var teamPool: TeamPoolHintModel? = nil
    var approvedArtworkHosts: Set<String> = []
    var onPoolTrimmed: () -> Void = {}
}

private struct NativeGameHelpKey: EnvironmentKey { static let defaultValue: NativeGameHelpContext? = nil }

extension EnvironmentValues {
    /// Set by the play host when the server enabled the hint ladder for this stop.
    var nativeGameHelp: NativeGameHelpContext? {
        get { self[NativeGameHelpKey.self] }
        set { self[NativeGameHelpKey.self] = newValue }
    }
}

/// NavigationStack (optional) → List(.insetGrouped) → kit sections → wrong reply → inline result.
/// Toolbar: close (sheet), hint (when enabled). Bottom bar: one `.borderedProminent` button.
/// A fresh result also opens a `.medium` sheet with retry / continue.
@MainActor struct NativeGameShell<Controls: View, Outcome: View>: View {
    let title: Text
    let style: NativeGameShellStyle
    /// Sort: the list stays in edit mode so rows show the system drag handles.
    let reorderable: Bool
    let wrapsInNavigationStack: Bool
    let close: (() -> Void)?
    let progress: NativeGameProgress?
    let wrongReply: String?
    let submit: NativeGameSubmit?
    /// The server verdict (nil until one exists). A fresh `.passed` plays the success feedback (G-007).
    let verdict: PlayGameOutcome?
    /// A server-reported score; the result sheet rolls it up from zero (G-009).
    let score: Int?
    /// Components r1: server values for the live HUD (score, tries); the shell adds progress and hint counts.
    let hud: NativeGameHUDModel
    let help: NativeGameHelpContext?
    let analyticsNodeID: Int?
    let analyticsKit: String?
    let identifier: String
    @Binding var resultPresented: Bool
    let resultActions: NativeGameResultActions
    let controls: Controls
    let outcome: Outcome
    @State private var hintShown = false
    /// Bumped when a fresh pass arrives; drives the verdict symbol bounce.
    @State private var celebration = 0
    /// What the result sheet shows; rolls from 0 to `score` when the sheet appears.
    @State private var shownScore = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    init(title: Text,
         style: NativeGameShellStyle = .list,
         reorderable: Bool = false,
         wrapsInNavigationStack: Bool = false,
         close: (() -> Void)? = nil,
         progress: NativeGameProgress? = nil,
         wrongReply: String? = nil,
         submit: NativeGameSubmit? = nil,
         verdict: PlayGameOutcome? = nil,
         score: Int? = nil,
         hud: NativeGameHUDModel = NativeGameHUDModel(),
         help: NativeGameHelpContext? = nil,
         analyticsNodeID: Int? = nil,
         analyticsKit: String? = nil,
         identifier: String,
         resultPresented: Binding<Bool>,
         resultActions: NativeGameResultActions = NativeGameResultActions(),
         @ViewBuilder controls: () -> Controls,
         @ViewBuilder outcome: () -> Outcome) {
        self.title = title; self.style = style; self.reorderable = reorderable; self.wrapsInNavigationStack = wrapsInNavigationStack
        self.close = close; self.progress = progress; self.wrongReply = wrongReply; self.submit = submit
        self.verdict = verdict; self.score = score; self.hud = hud
        self.help = help; self.analyticsNodeID = analyticsNodeID; self.analyticsKit = analyticsKit
        self.identifier = identifier; self._resultPresented = resultPresented; self.resultActions = resultActions
        self.controls = controls(); self.outcome = outcome()
    }

    var body: some View {
        if wrapsInNavigationStack { NavigationStack { framed } } else { framed }
    }

    @ViewBuilder private var framed: some View {
        if style == .embedded { embeddedBody } else { listBody }
    }

    private var listBody: some View {
        List {
            if !liveHUD.isEmpty {
                Section { NativeGameHUD(model: liveHUD) }
            }
            controls
            wrongReplySection
            outcome
        }
        .listStyle(.insetGrouped)
        .modifier(NativeGameReorderMode(active: reorderable))
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                if let close {
                    Button("nativeGames.close", action: close)
                        .accessibilityIdentifier("playkit.close")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                if help != nil {
                    Button { hintShown = true } label: { Label("nativeGames.hint", systemImage: "lightbulb") }
                        .accessibilityIdentifier("nativeGames.hint")
                }
            }
        }
        .safeAreaInset(edge: .bottom) { submitBar }
        .animation(reduceMotion ? nil : .smooth, value: wrongReply)
        .modifier(NativeGameFeedback(wrongReply: wrongReply, verdict: verdict, celebrate: celebrate))
        .cySheet(isPresented: $resultPresented) { resultSheet }
        .cySheet(isPresented: $hintShown) { hintSheet }
        // Native r2 M4: a revealed hint level pops the hint island; "下一条提示" reopens this ladder.
        .islandHints(help?.model) { hintShown = true }
        .accessibilityIdentifier(identifier)
    }

    /// Inside the story page: plain stack, no nested List, ScrollView or toolbar.
    private var embeddedBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !liveHUD.isEmpty { NativeGameHUD(model: liveHUD) }
            controls
            wrongReplySection
            outcome
            if let submit { submitButton(submit) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .smooth, value: wrongReply)
        .modifier(NativeGameFeedback(wrongReply: wrongReply, verdict: verdict, celebrate: celebrate))
        .accessibilityIdentifier(identifier)
    }

    /// The host's server values plus the question progress and the hint ladder's revealed / total layers.
    private var liveHUD: NativeGameHUDModel {
        var model = hud
        model.progress = progress
        if let hints = NativeGameHUDModel.hints(help?.model) {
            model.hintsUsed = hints.used
            model.hintsTotal = hints.total
        }
        return model
    }

    /// Result sheet: what it took (tries, hints); the score itself is the big rolling number above.
    private var resultStats: NativeGameHUDModel {
        var model = liveHUD
        model.score = nil
        model.progress = nil
        return model
    }

    /// The server's reply to a wrong answer, right under the controls (PlayKitWrongReply).
    @ViewBuilder private var wrongReplySection: some View {
        if let wrongReply {
            Section {
                Label {
                    Text(verbatim: wrongReply).fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "xmark.circle")
                }
                .foregroundStyle(.red)
                .symbolEffect(.bounce, value: reduceMotion ? nil : wrongReply)
                .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("playkit.qa.wrongReply")
            }
        }
    }

    @ViewBuilder private var submitBar: some View {
        if let submit {
            submitButton(submit)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }

    private func submitButton(_ submit: NativeGameSubmit) -> some View {
        Button(action: submit.action) {
            Group {
                if submit.busy { ProgressView() } else { submit.title }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!submit.enabled || submit.busy)
        // G-006: the spinner replaces the title, so VoiceOver keeps the title and hears "sending" as the value.
        .accessibilityLabel(submit.title)
        .accessibilityValue(submit.busy ? Text("playkit.sending") : Text(verbatim: ""))
        .accessibilityIdentifier(submit.identifier)
    }

    private var resultSheet: some View {
        NavigationStack {
            List {
                if let verdict { resultHeader(verdict) }
                outcome
                if resultActions.canRetry || resultActions.canContinue {
                    Section {
                        if resultActions.canRetry {
                            Button {
                                resultPresented = false
                                resultActions.retry()
                            } label: {
                                Text("nativeGames.retry").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("nativeGames.result.retry")
                        }
                        if resultActions.canContinue {
                            Button {
                                resultPresented = false
                                resultActions.continueStory()
                            } label: {
                                Text("playkit.story.continue").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .accessibilityIdentifier("nativeGames.result.continue")
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("nativeGames.result.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("nativeGames.done") { resultPresented = false }
                        .accessibilityIdentifier("nativeGames.result.done")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear(perform: rollScore)
        .accessibilityIdentifier("nativeGames.result.sheet")
    }

    /// Big verdict symbol (bounces on a pass) and the server score rolling up from zero (G-007 / G-009).
    private func resultHeader(_ verdict: PlayGameOutcome) -> some View {
        Section {
            VStack(spacing: 8) {
                // Components r1: badge springs in with one ripple on a pass (MP result-sheet); still under Reduce Motion.
                NativeGameRewardBadge(systemImage: Self.symbol(for: verdict), passed: verdict == .passed, trigger: celebration)
                if let score {
                    Text(verbatim: shownScore.formatted(.number.locale(locale)))
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(shownScore)))
                        .accessibilityLabel(Text("nativeGames.result.score \(score)"))
                        .accessibilityIdentifier("nativeGames.result.score")
                }
                if !resultStats.isEmpty {
                    NativeGameHUD(model: resultStats)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("nativeGames.result.stats")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .listRowBackground(Color.clear)
    }

    /// Runs once the sheet is on screen so the bounce and the numeric roll are visible (Reduce Motion: set instantly).
    private func rollScore() {
        if reduceMotion { shownScore = score ?? 0; return }
        shownScore = 0
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            if verdict == .passed { celebration += 1 }
            if let score { withAnimation(.smooth(duration: 0.8)) { shownScore = score } }
        }
    }

    /// A fresh pass: bounce, success haptic (in `NativeGameFeedback`), island and a VoiceOver announcement.
    private func celebrate() {
        celebration += 1
        IslandCenter.shared.status(.key("nativeGames.passed.island"), tone: .success)
        AccessibilityNotification.Announcement(appLocalized("nativeGames.passed.island", locale: locale)).post()
    }

    static func symbol(for verdict: PlayGameOutcome) -> String {
        switch verdict {
        case .passed: return "checkmark.seal.fill"
        case .notPassed: return "arrow.uturn.backward.circle"
        case .recorded: return "bookmark.circle"
        case .noVerdict: return "ellipsis.circle"
        }
    }

    @ViewBuilder private var hintSheet: some View {
        if let help {
            NativeGameHintSheet(model: help.model, teamPool: help.teamPool, approvedArtworkHosts: help.approvedArtworkHosts,
                                onPoolTrimmed: help.onPoolTrimmed, analyticsNodeID: analyticsNodeID, analyticsKit: analyticsKit,
                                close: { hintShown = false })
        }
    }
}

/// Permission denied or sensor missing: one system empty state with Open Settings.
@MainActor struct NativeGamePermissionView: View {
    let title: LocalizedStringKey
    let systemImage: String
    let description: LocalizedStringKey
    var showsSettings = true
    var retry: (() -> Void)? = nil
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(description)
        } actions: {
            if showsSettings, let url = Self.settingsURL {
                Button("playkit.media.openSettings") { openURL(url) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("playkit.sensor.openSettings")
            }
            if let retry {
                Button("nativeGames.tryAgain", action: retry)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("nativeGames.permission.retry")
            }
        }
        .accessibilityIdentifier("nativeGames.permission")
    }

    static var settingsURL: URL? {
        #if canImport(UIKit)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}

/// G-007 / G-012: error haptic + VoiceOver announcement for a new wrong reply; success haptic and
/// `celebrate` for a fresh pass. Haptics are system `.sensoryFeedback` (they respect the system setting).
@MainActor private struct NativeGameFeedback: ViewModifier {
    let wrongReply: String?
    let verdict: PlayGameOutcome?
    let celebrate: @MainActor () -> Void
    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.error, trigger: wrongReply) { _, next in next != nil }
            .sensoryFeedback(.success, trigger: verdict) { old, next in old != .passed && next == .passed }
            .onChange(of: wrongReply) { _, next in
                if let next, !next.isEmpty { AccessibilityNotification.Announcement(next).post() }
            }
            .onChange(of: verdict) { old, next in
                if old != .passed && next == .passed { celebrate() }
            }
    }
}

/// Active edit mode only while a sort kit can be reordered; otherwise the environment is untouched.
private struct NativeGameReorderMode: ViewModifier {
    let active: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if active { content.environment(\.editMode, .constant(.active)) } else { content }
    }
}
