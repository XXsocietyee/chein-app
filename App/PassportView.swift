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
                CYLoadingStateView(rows: 1).accessibilityIdentifier("passport.stamps.loading")
            case .offline:
                CYOfflineBanner { load() }.accessibilityIdentifier("passport.stamps.offline")
            case .failed:
                CYInlineError("roam.experience.readFailed") { load() }.accessibilityIdentifier("passport.stamps.error")
            case .ready:
                EmptyView()
            }
            PassportOverviewContent(stampCount: stampCount, badges: badges, onOpenTickets: onOpenTickets, onOpenWallet: onOpenWallet, onOpenMessages: onOpenMessages, onOpenStamps: onOpenStamps, onOpenBadges: onOpenBadges)
        }
        // No white slab: the section rows are clear and each block below draws its own dark glass card.
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: CYSpacing.sm, leading: 0, bottom: CYSpacing.sm, trailing: 0))
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

private extension View {
    /// Borderless elevated card. Depth comes from the surface step, not a stroke.
    func passportFlatCard() -> some View { cyDomainCard(radius: Theme.Radius.lg, padding: CYSpacing.lg) }
}

/// Large rolling "3 of 12" header. Unknown (nil) is an em dash, never 0. Reduce Motion: final number at once.
private struct PassportRollingCount: View {
    let value: Int?
    let total: Int
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = 0

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
            if value != nil {
                Text(verbatim: "\(shown)")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold)).monospacedDigit()
                    .foregroundStyle(palette.textPrimary)
                    .contentTransition(.numericText(value: Double(shown)))
                Text("passport.stamps.ofTotal \(total)")
                    .font(CYTypography.cardTitle).monospacedDigit().foregroundStyle(palette.textSecondary)
            } else {
                Text(verbatim: "—").font(.system(.largeTitle, design: .rounded).weight(.bold)).foregroundStyle(palette.textTertiary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { reveal() }
        .onChange(of: value) { _, _ in reveal() }
    }

    private func reveal() {
        guard let value else { shown = 0; return }
        let target = PassportStampGrid.earnedSlots(value)
        if reduceMotion { shown = target } else { withAnimation(CYAlbumMotion.countUp) { shown = target } }
    }
}

