import SwiftUI

@MainActor struct ClubMemberWelcomeHost: View {
    let club: ClubRecord
    let identity: ClubReadIdentity
    let namespace: String?
    let role: String?
    let active: Bool
    let goEvents: () -> Void
    @StateObject private var flow = ClubWelcomePresentation()
    @Environment(\.scenePhase) private var scenePhase
    private var current: Bool { active && scenePhase == .active && identity.isSignedIn && club.isJoined && !club.isOwner && !club.viewerIdentityUnavailable }
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onAppear { consider() }
            .onChange(of: club) { _, _ in consider() }
            .onChange(of: identity) { _, _ in flow.clear(); consider() }
            .onChange(of: namespace) { _, _ in flow.clear(); consider() }
            .onChange(of: role) { _, _ in consider() }
            .onChange(of: current) { _, _ in consider() }
            .onDisappear { flow.clear() }
            .sheet(item: Binding(get: { current ? flow.presentation : nil }, set: { value in if value == nil { flow.clear() } })) { original in Group {
                ClubMemberWelcomeLiveSheet(flow: flow, originalID: original.id, close: { flow.dismiss(original.id) }, goEvents: {
                    guard current, flow.presentation?.id == original.id, original.identity == identity,
                          original.club.id == club.id, original.namespace == namespace else { return }
                    flow.dismiss(original.id); goEvents()
                })
            }.cySheet()
            }
    }
    private func consider() { flow.consider(club: club, identity: identity, namespace: namespace, role: role, active: current) }
}
@MainActor private struct ClubMemberWelcomeLiveSheet: View {
    @ObservedObject var flow: ClubWelcomePresentation
    let originalID: UUID
    let close: () -> Void
    let goEvents: () -> Void
    var body: some View {
        if let current = flow.presentation, current.id == originalID {
            ClubMemberWelcomeSheet(value: current, close: close, goEvents: goEvents)
        }
    }
}
/// Join moment: the club medal lands with a spring and light confetti, success haptic, then the three first
/// steps as one quiet card and a single primary action (events). "Got it" is the quiet secondary.
@MainActor struct ClubMemberWelcomeSheet: View {
    let value: ClubMemberWelcome
    let close: () -> Void
    let goEvents: () -> Void
    @State private var arrived = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.fill")
                            .font(.largeTitle)
                            .imageScale(.large)
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        // CLB-detail-29 (parity r2): MP 欢迎加入「name」 as one title.
                        Group {
                            if value.club.name.isEmpty { Text("welcome.title", tableName: "ClubMemberWelcome") }
                            else { Text("welcome.titleNamed \(value.club.name)", tableName: "ClubMemberWelcome") }
                        }
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .cyHaptic(.success, trigger: arrived)
                }
                if let note = value.club.welcomeNote, !note.isEmpty {
                    Section {
                        Text(verbatim: note).textSelection(.enabled)
                    } header: {
                        Text("welcome.note", tableName: "ClubMemberWelcome")
                    }
                }
                if let perk = value.memberPricePerk {
                    Section {
                        Text(verbatim: perk)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("club.welcome.memberPrice")
                    }
                }
                Section {
                    step("text.bubble", Text(LocalizedStringKey(value.postingKey), tableName: "ClubMemberWelcome"))
                    step("calendar", Text(LocalizedStringKey(value.eventsKey), tableName: "ClubMemberWelcome"))
                    step("person.3", Text("welcome.overview", tableName: "ClubMemberWelcome"))
                    if let memberPriceText {
                        // cursor/core-club hand-off (CLB-detail-29): the member price perk, shown only when Core
                        // has one. Owner decision 9: two decimals through the shared `MoneyDisplay`.
                        step("tag", Text("club.welcome.memberPrice \(memberPriceText)"))
                            .accessibilityIdentifier("club.welcome.memberPrice")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button(action: goEvents) {
                        Text("welcome.events", tableName: "ClubMemberWelcome")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("club.welcome.events")
                    Button(action: close) {
                        Text("welcome.gotIt", tableName: "ClubMemberWelcome")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.large)
                    .accessibilityIdentifier("club.welcome.close")
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.bar)
            }
            .onAppear { arrived = true }
            .navigationBarTitleDisplayMode(.inline)
            // CLB-detail-29: two exits are enough (去看活动 / 知道了, plus the drag); no toolbar 关闭.
        }
    }
    /// Server text wins (as `ClubMemberWelcome.memberPricePerk` does); otherwise `MoneyDisplay.yuan` (¥12.50).
    private var memberPriceText: String? {
        guard value.memberPricePerk != nil, let price = value.club.memberDiscountPrice else { return nil }
        if let text = value.club.memberDiscountPriceText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        return MoneyDisplay.yuan(Decimal(price))
    }

    private func step(_ symbol: String, _ text: Text) -> some View {
        Label {
            text.fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
    }
}
