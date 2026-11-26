import SwiftUI

/// W1-4 Passport tab root. Wraps the existing `AccountView` (all of its rows and identifiers are kept) and adds the
/// skeleton from the UX strategy above the grouped list: three circular actions and a stamp grid with locked
/// silhouettes. The identity card is the existing `MemberIdentityCardSection`. No new data source: the stamp count
/// is `RoamPassportHome.stamps` from this device's saved roam records, and unknown shows an em dash, never 0.
@MainActor struct PassportView: View {
    let account: Account
    var privateHomeCoordinator: PrivateHomeCoordinator? = nil
    var nativeHomeReturnSelection: NativeHomeReturnSelectionCoordinator? = nil
    var onOpenGuideDestination: ((SocialGuideDestination) -> Void)? = nil
    /// chein://ticket/<id>: presents the existing ticket pass sheet once (AccountView clears it).
    var presentsTicketPass: Binding<Bool>? = nil
    var body: some View {
        AccountView(account: account, privateHomeCoordinator: privateHomeCoordinator,
                    nativeHomeReturnSelection: nativeHomeReturnSelection, onOpenGuideDestination: onOpenGuideDestination,
                    showsPassportOverview: true, presentsTicketPass: presentsTicketPass)
    }
}

/// Number of stamp slots drawn in the grid. A slot past the earned count is a locked silhouette.
enum PassportStampGrid {
    static let slots = 12
    /// `nil` (unknown) locks every slot; a known count fills the first `min(count, slots)`.
    static func earnedSlots(_ count: Int?) -> Int { max(0, min(count ?? 0, slots)) }
}

/// One earned badge from the existing growth center read (`GrowthCenterRecord.badges`). `name` nil renders the
/// generic "Badge" label; it is never invented.
struct PassportBadge: Identifiable, Equatable {
    let id: Int
    let name: String?
    init(index: Int, badge: GrowthCenterBadge) { id = index; name = badge.displayName }
    init(id: Int, name: String?) { self.id = id; self.name = name }
}

/// Loads the stamp count and badges and hosts `PassportOverviewContent` as a Form section next to the identity card.
@MainActor struct PassportOverviewSection: View {
    let reader: any RoamExperienceReading
    /// Existing growth center source; nil or unreadable leaves the badges unknown (em dash).
    var growth: (any GrowthCenterReading)? = nil
    var refreshToken = 0
    var onOpenTickets: () -> Void
    /// False when the host already shows 票夹 (the identity card's pill): one entry per destination on the page.
    var showsTicketsAction = true
    var onOpenWallet: () -> Void
    var onOpenMessages: () -> Void
    /// Stamp collection and badge rail each get one tap to their existing list (history / growth center); nil = static.
    var onOpenStamps: (() -> Void)? = nil
    var onOpenBadges: (() -> Void)? = nil
    @State private var stampCount: Int?
    @State private var stampPhase: StampPhase = .loading
    @State private var badges: [PassportBadge]?
    private enum StampPhase { case loading, ready, failed, offline }
    private struct LoadKey: Equatable { var stamps: ObjectIdentifier; var growth: ObjectIdentifier?; var refresh: Int }

    var body: some View {
        Section {
            switch stampPhase {
            case .loading:
                ProgressView().frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("cy.state.loading"))
                    .accessibilityIdentifier("passport.stamps.loading")
            case .offline:
                HStack {
                    Label("cy.state.offline.title", systemImage: "wifi.slash")
                    Spacer(minLength: 8)
                    Button("cy.state.offline.retry") { load() }.buttonStyle(.borderless)
                }
                .accessibilityIdentifier("passport.stamps.offline")
            case .failed:
                HStack {
                    Label("roam.experience.readFailed", systemImage: "exclamationmark.circle")
                    Spacer(minLength: 8)
                    Button("cy.state.offline.retry") { load() }.buttonStyle(.borderless)
                }
                .accessibilityIdentifier("passport.stamps.error")
            case .ready:
                EmptyView()
            }
            PassportOverviewContent(stampCount: stampCount, badges: badges, onOpenTickets: onOpenTickets, showsTicketsAction: showsTicketsAction, onOpenWallet: onOpenWallet, onOpenMessages: onOpenMessages, onOpenStamps: onOpenStamps, onOpenBadges: onOpenBadges)
        }
        .task(id: LoadKey(stamps: ObjectIdentifier(reader), growth: growth.map { ObjectIdentifier($0) }, refresh: refreshToken)) {
            load()
            await loadBadges()
        }
    }

    private func loadBadges() async {
        // Same source as the Growth Center; any failure (unconfigured, signed out, read error) is unknown, not "none".
        guard let growth, growth.isConfigured, growth.isAuthenticated,
              let center = (try? await growth.overview())?.center.value, !Task.isCancelled else { badges = nil; return }
        badges = center.badges.enumerated().map { PassportBadge(index: $0.offset, badge: $0.element) }
    }

    private func load() {
        // Local saved-record read only. A thrown read stays an em dash, and says whether it was offline.
        do {
            let records = try reader.history()
            stampCount = try RoamPassportHome(records: records).stamps
            stampPhase = .ready
        } catch is CancellationError {
            return
        } catch is URLError {
            stampCount = nil
            stampPhase = .offline
        } catch {
            stampCount = nil
            stampPhase = .failed
        }
    }
}

