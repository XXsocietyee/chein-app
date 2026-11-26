import SwiftUI

/// Design backlog P-021 / P-022 / P-026: the one search model behind every player search surface.
/// 首页 (in place, over the feed), the pushed search page and its deep links all read and write this model, and
/// they all draw the same system search field through `globalSearchField(_:)`: `.searchable`,
/// `.searchSuggestions` and `.searchScopes`. The list and map are two presentations of the same query.
/// No reads happen here; `GlobalSearchView` keeps the only search request.
@MainActor @Observable final class GlobalSearchSession {
    /// The system search field's text.
    var keyword = ""
    /// The system search field is active (focused, Cancel showing).
    var isPresented = false
    /// Result scope (MP `search2/result` tabs). Nil is 全部.
    var scope: GlobalSearchKind?
    /// List or map presentation of the same query (`UnifiedSearchExperience`).
    var mode: UnifiedSearchExperience.PresentationMode = .list
    /// Bumped by the keyboard Search key; `GlobalSearchView` runs its submit when it changes.
    var submitCount = 0
    /// History and recommended keywords, offered as completions while typing.
    var suggestionPool: [String] = []
    /// Result counts for the scope bar, written by the results list once a search settles (MP tab counts).
    var scopeCounts: [GlobalSearchKind: String] = [:]
    /// Kinds the scope bar offers.
    var kinds: [GlobalSearchKind] = GlobalSearchKind.allCases

    init() {}

    /// Completions for the typed text: a history or recommended keyword that starts with, or contains, the text.
    /// Empty text shows none (the page lists history and recommendations inline instead).
    var completions: [String] {
        let typed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !typed.isEmpty else { return [] }
        var seen = Set<String>()
        return suggestionPool.filter { candidate in
            guard candidate != typed, candidate.localizedCaseInsensitiveContains(typed) else { return false }
            return seen.insert(candidate).inserted
        }
        .prefix(6)
        .map { $0 }
    }

    func submit() { submitCount &+= 1 }

    /// Cancel / scope change on the host: back to an empty search.
    func reset() {
        keyword = ""
        scope = nil
        scopeCounts = [:]
        mode = .list
    }
}

extension View {
    /// The one system search field for player search. `prompt` keeps the MP placeholder copy.
    @MainActor func globalSearchField(_ session: GlobalSearchSession, placement: SearchFieldPlacement = .navigationBarDrawer(displayMode: .always)) -> some View {
        modifier(GlobalSearchFieldModifier(session: session, placement: placement))
    }
}

@MainActor private struct GlobalSearchFieldModifier: ViewModifier {
    @Bindable var session: GlobalSearchSession
    let placement: SearchFieldPlacement

    func body(content: Content) -> some View {
        content
            .searchable(text: $session.keyword, isPresented: $session.isPresented, placement: placement,
                        prompt: Text("searchMap.placeholder.player"))
            .searchSuggestions {
                ForEach(session.completions, id: \.self) { keyword in
                    Label { Text(verbatim: keyword) } icon: { Image(systemName: "clock.arrow.circlepath") }
                        .searchCompletion(keyword)
                        .accessibilityIdentifier("searchMap.completion")
                }
            }
            .searchScopes($session.scope, activation: .onSearchPresentation) {
                // MP result tabs: 全部 carries no count; each kind shows its own once a search has settled.
                Text("searchMap.all").tag(nil as GlobalSearchKind?)
                ForEach(session.kinds, id: \.self) { kind in
                    scopeTitle(kind).tag(kind as GlobalSearchKind?)
                }
            }
            .onSubmit(of: .search) { session.submit() }
            .textInputAutocapitalization(.never)
            .sensoryFeedback(.selection, trigger: session.scope)
    }

    private func scopeTitle(_ kind: GlobalSearchKind) -> Text {
        if let count = session.scopeCounts[kind] {
            return Text(kind.titleKey) + Text(verbatim: " \(count)")
        }
        return Text(kind.titleKey)
    }
}
