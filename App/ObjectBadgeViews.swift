import SwiftUI

/// BWALL-3 grouping for the wall the server already returned. Lit identities stay in server order,
/// then city medals, then achievements. Locked identities stay in server order. Medals are lit.
/// A missing medal collection is not invented. Identifiers stay on the old family prefixes.
private enum ObjectBadgeWallColumns {
    struct Slot {
        let badge: ProfileBadgeSelection
        let identifier: String
    }
    static func split(_ wall: ProfileBadgeWall) -> (lit: [Slot], locked: [Slot]) {
        var lit: [Slot] = []
        var locked: [Slot] = []
        for (index, badge) in ObjectBadgeWallOrdering.litFirst(wall.identities).enumerated() {
            let slot = Slot(badge: .identity(badge), identifier: "profile.badge.identity.\(index)")
            if badge.unlocked { lit.append(slot) } else { locked.append(slot) }
        }
        if let medals = wall.medals {
            let city = medals.filter { !$0.isAchievement }
            let achievements = medals.filter(\.isAchievement)
            for (index, badge) in city.enumerated() {
                lit.append(Slot(badge: .medal(badge), identifier: "profile.badge.medal.\(index)"))
            }
            for (index, badge) in achievements.enumerated() {
                lit.append(Slot(badge: .medal(badge), identifier: "profile.badge.achievement.\(index)"))
            }
        }
        return (lit, locked)
    }
}

/// Additive replacement for the old wall's unrestricted AsyncImage and static detail.
/// Same ProfileService two-endpoint/partial-result reads; no new endpoint or model assets.
@MainActor struct ObjectBadgeWallView: View {
    let reader: any ProfileReading
    var media: (any ObjectCardImageLoading)? = nil
    /// Play-side badge code to read back on the loaded wall (source query `badgeCode`).
    var focusBadgeCode: String? = nil
    @Environment(\.objectCardMedia) private var envMedia
    @Environment(\.growthExploreHomeAction) private var onExploreHome
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.cyPalette) private var palette
    @Namespace private var hero
    @CYAlbumSeen private var seen
    @Environment(\.rootTabSwitch) private var rootTabSwitch
    /// BWALL-3: two columns at the default text size, one column when Dynamic Type is an accessibility size.
    private var badgeWallColumns: [GridItem] {
        let count = dynamicTypeSize.isAccessibilitySize ? 1 : 2
        return Array(repeating: GridItem(.flexible(), spacing: CYSpacing.md, alignment: .top), count: count)
    }
    var body: some View {
        // BWALL-5: the signed-out state offers 登录 (opens 我的) like the MP access gate.
        ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.badges", onSignIn: rootTabSwitch.isAvailable ? { rootTabSwitch(.mine) } : nil,
                          load: { try await reader.profileBadges() }) { wall in
            let groups = ObjectBadgeWallColumns.split(wall)
            List {
                ObjectBadgeWallParityHeader(wall: wall, focusBadgeCode: focusBadgeCode)
                if wall.isPartial {
                    Section {
                        Text("profile.badges.partial")
                        if let message = wall.medalFailureMessage, !message.isEmpty { Text(verbatim: message) }
                    }
                    .listRowBackground(palette.bgElevated)
                }
                if wall.isEmpty {
                    // Mini-program badge-wall empty: 还没有点亮勋章 with 去探索 when a home route is supplied.
                    // BWALL flows (MP goExplore → switchTab index): without an injected action the root tab switch (首页) is the fallback.
                    let explore = rootTabSwitch.growthExploreFallback(onExploreHome)
                    CYEmptyState(systemImage: "medal", "badgeWall.empty",
                                 actionTitle: explore == nil ? nil : "badgeWall.explore",
                                 actionIdentifier: "badgeWall.empty.explore", action: explore)
                        .accessibilityIdentifier("profile.badges.emptyState")
                        .listRowBackground(palette.bgElevated)
                }
                // BWALL-3: the wall is 已点亮 then 未解锁. Each group is a system grid, not a family list.
                if !groups.lit.isEmpty {
                    Section("profile.badges.unlocked") {
                        badgeGrid(groups.lit, wall: wall)
                    }
                    .listRowBackground(palette.bgElevated)
                }
                if !groups.locked.isEmpty {
                    Section("profile.badges.notUnlocked") {
                        badgeGrid(groups.locked, wall: wall)
                    }
                    .listRowBackground(palette.bgElevated)
                }
            }
        }.scrollContentBackground(.hidden).cyDomainPageBackground().cyAlbumChildTitle("profile.badges.title")
            .cyHideTabBar()
            // The typed internal badge-path entry is not a player feature and is not offered here.
    }
    @ViewBuilder private func badgeGrid(_ slots: [ObjectBadgeWallColumns.Slot], wall: ProfileBadgeWall) -> some View {
        LazyVGrid(columns: badgeWallColumns, alignment: .leading, spacing: CYCollectionGrid.spacing) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                link(slot.badge, identifier: slot.identifier, albumID: slot.identifier, wall: wall).buttonStyle(.plain)
            }
        }.padding(.vertical, 4)
    }
    private func link(_ badge: ProfileBadgeSelection, identifier: String, albumID: String, wall: ProfileBadgeWall) -> some View {
        let capturedIdentity = reader.identity
        let media = self.media ?? envMedia
        let isNew = ObjectBadgeAlbumItem.isNew(badge) && !seen.contains(ObjectBadgeAlbumItem.seenKey(badge))
        return NavigationLink {
            ObjectBadgeDetailView(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media,
                                  collection: wall.isPartial ? nil : ObjectBadgeWallSummary(wall: wall))
                .modifier(ObjectBadgeThreeDEntry(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media))
                .cyHeroDestination(albumID, in: hero)
        } label: {
            ObjectBadgeWallBadgeLabel(badge: badge, isNew: isNew)
                .cyHeroSource(albumID, in: hero)
        }.accessibilityIdentifier(identifier)
    }
}

