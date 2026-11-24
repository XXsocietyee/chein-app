import SwiftUI

@MainActor struct NativeRouteErrorView: View {
    let failure: NativeRouteFailure
    let goHome: () -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ContentUnavailableView {
            Label("nativeNav.error.title", systemImage: "questionmark.folder")
        } description: {
            if failure == .legacyTeamLink {
                Text("team.page.legacyLink").cyText(.cardTitle)
                Text("team.page.legacyLink.detail")
            } else {
                Text(failure == .cannotOpen ? "nativeNav.error.cannotOpen" : "nativeNav.error.detail")
            }
        } actions: {
            VStack(spacing: CYSpacing.sm) {
                CYPillButton("homeFeed.title", style: .primary, action: goHome).accessibilityIdentifier("nativeNav.error.home")
                CYPillButton("nativeNav.close", style: .tertiary) { dismiss() }.accessibilityIdentifier("nativeNav.error.close")
            }.padding(.horizontal, CYSpacing.lg)
        }.navigationTitle("nativeNav.error.title").navigationBarTitleDisplayMode(.inline)
            .accessibilityElement(children: .contain).accessibilityIdentifier("nativeNav.error")
    }
}

@MainActor struct TeamInvitationEntryView: View {
    let makeCoordinator: () -> TeamCoordinator
    var onLogin: (() -> Void)? = nil
    var onOpen: ((TeamInvitationRoute) -> Void)? = nil
    @State private var code = ""
    @State private var route: TeamInvitationPresentation?
    @State private var invalid = false
    private static let maxCodeLength = 40
    private func open() {
        guard let value = try? TeamInvitationRoute(code: code) else { invalid = true; return }
        invalid = false
        if let onOpen { onOpen(value) } else { route = TeamInvitationPresentation(route: value) }
    }
    var body: some View {
        Form {
            // MP team/join `?entry=code` (C-J1): 加入码 field (≤ 40), then 下一步 to the invitation page.
            Section {
                LabeledContent {
                    TextField("nativeNav.team.codePlaceholder", text: $code)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: code) { _, value in if value.count > Self.maxCodeLength { code = String(value.prefix(Self.maxCodeLength)) } }
                        .submitLabel(.next).onSubmit(open)
                        .accessibilityIdentifier("nativeNav.team.code")
                } label: { Text("nativeNav.team.code") }
                if invalid { Text("nativeNav.invalid").cyText(.meta).foregroundStyle(CYColor.dangerText) }
            } footer: { Text("nativeNav.team.notice").cyText(.meta) }
            Section {
                CYPillButton("nativeNav.team.next", action: open)
                    .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("nativeNav.team.next")
            }.listRowBackground(Color.clear)
        }.cyPageTitle("team.invitation")
            .navigationDestination(item: $route) { item in
                TeamInvitationDestination(route: item.route, makeCoordinator: makeCoordinator, onLogin: onLogin)
            }
            .privacySensitive()
        .cyDomainScreen(.player)
    }
}
private struct TeamInvitationPresentation: Hashable {
    let id = UUID(); let route: TeamInvitationRoute
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
@MainActor private struct TeamInvitationDestination: View {
    let route: TeamInvitationRoute
    let makeCoordinator: () -> TeamCoordinator
    var onLogin: (() -> Void)?
    var body: some View {
        TeamDetailView(lookup: .invitation(route.code), coordinator: makeCoordinator(), makeCoordinator: makeCoordinator)
            .toolbar { if let onLogin { Button("team.signIn", action: onLogin) } }
    }
}

/// Normal wall entry for a source /badge query link. HTTPS links still go through the
/// separate approved-origin router; this form accepts only the documented relative path.
@MainActor struct BadgeRouteEntryView: View {
    let reader: any ProfileReading
    var media: (any ObjectCardImageLoading)? = nil
    @State private var text = ""
    @State private var route: BadgeRoutePresentation?
    @State private var invalid = false
    @State private var scope = UUID()
    var body: some View {
        Form {
            TextField("nativeNav.badge.path", text: $text, axis: .vertical)
                .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityIdentifier("nativeNav.badge.path")
            Text("nativeNav.badge.notice").cyText(.bodyCompact)
            Button("nativeNav.open") {
                guard case .badge(let parameters) = NativeNavigationContract.parseInternal(text) else { invalid = true; return }
                invalid = false; route = BadgeRoutePresentation(parameters: parameters, scope: scope)
            }.disabled(text.isEmpty)
            if invalid { Text("nativeNav.invalid") }
        }.navigationTitle("nativeNav.badge.open").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $route) { target in Group {
                NavigationStack {
                    ObjectBadgeRoutePreview(parameters: target.parameters, expectedScope: target.scope, currentScope: { scope }, media: media)
                        .toolbar { Button("nativeNav.close") { route = nil } }
                }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: reader.identity) { _, _ in scope = UUID(); route = nil; text = "" }
            .onDisappear { scope = UUID(); route = nil }
    }
}
private struct BadgeRoutePresentation: Identifiable {
    let id = UUID(); let parameters: ObjectBadgeDetailParameters; let scope: UUID
}