/// Three circular actions, stamp collection (foil seals + ghost silhouettes) and the badge rail. Pure presentation so
/// fixtures can render every state.
@MainActor struct PassportOverviewContent: View {
    let stampCount: Int?
    /// nil = unknown (em dash); empty = known none (rail hidden); otherwise the earned badges.
    var badges: [PassportBadge]? = nil
    var onOpenTickets: () -> Void = {}
    var onOpenWallet: () -> Void = {}
    var onOpenMessages: () -> Void = {}
    var onOpenStamps: (() -> Void)? = nil
    var onOpenBadges: (() -> Void)? = nil
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.cyPalette) private var palette
    @Environment(\.cyOpenPassportStamp) private var openStamp
    /// Glass circle scales with the glyph (Dynamic Type) so the icon never outgrows it.
    @ScaledMetric(relativeTo: .title3) private var actionCircle: CGFloat = 56

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            actions
            stamps.passportFlatCard()
            if badges?.isEmpty != true { badgeRail.passportFlatCard() }
        }
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            action("ticketWallet.title", "ticket", id: "passport.action.tickets", perform: onOpenTickets)
            action("wallet.title", "creditcard", id: "passport.action.wallet", perform: onOpenWallet)
            action("messaging.title", "bubble.left.and.bubble.right", id: "passport.action.messages", perform: onOpenMessages)
        }
        .frame(maxWidth: .infinity)
    }

    /// Glass circle button; the label sits under it.
    private func action(_ title: LocalizedStringKey, _ symbol: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: CYSpacing.xs) {
                Image(systemName: symbol)
                    .font(.title3)
                    .dynamicTypeSize(...DynamicTypeSize.accessibility1) // glyph stops growing before three circles stop fitting in a row
                    .foregroundStyle(palette.textPrimary)
                    .frame(width: min(actionCircle, 84), height: min(actionCircle, 84))
                    .background(Circle().fill(palette.bgElevated))
                    .accessibilityHidden(true)
                Text(title)
                    .font(CYTypography.meta)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 2)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cyPressable)
        .accessibilityIdentifier(id)
    }

    private var stamps: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text("passport.stamps.title").font(CYTypography.meta).textCase(.uppercase).foregroundStyle(palette.textSecondary)
                PassportRollingCount(value: stampCount, total: PassportStampGrid.slots)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(stampCount.map { Text("passport.stamps.count \(PassportStampGrid.earnedSlots($0)) \(PassportStampGrid.slots)") } ?? Text(verbatim: "—"))
                    .accessibilityIdentifier("passport.stamps.count")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 88 : 64), spacing: CYSpacing.md)], spacing: CYSpacing.md) {
                ForEach(0..<PassportStampGrid.slots, id: \.self) { index in
                    slot(index: index, earned: index < PassportStampGrid.earnedSlots(stampCount))
                }
            }
            if let onOpenStamps { openRow("roam.experience.history", id: "passport.stamps.open", perform: onOpenStamps) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.stampGrid")
    }

    /// Earned: foil seal in this stamp's colour with the one-shot sheen. Locked: ghost silhouette, dashed outline, low opacity.
    /// With a host (`cyPassportStampHost`) the cell is a button: the seal zooms into the stamp detail (the same seal at 3.2x: 44 pt cell to 141 pt hero).
    @ViewBuilder private func slot(index: Int, earned: Bool) -> some View {
        let foil = CYStampSeal.foil(index)
        let size: CGFloat = typeSize.isAccessibilitySize ? 64 : 44
        let seal = CYStampSeal(index: index, earned: earned)
            .frame(width: size, height: size)
            .cyFoilSheen(active: earned, trigger: 0, cornerRadius: size / 2, foilStrength: 0.4)
            .shadow(color: earned ? foil.1.opacity(0.35) : .clear, radius: 6, y: 3)
            .opacity(earned ? 1 : 0.35)
        Group {
        if let open = openStamp {
            Button { open(CYPassportStampSelection(index: index, earned: earned)) } label: { seal }
                .buttonStyle(.cyPressable)
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
        // Outside the button so the zoom snapshots the seal, not the pressed label. Radius = exactly half the side (a true circle): a larger radius collapses the clip to a small diamond on iOS 27 and hid the whole seal.
        // The identifier stays on the seal-sized button. The cell only centres it; its wider frame was the gap MotionTour tapped.
        .cyHeroSourceInherited(index, cornerRadius: size / 2)
        .frame(maxWidth: .infinity, minHeight: size)
    }

    private var badgeRail: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                Text("passport.badges.title").font(CYTypography.meta).textCase(.uppercase).foregroundStyle(palette.textSecondary)
                Spacer(minLength: CYSpacing.sm)
                if let badges { Text(verbatim: "\(badges.count)").font(CYTypography.meta).monospacedDigit().foregroundStyle(palette.textSecondary) }
                else { Text(verbatim: "—").font(CYTypography.meta).foregroundStyle(palette.textTertiary) }
            }
            if let badges {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(badges) { badge in
                            VStack(spacing: CYSpacing.xs) {
                                CYBadgeMedal(seed: badge.name ?? "badge-\(badge.id)", size: 64)
                                    .cyFoilSheen(cornerRadius: 32)
                                Group { if let name = badge.name { Text(verbatim: name) } else { Text("growth.badge.unnamed") } }
                                    .font(CYTypography.meta).foregroundStyle(palette.textSecondary)
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
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.badgeRail")
    }

    /// Quiet "see all" row under a card: one tap from the Passport root to the full list.
    private func openRow(_ title: LocalizedStringKey, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack {
                Text(title).font(CYTypography.meta).foregroundStyle(palette.textSecondary)
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