/// "3 of 12" header. Unknown (nil) is an em dash, never 0.
private struct PassportRollingCount: View {
    let value: Int?
    let total: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let value {
                Text(verbatim: "\(PassportStampGrid.earnedSlots(value))")
                    .font(.largeTitle.bold()).monospacedDigit()
                    .contentTransition(.numericText(value: Double(PassportStampGrid.earnedSlots(value))))
                Text("passport.stamps.ofTotal \(total)")
                    .font(.headline).monospacedDigit().foregroundStyle(.secondary)
            } else {
                Text(verbatim: "—").font(.largeTitle.bold()).foregroundStyle(.secondary)
            }
        }
    }
}

/// Three actions, stamp collection and the badge rail as grouped-list rows. Pure presentation so
/// fixtures can render every state.
@MainActor struct PassportOverviewContent: View {
    let stampCount: Int?
    /// nil = unknown (em dash); empty = known none (rail hidden); otherwise the earned badges.
    var badges: [PassportBadge]? = nil
    var onOpenTickets: () -> Void = {}
    var showsTicketsAction = true
    var onOpenWallet: () -> Void = {}
    var onOpenMessages: () -> Void = {}
    var onOpenStamps: (() -> Void)? = nil
    var onOpenBadges: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.cyOpenPassportStamp) private var openStamp

    var body: some View {
        Group {
            actions
            stamps
            if badges?.isEmpty != true { badgeRail }
        }
    }

    /// Contacts-style action buttons (bordered, symbol over label).
    private var actions: some View {
        HStack(alignment: .top, spacing: 8) {
            if showsTicketsAction {
                action("ticketWallet.title", "ticket", id: "passport.action.tickets", perform: onOpenTickets)
            }
            action("wallet.title", "creditcard", id: "passport.action.wallet", perform: onOpenWallet)
            action("messaging.title", "bubble.left.and.bubble.right", id: "passport.action.messages", perform: onOpenMessages)
        }
        .frame(maxWidth: .infinity)
    }

    private func action(_ title: LocalizedStringKey, _ symbol: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.title3)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityIdentifier(id)
    }

    private var stamps: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("passport.stamps.title").font(.subheadline).foregroundStyle(.secondary)
                PassportRollingCount(value: stampCount, total: PassportStampGrid.slots)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(stampCount.map { Text("passport.stamps.count \(PassportStampGrid.earnedSlots($0)) \(PassportStampGrid.slots)") } ?? Text(verbatim: "—"))
                    .accessibilityIdentifier("passport.stamps.count")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 88 : 64), spacing: 12)], spacing: 12) {
                ForEach(0..<PassportStampGrid.slots, id: \.self) { index in
                    slot(index: index, earned: index < PassportStampGrid.earnedSlots(stampCount))
                }
            }
            if let onOpenStamps { openRow("roam.experience.history", id: "passport.stamps.open", perform: onOpenStamps) }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.stampGrid")
    }

    /// Earned: filled seal in the accent colour. Locked: outline seal in the tertiary colour.
    /// With a host (`cyPassportStampHost`) the cell is a button that opens the stamp detail.
    @ViewBuilder private func slot(index: Int, earned: Bool) -> some View {
        let size: CGFloat = typeSize.isAccessibilitySize ? 64 : 44
        let seal = Image(systemName: earned ? "seal.fill" : "seal")
            .resizable()
            .scaledToFit()
            .foregroundStyle(earned ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            .frame(width: size, height: size)
            .accessibilityLabel(Text(earned ? LocalizedStringKey("passport.stamp.earned") : LocalizedStringKey("passport.stamp.locked")))
        Group {
        if let open = openStamp {
            Button { open(CYPassportStampSelection(index: index, earned: earned)) } label: { seal }
                .buttonStyle(.borderless)
                .frame(width: size, height: size)
                .contentShape(Circle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(earned ? LocalizedStringKey("passport.stamp.earned") : LocalizedStringKey("passport.stamp.locked")))
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("passport.stamp.\(index)")
        } else {
            seal
                .frame(width: size, height: size)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(earned ? LocalizedStringKey("passport.stamp.earned") : LocalizedStringKey("passport.stamp.locked")))
                .accessibilityIdentifier("passport.stamp.\(index)")
        }
        }
        // Zoom source for the stamp detail stays on the cell. Radius = exactly half the side (a true circle).
        .cyHeroSourceInherited(index, cornerRadius: size / 2)
        .frame(maxWidth: .infinity, minHeight: size)
    }

    private var badgeRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent {
                if let badges { Text(verbatim: "\(badges.count)").monospacedDigit() }
                else { Text(verbatim: "—") }
            } label: {
                Text("passport.badges.title")
            }
            if let badges {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(badges) { badge in
                            VStack(spacing: 4) {
                                Image(systemName: "rosette")
                                    .font(.largeTitle)
                                    .foregroundStyle(.tint)
                                    .accessibilityHidden(true)
                                Group { if let name = badge.name { Text(verbatim: name) } else { Text("growth.badge.unnamed") } }
                                    .font(.caption).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center).lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(width: typeSize.isAccessibilitySize ? 112 : 80)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("passport.badge.\(badge.id)")
                        }
                    }
                }
            }
            if let onOpenBadges { openRow("growth.title", id: "passport.badges.open", perform: onOpenBadges) }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.badgeRail")
    }

    /// "See all" link under a block: one tap from the Passport root to the full list.
    private func openRow(_ title: LocalizedStringKey, id: String, perform: @escaping () -> Void) -> some View {
        Button(title, action: perform)
            .buttonStyle(.borderless)
            .accessibilityIdentifier(id)
    }
}
