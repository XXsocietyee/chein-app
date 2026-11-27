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
                Text("team.page.legacyLink").font(.headline)
                Text("team.page.legacyLink.detail")
            } else {
                Text(failure == .cannotOpen ? "nativeNav.error.cannotOpen" : "nativeNav.error.detail")
            }
        } actions: {
            Button("homeFeed.title", action: goHome)
                .buttonStyle(.borderedProminent).controlSize(.large)
                .accessibilityIdentifier("nativeNav.error.home")
            Button("nativeNav.close") { dismiss() }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("nativeNav.error.close")
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
    /// MP PG-014 `_backToCodeEntry`: a code the server cannot resolve comes back to this field with the reason.
    @State private var lookupReason: LocalizedStringKey?
    @State private var looking = false
    private static let maxCodeLength = 40
    private func open() {
        guard !looking else { return }
        guard let value = try? TeamInvitationRoute(code: code) else { invalid = true; lookupReason = nil; return }
        invalid = false; lookupReason = nil
        Task { await lookUp(value) }
    }
    private func lookUp(_ value: TeamInvitationRoute) async {
        let coordinator = makeCoordinator()
        // Signed out or unconfigured: the invitation page owns those states (sign-in action, unconfigured copy).
        guard coordinator.authenticated, coordinator.configured else { proceed(value); return }
        looking = true
        await coordinator.loadDetail(.invitation(value.code))
        looking = false
        guard value.code == (try? TeamInvitationRoute(code: code))?.code else { return }
        if coordinator.detail != nil || coordinator.messageKey == "team.signIn" { proceed(value); return }
        lookupReason = Self.reason(coordinator)
    }
    private func proceed(_ value: TeamInvitationRoute) {
        if let onOpen { onOpen(value) } else { route = TeamInvitationPresentation(route: value) }
    }
    /// MP team/join index.js:154 and :168 reasons, in the same precedence.
    private static func reason(_ coordinator: TeamCoordinator) -> LocalizedStringKey {
        if coordinator.readFailure == .network { return "mpr3.team.joinCodeNetwork" }
        if coordinator.readFailure == .forbidden { return "mpr3.team.joinCodeForbidden" }
        if coordinator.readRefused { return "team.invite.unavailable" }
        return "team.page.inviteUnavailable"
    }
    var body: some View {
        Form {
            // MP team/join `?entry=code` (C-J1, wxml:24-30): the 加入码 field (≤ 40) with its error under it,
            // then 下一步 as the page's one primary button, which opens the invitation page.
            Section {
                LabeledContent {
                    TextField("nativeNav.team.codePlaceholder", text: $code)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .onChange(of: code) { _, value in
                            if value.count > Self.maxCodeLength { code = String(value.prefix(Self.maxCodeLength)) }
                            invalid = false; lookupReason = nil
                        }
                        .submitLabel(.next).onSubmit(open)
                        .accessibilityIdentifier("nativeNav.team.code")
                } label: { Text("nativeNav.team.code") }
            } footer: {
                if invalid {
                    Label("mpr3.team.joinCodeInvalid", systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("nativeNav.team.codeError")
                } else if let lookupReason {
                    Label(lookupReason, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("nativeNav.team.codeLookupError")
                }
            }
            Section {
                Button(action: open) {
                    // P10: while the code is looked up the button says so.
                    Group {
                        if looking { ProgressView { Text("mpr3.team.joinCodeLooking") } } else { Text("nativeNav.team.next") }
                    }
                    .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .disabled(looking || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("nativeNav.team.next")
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
            .cyPageTitle("team.invitation")
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
            Text("nativeNav.badge.notice").font(.subheadline).foregroundStyle(.secondary)
            Button("nativeNav.open") {
                guard case .badge(let parameters) = NativeNavigationContract.parseInternal(text) else { invalid = true; return }
                invalid = false; route = BadgeRoutePresentation(parameters: parameters, scope: scope)
            }.disabled(text.isEmpty)
            if invalid { Text("nativeNav.invalid") }
        }.navigationTitle("nativeNav.badge.open").navigationBarTitleDisplayMode(.inline)
            .cySheet(item: $route) { target in Group {
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
