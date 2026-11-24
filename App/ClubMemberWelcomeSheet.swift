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
            ScrollView {
                VStack(spacing: CYSpacing.xl) {
                    VStack(spacing: CYSpacing.md) {
                        CYBadgeMedal(seed: value.club.name.isEmpty ? "club" : value.club.name, symbol: "person.3.fill", size: 116)
                            .cyStampSlam(trigger: true)
                            .overlay { CYConfettiBurst(fireOnAppear: true).frame(height: 200) }
                            .overlay { CYOrbitDots(fire: arrived, radius: 70, spread: 22) }
                            .padding(.top, CYSpacing.lg)
                        // CLB-detail-29 (parity r2): MP 欢迎加入「name」 as one title.
                        Group {
                            if value.club.name.isEmpty { Text("welcome.title", tableName: "ClubMemberWelcome") }
                            else { Text("welcome.titleNamed \(value.club.name)", tableName: "ClubMemberWelcome") }
                        }
                        .cyText(.sheetTitle)  // CLB-detail-40: MP welcome title is the sheet title size
                        .foregroundStyle(CYColor.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    }
                    .frame(maxWidth: .infinity)
                    .cyHaptic(.success, trigger: arrived)
                    if let note = value.club.welcomeNote, !note.isEmpty {
                        VStack(alignment: .leading, spacing: CYSpacing.sm) {
                            Text("welcome.note", tableName: "ClubMemberWelcome").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            Text(verbatim: note).cyText(.body).foregroundStyle(CYColor.textPrimary).textSelection(.enabled)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(CYSpacing.lg)
                        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        step("text.bubble", Text(LocalizedStringKey(value.postingKey), tableName: "ClubMemberWelcome"))
                        Divider().overlay(CYColor.borderSubtle).padding(.leading, 52)
                        step("calendar", Text(LocalizedStringKey(value.eventsKey), tableName: "ClubMemberWelcome"))
                        Divider().overlay(CYColor.borderSubtle).padding(.leading, 52)
                        step("person.3", Text("welcome.overview", tableName: "ClubMemberWelcome"))
                        if let memberPriceText {
                            // cursor/core-club hand-off (CLB-detail-29): the member price perk, shown only when Core
                            // has one. Owner decision 9: two decimals through the shared `MoneyDisplay`.
                            Divider().overlay(CYColor.borderSubtle).padding(.leading, 52)
                            step("tag", Text("club.welcome.memberPrice \(memberPriceText)"))
                                .accessibilityIdentifier("club.welcome.memberPrice")
                        }
                    }
                    .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                }
                .padding(.horizontal, CYSpacing.xxl)
                .padding(.bottom, CYSpacing.lg)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: CYSpacing.sm) {
                    Button(action: goEvents) { Text("welcome.events", tableName: "ClubMemberWelcome") }
                        .buttonStyle(.cyPrimary)
                        .accessibilityIdentifier("club.welcome.events")
                    Button(action: close) { Text("welcome.gotIt", tableName: "ClubMemberWelcome").frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget) }
                        .cyText(.bodyMedium)
                        .foregroundStyle(CYColor.textSecondary)
                        .accessibilityIdentifier("club.welcome.close")
                }
                .padding(.horizontal, CYSpacing.xxl)
                .padding(.vertical, CYSpacing.md)
                .background(CYColor.bgPage)
            }
            .background(CYColor.bgPage)
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
        HStack(spacing: CYSpacing.md) {
            Image(systemName: symbol).foregroundStyle(CYColor.textPrimary).frame(width: 24)
            text.cyText(.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
        }
            .padding(CYSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
