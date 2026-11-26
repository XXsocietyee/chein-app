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
    let help: NativeGameHelpContext?
    let analyticsNodeID: Int?
    let analyticsKit: String?
    let identifier: String
    @Binding var resultPresented: Bool
    let resultActions: NativeGameResultActions
    let controls: Controls
    let outcome: Outcome
    @State private var hintShown = false

    init(title: Text,
         style: NativeGameShellStyle = .list,
         reorderable: Bool = false,
         wrapsInNavigationStack: Bool = false,
         close: (() -> Void)? = nil,
         progress: NativeGameProgress? = nil,
         wrongReply: String? = nil,
         submit: NativeGameSubmit? = nil,
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
            if let progress {
                Section { progressView(progress) }
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
        .sensoryFeedback(.error, trigger: wrongReply) { _, next in next != nil }
        .sheet(isPresented: $resultPresented) { resultSheet }
        .sheet(isPresented: $hintShown) { hintSheet }
        // Native r2 M4: a revealed hint level pops the hint island; "下一条提示" reopens this ladder.
        .islandHints(help?.model) { hintShown = true }
        .accessibilityIdentifier(identifier)
    }

    /// Inside the story page: plain stack, no nested List, ScrollView or toolbar.
    private var embeddedBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let progress { progressView(progress) }
            controls
            wrongReplySection
            outcome
            if let submit { submitButton(submit) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sensoryFeedback(.error, trigger: wrongReply) { _, next in next != nil }
        .accessibilityIdentifier(identifier)
    }

    private func progressView(_ progress: NativeGameProgress) -> some View {
        ProgressView(value: Double(min(progress.current, progress.total)), total: Double(max(1, progress.total))) {
            Text("nativeGames.progress \(progress.current) \(progress.total)")
        }
        .accessibilityIdentifier("nativeGames.progress")
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
        .accessibilityIdentifier(submit.identifier)
    }

    private var resultSheet: some View {
        NavigationStack {
            List {
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
        .presentationDetents([.medium])
        .accessibilityIdentifier("nativeGames.result.sheet")
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

/// Active edit mode only while a sort kit can be reordered; otherwise the environment is untouched.
private struct NativeGameReorderMode: ViewModifier {
    let active: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if active { content.environment(\.editMode, .constant(.active)) } else { content }
    }
}
