import SwiftUI

// View-state machine (view-state series): one enum instead of loading/error/data booleans, so impossible
// combinations (loading AND failed, failed AND loaded) cannot be represented or rendered.
// Transitions and guards per migrated view: docs/release/state-machines/views.md.

/// Load lifecycle of one screen or section.
///
/// ```
/// idle -> loading -> loaded(Value) | empty | failed(Failure, retry:)
/// loaded | empty | failed -> loading   (reload / retry)
/// loading | loaded | empty | failed -> idle   (screen left, load cancelled)
/// ```
enum CYPhase<Value, Failure> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(Failure, retry: (() -> Void)?)

    var isLoading: Bool { if case .loading = self { return true } else { return false } }
    var isFailed: Bool { if case .failed = self { return true } else { return false } }
    var value: Value? { if case .loaded(let value) = self { return value } else { return nil } }
    var failure: Failure? { if case .failed(let failure, _) = self { return failure } else { return nil } }

    /// Coarse, Equatable identity of the phase (drives animation and announcements without requiring `Value: Equatable`).
    var kind: CYPhaseKind {
        switch self {
        case .idle: .idle
        case .loading: .loading
        case .loaded: .loaded
        case .empty: .empty
        case .failed: .failed
        }
    }
}

enum CYPhaseKind: Equatable { case idle, loading, loaded, empty, failed }

/// Maps a `CYPhase` onto the kit states: skeleton while loading, `CYEmptyState`, `CYErrorState` with retry,
/// and the caller's content once loaded. The skeleton shows only after 120 ms and stays at least 350 ms, so a fast
/// load never flashes it. Phase swaps cross-fade over 0.20 s (instant under Reduce Motion) and VoiceOver
/// hears one announcement when a load ends in failure or content.
struct CYPhaseView<Value, Failure, Content: View>: View {
    let phase: CYPhase<Value, Failure>
    var skeletonRows = 3
    let loadingLabel: LocalizedStringKey
    var emptySystemImage = "tray"
    let emptyMessage: LocalizedStringKey
    var emptyActionTitle: LocalizedStringKey?
    var emptyAction: (() -> Void)?
    var failureMessage: LocalizedStringKey = "Couldn't load this. Check your connection."
    var offline: (Failure) -> Bool = { _ in false }
    var announcesChanges = true
    /// Accessibility identifier on the skeleton, for screens whose UI tests wait on a `.loading` element.
    var loadingIdentifier: String?
    @ViewBuilder var content: (Value) -> Content

    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var previous: CYPhaseKind = .idle
    @State private var skeletonVisible = false

    init(
        phase: CYPhase<Value, Failure>,
        skeletonRows: Int = 3,
        loadingLabel: LocalizedStringKey,
        emptySystemImage: String = "tray",
        emptyMessage: LocalizedStringKey,
        emptyActionTitle: LocalizedStringKey? = nil,
        emptyAction: (() -> Void)? = nil,
        failureMessage: LocalizedStringKey = "Couldn't load this. Check your connection.",
        offline: @escaping (Failure) -> Bool = { _ in false },
        announcesChanges: Bool = true,
        loadingIdentifier: String? = nil,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.phase = phase
        self.skeletonRows = skeletonRows
        self.loadingLabel = loadingLabel
        self.emptySystemImage = emptySystemImage
        self.emptyMessage = emptyMessage
        self.emptyActionTitle = emptyActionTitle
        self.emptyAction = emptyAction
        self.failureMessage = failureMessage
        self.offline = offline
        self.announcesChanges = announcesChanges
        self.loadingIdentifier = loadingIdentifier
        self.content = content
    }

    /// What is on screen: the timed skeleton wins while it is visible (show-delay / minimum hold), otherwise the phase.
    private enum Rendered: Equatable { case skeleton, phase(CYPhaseKind) }
    private var rendered: Rendered { skeletonVisible ? .skeleton : .phase(phase.kind) }

    var body: some View {
        ZStack {
            if skeletonVisible {
                skeleton
            } else {
                phaseBody
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: CYMotion.Duration.quick), value: rendered)
        .cySkeletonTiming(isLoading: phase.isLoading, visible: $skeletonVisible)
        .onChange(of: phase.kind) { _, new in
            defer { previous = new }
            guard announcesChanges, previous == .loading else { return }
            let t = CYKitCopy(locale: locale)
            switch new {
            case .failed: Self.announce(t("Couldn't load. Try again.", "没加载出来，再试一次。"))
            case .loaded: Self.announce(t("Loaded", "已加载"))
            case .empty: Self.announce(t("Nothing here yet", "这里还没有内容"))
            case .idle, .loading: break
            }
        }
    }

    private var skeleton: some View {
        // mp-states r3: the caller's loading words are the visible ProgressView label, not VoiceOver-only.
        CYLoadingStateView(rows: skeletonRows, label: loadingLabel)
            .padding(.top, CYSpacing.sm)
            .frame(maxHeight: .infinity, alignment: .top)
            .accessibilityIdentifier(loadingIdentifier ?? "cy.phase.loading")
            .transition(.opacity)
    }

    @ViewBuilder private var phaseBody: some View {
        ZStack {
            switch phase {
            case .idle, .loading:
                Color.clear.accessibilityHidden(true)
            case .loaded(let value):
                content(value).transition(.opacity)
            case .empty:
                CYEmptyState(systemImage: emptySystemImage, emptyMessage, actionTitle: emptyActionTitle, action: emptyAction)
                    .transition(.opacity)
            case .failed(let failure, let retry):
                CYErrorState(failureMessage, offline: offline(failure), onRetry: retry ?? {})
                    .transition(.opacity)
            }
        }
    }

    private static func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
