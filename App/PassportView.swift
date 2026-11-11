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
    var body: some View {
        AccountView(account: account, privateHomeCoordinator: privateHomeCoordinator,
                    nativeHomeReturnSelection: nativeHomeReturnSelection, onOpenGuideDestination: onOpenGuideDestination,
                    showsPassportOverview: true)
    }
}

/// Number of stamp slots drawn in the grid. A slot past the earned count is a locked silhouette.
enum PassportStampGrid {
    static let slots = 12
    /// `nil` (unknown) locks every slot; a known count fills the first `min(count, slots)`.
    static func earnedSlots(_ count: Int?) -> Int { max(0, min(count ?? 0, slots)) }
}

/// Loads the stamp count and hosts `PassportOverviewContent` as a Form section next to the identity card.
@MainActor struct PassportOverviewSection: View {
    let reader: any RoamExperienceReading
    var onOpenTickets: () -> Void
    var onOpenWallet: () -> Void
    var onOpenMessages: () -> Void
    @State private var stampCount: Int?

    var body: some View {
        Section {
            PassportOverviewContent(stampCount: stampCount, onOpenTickets: onOpenTickets, onOpenWallet: onOpenWallet, onOpenMessages: onOpenMessages)
        }
        .listRowBackground(CYColor.bgSurface)
        .task(id: ObjectIdentifier(reader)) { load() }
    }

    private func load() {
        // Local saved-record read only; failure leaves the count unknown (em dash).
        stampCount = (try? RoamPassportHome(records: try reader.history()))?.stamps
    }
}

/// Three circular actions + stamp grid. Pure presentation so fixtures can render every state.
@MainActor struct PassportOverviewContent: View {
    let stampCount: Int?
    var onOpenTickets: () -> Void = {}
    var onOpenWallet: () -> Void = {}
    var onOpenMessages: () -> Void = {}
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            actions
            stamps
        }
        .padding(.vertical, CYSpacing.xs)
    }

    private var actions: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            action("ticketWallet.title", "ticket", id: "passport.action.tickets", perform: onOpenTickets)
            action("wallet.title", "creditcard", id: "passport.action.wallet", perform: onOpenWallet)
            action("messaging.title", "bubble.left.and.bubble.right", id: "passport.action.messages", perform: onOpenMessages)
        }
        .frame(maxWidth: .infinity)
    }

    private func action(_ title: LocalizedStringKey, _ symbol: String, id: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            VStack(spacing: CYSpacing.xs) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(CYColor.bgSurfaceSubtle))
                    .accessibilityHidden(true)
                Text(title)
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.cyPressable)
        .accessibilityIdentifier(id)
    }

    private var stamps: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            HStack {
                Text("passport.stamps.title").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                Spacer(minLength: CYSpacing.sm)
                Group {
                    if let stampCount { Text("passport.stamps.count \(PassportStampGrid.earnedSlots(stampCount)) \(PassportStampGrid.slots)") }
                    else { Text(verbatim: "—") }
                }
                .font(CYTypography.meta).monospacedDigit().foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("passport.stamps.count")
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 88 : 64), spacing: CYSpacing.md)], spacing: CYSpacing.md) {
                ForEach(0..<PassportStampGrid.slots, id: \.self) { index in
                    slot(earned: index < PassportStampGrid.earnedSlots(stampCount))
                        .accessibilityIdentifier("passport.stamp.\(index)")
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("passport.stampGrid")
    }

    @ViewBuilder private func slot(earned: Bool) -> some View {
        ZStack {
            Circle().fill(earned ? CYColor.bgElevated : CYColor.bgSurfaceSubtle)
            Circle().strokeBorder(CYColor.borderSubtle, style: StrokeStyle(lineWidth: 1, dash: earned ? [] : [4, 3]))
            Image(systemName: earned ? "seal.fill" : "seal")
                .font(.title3)
                .foregroundStyle(earned ? CYColor.textPrimary : CYColor.textPlaceholder)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(earned ? LocalizedStringKey("passport.stamp.earned") : LocalizedStringKey("passport.stamp.locked")))
    }
}