/// Album identity for a badge: the badge code or medal template, so the "seen" memory and the showcase survive reloads.
/// Rows without any code share a family fallback and are simply never remembered as seen.
struct ObjectBadgeAlbumItem: Identifiable {
    let id: String
    let badge: ProfileBadgeSelection
    static func seenKey(_ badge: ProfileBadgeSelection) -> String {
        switch badge {
        case .identity(let value): return value.badgeCode.isEmpty ? "" : "identity.\(value.badgeCode)"
        case .medal(let value):
            if let template = value.templateID { return "medal.\(template)" }
            return value.badgeCode.isEmpty ? "" : "medal.\(value.badgeCode)"
        }
    }
    static func obtainedRaw(_ badge: ProfileBadgeSelection) -> String? {
        switch badge {
        case .identity(let value): return value.unlocked ? value.unlockTime : nil
        case .medal(let value): return value.getTime
        }
    }
    /// Unlocked within the last seven days. Locked badges are never new.
    static func isNew(_ badge: ProfileBadgeSelection) -> Bool {
        !badge.isLocked && CYAlbumRecency.isNew(obtainedRaw(badge))
    }
}

/// BWALL-3b (MP subpackageP3/badge-wall/index/index.wxml:46-63): one wall tile, the badge art over its name and meta.
/// Locked tiles are grayscale. No foil, sheen, pulse or card chrome.
struct ObjectBadgeWallBadgeLabel: View {
    let badge: ProfileBadgeSelection
    /// Unlocked within seven days and not opened yet; read out by VoiceOver.
    var isNew = false
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            // BWALL-2: server `badge.image` through the bounded loader; MP `badge-demo.png` is the fallback.
            ObjectBadgeTileArtwork(url: badge.image, locked: badge.isLocked)
                .frame(width: 76, height: 76)
                .grayscale(badge.isLocked ? 1 : 0)
            description.fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 72)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: isNew ? ChannelCopy.text("新获得", "New", locale: locale) : ""))
    }
    private var description: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            // Titles wrap on word boundaries only (one column at accessibility sizes keeps the width generous).
            Group { if badge.name.isEmpty { Text(badge.familyKey) } else { Text(verbatim: badge.name) } }
                .allowsTightening(true)
            // BWALL-5 (MP badge-wall wxml:38): locked → condition ?? 尚未点亮; lit → obtained date ?? 已点亮.
            Text(verbatim: Self.meta(badge, locale: locale)).cyText(.meta).foregroundStyle(.secondary)
                // The meta may be a condition or a date; VoiceOver still hears the lit state.
                .accessibilityValue(Text(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked"))
        }
    }

    static func meta(_ badge: ProfileBadgeSelection, locale: Locale) -> String {
        func nonempty(_ value: String?) -> String? {
            guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
            return value
        }
        /// MP `displayDate`: `YYYY-MM-DD` from a date or date-time string; anything else is not shown.
        func day(_ value: String?) -> String? {
            guard let value = nonempty(value), value.count >= 10 else { return nil }
            let head = String(value.prefix(10))
            return head.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) == nil ? nil : head
        }
        let condition: String?
        let obtained: String?
        switch badge {
        case .identity(let value): condition = nonempty(value.unlockHint); obtained = day(value.unlockTime)
        case .medal(let value): condition = nonempty(value.displayCondition); obtained = day(value.getTime)
        }
        if badge.isLocked { return condition ?? appLocalized("objects.badge.meta.locked", locale: locale) }
        return obtained ?? appLocalized("profile.badges.unlocked", locale: locale)
    }
}

