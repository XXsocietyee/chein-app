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
    @State private var stampCount: Int?
    @State private var badges: [PassportBadge]?
    private struct LoadKey: Equatable { var stamps: ObjectIdentifier; var growth: ObjectIdentifier?; var refresh: Int }

    var body: some View {
        Section {
            PassportOverviewContent(stampCount: stampCount, badges: badges, onOpenTickets: onOpenTickets, onOpenWallet: onOpenWallet, onOpenMessages: onOpenMessages)
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
        // Local saved-record read only; failure leaves the count unknown (em dash).
        stampCount = (try? RoamPassportHome(records: try reader.history()))?.stamps
    }
}

/// Dark glass card used by the Passport blocks. Palette colours (not system-dynamic ones) so the card stays dark
/// in the player domain; Reduce Transparency swaps the material for the solid elevated fill.
private struct PassportGlassCard: ViewModifier {
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
        content
            .padding(CYSpacing.lg)
            .background {
                if reduceTransparency { shape.fill(palette.bgElevated) }
                else { shape.fill(.ultraThinMaterial).overlay(shape.fill(palette.bgGlass.opacity(0.55))) }
            }
            .overlay(shape.strokeBorder(palette.borderSubtle, lineWidth: 1))
    }
}

private extension View {
    func passportGlassCard() -> some View { modifier(PassportGlassCard()) }
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
        .minimumScaleFactor(0.6).lineLimit(1)
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
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    /// Glass circle scales with the glyph (Dynamic Type) so the icon never outgrows it.
    @ScaledMetric(relativeTo: .title3) private var actionCircle: CGFloat = 56

    /// One foil colour pair per stamp (by index), so a collection reads as distinct seals.
    private static let foils: [(Color, Color)] = [
        (Color(red: 1.00, green: 0.84, blue: 0.40), Color(red: 0.86, green: 0.55, blue: 0.16)),
        (Color(red: 0.62, green: 0.84, blue: 1.00), Color(red: 0.28, green: 0.52, blue: 0.92)),
        (Color(red: 0.62, green: 0.95, blue: 0.78), Color(red: 0.18, green: 0.64, blue: 0.48)),
        (Color(red: 1.00, green: 0.70, blue: 0.78), Color(red: 0.84, green: 0.30, blue: 0.48)),
        (Color(red: 0.88, green: 0.90, blue: 0.94), Color(red: 0.50, green: 0.55, blue: 0.64)),
        (Color(red: 1.00, green: 0.78, blue: 0.60), Color(red: 0.88, green: 0.42, blue: 0.24)),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            actions
            stamps.passportGlassCard()
            if badges?.isEmpty != true { badgeRail.passportGlassCard() }
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
                    .background {
                        if reduceTransparency { Circle().fill(palette.bgElevated) }
                        else { Circle().fill(.ultraThinMaterial).overlay(Circle().fill(palette.bgGlass.opacity(0.55))) }
                    }
                    .overlay(Circle().strokeBorder(LinearGradient(colors: [palette.borderStrong, palette.borderSubtle], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
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
                        .accessibilityIdentifier("passport.stamp.\(index)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.stampGrid")
    }

    /// Earned: foil seal in this stamp's colour with the one-shot sheen. Locked: ghost silhouette, dashed outline, low opacity.
    @ViewBuilder private func slot(index: Int, earned: Bool) -> some View {
        let foil = Self.foils[index % Self.foils.count]
        ZStack {
            if earned {
                Circle().fill(LinearGradient(colors: [foil.0, foil.1], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.85), foil.1.opacity(0.6)], startPoint: .top, endPoint: .bottom), lineWidth: 2)
                Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [2, 3])).padding(6)
                Image(systemName: "seal.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
            } else {
                Circle().strokeBorder(palette.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                Image(systemName: "seal").font(.title3).foregroundStyle(palette.textTertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .cyFoilSheen(active: earned, trigger: 0, cornerRadius: 64)
        .shadow(color: earned ? foil.1.opacity(0.35) : .clear, radius: 6, y: 3)
        .opacity(earned ? 1 : 0.35)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(earned ? LocalizedStringKey("passport.stamp.earned") : LocalizedStringKey("passport.stamp.locked")))
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
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.badgeRail")
    }
}
