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
/// and the caller's content once loaded. Phase swaps cross-fade (instant under Reduce Motion) and VoiceOver
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
    @ViewBuilder var content: (Value) -> Content

    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var previous: CYPhaseKind = .idle

    var body: some View {
        ZStack {
            switch phase {
            case .idle:
                Color.clear.accessibilityHidden(true)
            case .loading:
                CYLoadingStateView(rows: skeletonRows)
                    .accessibilityLabel(Text(loadingLabel))
                    .transition(.opacity)
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
        .animation(reduceMotion ? nil : .easeInOut(duration: CYMotion.Duration.quick), value: phase.kind)
        .onChange(of: phase.kind) { _, new in
            defer { previous = new }
            guard announcesChanges, previous == .loading else { return }
            let t = CYKitCopy(locale: locale)
            switch new {
            case .failed: Self.announce(t("Couldn't load. Retry is available.", "加载失败，可重试。"))
            case .loaded: Self.announce(t("Loaded", "已加载"))
            case .empty: Self.announce(t("Nothing here yet", "暂无内容"))
            case .idle, .loading: break
            }
        }
    }

    private static func announce(_ text: String) {
        UIAccessibility.post(notification: .announcement, argument: text)
    }
}