@MainActor struct ObjectBadgeDetailView: View {
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    let badge: ProfileBadgeSelection
    let reader: any ProfileReading
    let expectedIdentity: ProfileReadIdentity?
    var media: (any ObjectCardImageLoading)? = nil
    /// Lit / total across the loaded wall; nil when the caller has no wall (the collection card is then hidden, never zero).
    var collection: ObjectBadgeWallSummary? = nil
    @State private var mediaScope = UUID()
    @State private var expiredScope = UUID()
    @State private var celebrate = false
    private var valid: Bool { expectedIdentity != nil && reader.identity == expectedIdentity }
    private var displayName: String { badge.name.isEmpty ? ChannelCopy.text("徽章", "Badge", locale: locale) : badge.name }
    private var obtained: String? {
        switch badge {
        case .identity(let value): return value.unlocked ? ObjectBadgePresentation.date(value.unlockTime) : nil
        case .medal(let value): return ObjectBadgePresentation.date(value.getTime)
        }
    }
    private var requirement: String {
        switch badge {
        case .identity(let value): return value.unlockHint.isEmpty ? value.statement : value.unlockHint
        case .medal(let value): return value.displayCondition
        }
    }
    /// N-r11-5 (MP subpackageP3/pages/badge-3d 2D fallback): an inset-grouped List with the badge image row and
    /// `LabeledContent` facts; no flip card, foil medal or bloom cover. The quiet success haptic stays.
    var body: some View {
        List {
            if !valid { Text("objects.sessionChanged") }
            else {
                Section {
                    artwork
                        .frame(width: 120, height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: .infinity)
                        .opacity(badge.isLocked ? 0.45 : 1)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(verbatim: displayName))
                    Text(verbatim: displayName).font(.title2.weight(.semibold))
                        .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                }
                Section {
                    LabeledContent(ChannelCopy.text("状态", "Status", locale: locale)) {
                        Label(badge.isLocked ? LocalizedStringKey("profile.badges.locked") : LocalizedStringKey("profile.badges.unlocked"),
                              systemImage: badge.isLocked ? "lock.fill" : "checkmark.seal.fill")
                    }
                    if let obtained, !obtained.isEmpty {
                        LabeledContent(ChannelCopy.text("获得日期", "Earned on", locale: locale), value: obtained)
                    }
                    LabeledContent(ChannelCopy.text("系列", "Series", locale: locale)) { Text(badge.familyKey) }
                }
                Section(ChannelCopy.text(badge.isLocked ? "如何点亮" : "获得条件", badge.isLocked ? "How to unlock" : "How it was earned", locale: locale)) {
                    Text(verbatim: requirement.isEmpty ? "—" : requirement)
                    if case .identity(let value) = badge, !value.statement.isEmpty, value.statement != requirement {
                        Text(verbatim: value.statement).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if let collection, collection.total > 0 {
                    Section(ChannelCopy.text("我的收藏", "My collection", locale: locale)) {
                        CYCollectedLockedSummary(collected: collection.unlocked, locked: collection.locked)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            if valid, !badge.isLocked {
                ShareLink(item: ChannelCopy.text("我在「城瘾」点亮了徽章「\(displayName)」", "I earned the “\(displayName)” badge on Chein", locale: locale)) {
                    Label { Text(verbatim: ChannelCopy.text("分享徽章", "Share badge", locale: locale)) } icon: { Image(systemName: "square.and.arrow.up") }
                        .cyText(.cardTitle).foregroundStyle(palette.actionPrimaryFg)
                        .frame(maxWidth: .infinity, minHeight: 56).background(palette.actionPrimaryBg, in: Capsule())
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md)
                .background(palette.bgPage.opacity(0.96))
                .accessibilityIdentifier("objects.badge.share")
            }
        }
        .cyPageTitle("profile.badges.detail").privacySensitive().cyHideTabBar()
        .sensoryFeedback(.success, trigger: celebrate)
        .onAppear { if valid, !badge.isLocked { celebrate = true } }
        .accessibilityIdentifier("objects.badge.detail")
    }
    @ViewBuilder private var artwork: some View {
        if media == nil || badge.image.isEmpty {
            // MP badge-3d `DEFAULT_BADGE_ASSET` (`badge-demo.png`) when the badge has no art.
            MPAsset.BadgeMedal.badgeDemo.resizable().scaledToFit()
        } else {
            ObjectCardArtwork(url: badge.image, label: badge.name, media: media,
                expectedScope: mediaScope, currentScope: { valid ? mediaScope : expiredScope })
        }
    }
}

/// For the existing /badge query route only. Identity category tracks are not rarity.
@MainActor struct ObjectBadgeRoutePreview: View {
    let parameters: ObjectBadgeDetailParameters
    let expectedScope: UUID
    let currentScope: () -> UUID
    var media: (any ObjectCardImageLoading)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    /// N-B3D (r10): the 2D fallback of MP subpackageP3/badge-3d: an inset-grouped List (image row, subtitle,
    /// rarity and style rows) under the system title. No 3D turntable.
    var body: some View {
        List {
            if currentScope() == expectedScope {
                Section {
                    ObjectCardArtwork(url: parameters.image, label: parameters.name, media: media,
                        expectedScope: expectedScope, currentScope: currentScope)
                        .frame(height: 200).frame(maxWidth: .infinity)
                        .accessibilityIdentifier("objects.badge.turntable")
                    if !parameters.subtitle.isEmpty { Text(verbatim: parameters.subtitle) }
                }
                Section {
                    Label(LocalizedStringKey("objects.rarity." + String(parameters.rarity)), systemImage: "sparkles")
                    Label(LocalizedStringKey(parameters.style == "glow" ? "objects.glow" : (parameters.style == "pin" ? "objects.pin" : "objects.enamel")),
                          systemImage: "seal")
                }
            } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "objects.sessionChanged") }
        }
        .listStyle(.insetGrouped)
        .themeDomain(.player)
        .navigationTitle(parameters.name.isEmpty ? appLocalized("profile.badges.detail", locale: locale) : parameters.name)
        .navigationBarTitleDisplayMode(.inline)
        .cyHideTabBar()
        .privacySensitive()
    }
}
