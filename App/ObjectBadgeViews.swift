import SwiftUI

/// Local presentation choice over the same authorized badge result. No renderer or read capability is added.
enum ObjectBadgeWallLayout: String, CaseIterable {
    case list, wall
    var titleKey: String { "objects.badgeLayout." + rawValue }
}
struct ObjectBadgeWallLayoutOwner: Equatable {
    let readerID: ObjectIdentifier
    let identity: ProfileReadIdentity?
    let isConfigured: Bool
}
struct ObjectBadgeWallLayoutSelection {
    private var owner: ObjectBadgeWallLayoutOwner?
    private var layout: ObjectBadgeWallLayout = .list
    func value(for current: ObjectBadgeWallLayoutOwner) -> ObjectBadgeWallLayout {
        owner == current && current.identity != nil && current.isConfigured ? layout : .list
    }
    mutating func choose(_ next: ObjectBadgeWallLayout, rendered: ObjectBadgeWallLayoutOwner, current: ObjectBadgeWallLayoutOwner) {
        guard rendered == current, current.identity != nil, current.isConfigured else { return }
        owner = current; layout = next
    }
    mutating func retire() { owner = nil; layout = .list }
}

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
        let layout = ObjectBadgeWallLayout.wall
        LazyVGrid(columns: badgeWallColumns, alignment: .leading, spacing: CYCollectionGrid.spacing) {
            ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                link(slot.badge, identifier: slot.identifier, albumID: slot.identifier, layout: layout, wall: wall).buttonStyle(.plain)
            }
        }.padding(.vertical, 4)
    }
    private func link(_ badge: ProfileBadgeSelection, identifier: String, albumID: String, layout: ObjectBadgeWallLayout, wall: ProfileBadgeWall) -> some View {
        let capturedIdentity = reader.identity
        let media = self.media ?? envMedia
        let isNew = ObjectBadgeAlbumItem.isNew(badge) && !seen.contains(ObjectBadgeAlbumItem.seenKey(badge))
        return NavigationLink {
            ObjectBadgeDetailView(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media,
                                  collection: wall.isPartial ? nil : ObjectBadgeWallSummary(wall: wall))
                .modifier(ObjectBadgeThreeDEntry(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media))
                .cyHeroDestination(albumID, in: hero)
        } label: {
            ObjectBadgeWallBadgeLabel(badge: badge, layout: layout, isNew: isNew)
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

/// This control is a separate list section, never nested inside a badge's navigation link.
struct ObjectBadgeWallLayoutControl: View {
    @Binding var selection: ObjectBadgeWallLayout
    var body: some View {
        Picker("objects.badgeLayout.title", selection: $selection) {
            ForEach(ObjectBadgeWallLayout.allCases, id: \.rawValue) { layout in
                Text(LocalizedStringKey(layout.titleKey)).tag(layout)
            }
        }.pickerStyle(.segmented).labelsHidden().frame(minHeight: 44)
            .accessibilityLabel(Text("objects.badgeLayout.title"))
            .accessibilityIdentifier("objects.badge.layout")
    }
}
struct ObjectBadgeWallBadgeLabel: View {
    let badge: ProfileBadgeSelection
    let layout: ObjectBadgeWallLayout
    /// Unlocked within seven days and not opened yet: gold "new" pulse on the tile.
    var isNew = false
    @Environment(\.locale) private var locale
    var body: some View {
        if layout == .wall {
            VStack(spacing: CYSpacing.sm) {
                CYFoilMedal(unlocked: !badge.isLocked, size: 76) {
                    ZStack {
                        // BWALL-2: server `badge.image` through the bounded loader; MP `badge-demo.png` is the fallback.
                        ObjectBadgeTileArtwork(url: badge.image, locked: badge.isLocked).padding(CYSpacing.xs)
                    }
                }.padding(6).accessibilityHidden(true)   // the name + locked chip carry the meaning
                description.fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 72)
                .cyDomainCard(padding: CYSpacing.md)
                .cyFoilSheen(active: !badge.isLocked)
                .cyLockedSilhouette(badge.isLocked, showsLock: false)
                .cyNewPulse(isNew, text: Text(verbatim: ChannelCopy.text("新", "New", locale: locale)))
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(verbatim: isNew ? ChannelCopy.text("新获得", "New", locale: locale) : ""))
        } else {
            HStack(spacing: CYSpacing.md) {
                CYBadgeMedal(seed: badge.name.isEmpty ? badge.image : badge.name, locked: badge.isLocked, size: 48)
                description
            }
            .accessibilityElement(children: .combine)
        }
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let badge: ProfileBadgeSelection
    let reader: any ProfileReading
    let expectedIdentity: ProfileReadIdentity?
    var media: (any ObjectCardImageLoading)? = nil
    /// Lit / total across the loaded wall; nil when the caller has no wall (the collection card is then hidden, never zero).
    var collection: ObjectBadgeWallSummary? = nil
    @State private var mediaScope = UUID()
    @State private var expiredScope = UUID()
    @State private var celebrate = false
    @State private var flipped = false
    @State private var celebrations = CYCelebrationCenter()
    @CYAlbumSeen private var seen
    private var valid: Bool { expectedIdentity != nil && reader.identity == expectedIdentity }
    private var track: Int {
        switch badge { case .identity(let value): return ObjectBadgePresentation.track(category: value.category); case .medal: return 1 }
    }
    private var tint: Color { [palette.success, Color(hue: 0.12, saturation: 0.7, brightness: 0.95), palette.warning, palette.textTertiary, palette.danger][track] }
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
    var body: some View {
        ScrollView {
            if !valid { Text("objects.sessionChanged").padding(CYSpacing.pageHorizontal) }
            else {
                VStack(spacing: CYSpacing.xl) {
                    stage
                    VStack(spacing: CYSpacing.sm) {
                        Text(verbatim: displayName).cyText(.display).multilineTextAlignment(.center)
                            .foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: CYSpacing.sm) { statusChips }
                            VStack(spacing: CYSpacing.sm) { statusChips }
                        }
                    }
                    requirementCard
                    if let collection, collection.total > 0 { collectionCard(collection) }
                }.padding(.horizontal, CYSpacing.pageHorizontal).padding(.top, CYSpacing.lg).padding(.bottom, CYSpacing.xxl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if valid, !badge.isLocked {
                ShareLink(item: ChannelCopy.text("我在「城瘾」点亮了徽章「\(displayName)」", "I earned the “\(displayName)” badge on 城瘾", locale: locale)) {
                    Label { Text(verbatim: ChannelCopy.text("分享徽章", "Share badge", locale: locale)) } icon: { Image(systemName: "square.and.arrow.up") }
                        .cyText(.cardTitle).foregroundStyle(palette.actionPrimaryFg)
                        .frame(maxWidth: .infinity, minHeight: 56).background(palette.actionPrimaryBg, in: Capsule())
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md)
                .background(palette.bgPage.opacity(0.96))
                .accessibilityIdentifier("objects.badge.share")
            }
        }
        .background(palette.bgPage.ignoresSafeArea())
        .cyPageTitle("profile.badges.detail").privacySensitive().cyHideTabBar()
        .sensoryFeedback(.success, trigger: celebrate)
        .cyCelebrations(celebrations)
        .onAppear { arrive() }
        .accessibilityIdentifier("objects.badge.detail")
    }
    /// First open of a badge unlocked in the last seven days plays the badge bloom cover once (`CYBadgeUnlockCover`, the same
    /// one the Growth Center uses); every other unlocked badge keeps the quiet success tick. Locked badges arrive silently.
    private func arrive() {
        guard valid, !badge.isLocked else { return }
        let key = ObjectBadgeAlbumItem.seenKey(badge)
        if ObjectBadgeAlbumItem.isNew(badge), !key.isEmpty, !seen.contains(key) {
            $seen.mark(key)
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                celebrations.enqueue(.badge(CYBadgePayload(id: key, name: displayName)))
            }
        } else {
            celebrate = true
        }
    }
    /// Large foil medal that flips to its facts. No ring or percentage: the API has no per-badge progress, so the page only says collected or locked.
    private var stage: some View {
        CYFlipCard(flipped: $flipped, flipActionTitle: Text(verbatim: ChannelCopy.text("翻面", "Flip", locale: locale))) {
            medal
        } back: {
            stageBack
        }
        .frame(maxWidth: .infinity)
    }
    private var medal: some View {
        ZStack {
            CYFoilMedal(unlocked: !badge.isLocked, size: 168, tint: tint) {
                if media == nil || badge.image.isEmpty {
                    ZStack {
                        LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        // MP badge-3d `DEFAULT_BADGE_ASSET` (`badge-demo.png`, MP assets) when the badge has no art.
                        MPAsset.BadgeMedal.badgeDemo.resizable().scaledToFit().padding(CYSpacing.lg)
                            .scaleEffect(celebrate && !reduceMotion ? 1.06 : 1)
                            .animation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.4), value: celebrate)
                    }
                } else {
                    ObjectCardArtwork(url: badge.image, label: badge.name, media: media,
                        expectedScope: mediaScope, currentScope: { valid ? mediaScope : expiredScope })
                }
            }
        }
        .frame(width: 212, height: 212)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: displayName))
        .accessibilityHint(Text(verbatim: ChannelCopy.text("双击翻面查看详情", "Double-tap to flip for details", locale: locale)))
    }
    private var stageBack: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack {
                Text(badge.familyKey).cyText(.meta).foregroundStyle(palette.textSecondary)
                Spacer(minLength: CYSpacing.sm)
                Image(systemName: badge.isLocked ? "lock.fill" : "medal.fill")
                    .foregroundStyle(badge.isLocked ? palette.textTertiary : CYAlbumMotion.gold).accessibilityHidden(true)
            }
            Divider()
            Text(verbatim: displayName).cyText(.cardTitle).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            if let obtained, !obtained.isEmpty {
                CYFactRow(label: Text(verbatim: ChannelCopy.text("获得日期", "Earned on", locale: locale)), value: obtained)
            }
            CYFactRow(label: Text(verbatim: ChannelCopy.text("状态", "Status", locale: locale)),
                      value: ChannelCopy.text(badge.isLocked ? "未解锁" : "已点亮", badge.isLocked ? "Locked" : "Unlocked", locale: locale))
            Text(verbatim: ChannelCopy.text(badge.isLocked ? "如何点亮" : "获得条件", badge.isLocked ? "How to unlock" : "How it was earned", locale: locale))
                .cyText(.meta).foregroundStyle(palette.textSecondary)
            Text(verbatim: requirement.isEmpty ? CYAlbumCopy.unknownMark : requirement)
                .cyText(.body).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Text(verbatim: ChannelCopy.text("轻点翻回正面", "Tap to turn back", locale: locale))
                .cyText(.caption).foregroundStyle(palette.textTertiary)
        }
        .frame(maxWidth: .infinity, minHeight: 212, alignment: .topLeading)
        .cyAlbumCard(padding: CYSpacing.lg)
    }
    @ViewBuilder private var statusChips: some View {
        CYStatusChip(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked",
                     tone: badge.isLocked ? .neutral : .success, systemImage: badge.isLocked ? "lock.fill" : "checkmark.seal.fill")
        if let obtained, !obtained.isEmpty { CYStatusChip(verbatim: obtained) }
    }
    private var requirementCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: ChannelCopy.text(badge.isLocked ? "如何点亮" : "获得条件", badge.isLocked ? "How to unlock" : "How it was earned", locale: locale))
                .cyText(.sectionTitle).foregroundStyle(palette.textPrimary).accessibilityAddTraits(.isHeader)
            Text(verbatim: requirement.isEmpty ? "—" : requirement)
                .cyText(.body).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            if case .identity(let value) = badge, !value.statement.isEmpty, value.statement != requirement {
                Text(verbatim: value.statement).cyText(.meta).foregroundStyle(palette.textTertiary).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(CYSpacing.lg)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }
    private func collectionCard(_ summary: ObjectBadgeWallSummary) -> some View {
        CYInfoCard(title: Text(verbatim: ChannelCopy.text("我的收藏", "My collection", locale: locale)), symbol: "square.grid.2x2.fill") {
            CYCollectedLockedSummary(collected: summary.unlocked, locked: summary.locked)
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
    @State private var turntable: ObjectBadgeTurntable?
    var body: some View {
        let table = turntable ?? ObjectBadgeTurntable(style: parameters.style, reducedMotion: reduceMotion)
        VStack(spacing: CYSpacing.lg) {
            if currentScope() == expectedScope {
                if parameters.name.isEmpty { CYHeroHeader("profile.badges.detail") }
                else { CYHeroHeader(verbatim: parameters.name) }
                // Native turntable: drag to rotate, tap to spin a pin badge; static under Reduce Motion.
                ObjectCardArtwork(url: parameters.image, label: parameters.name, media: media,
                    expectedScope: expectedScope, currentScope: currentScope).frame(height: 200)
                    .rotation3DEffect(.degrees(table.angle), axis: (x: 0, y: 1, z: 0))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            var next = turntable ?? table
                            next.drag(translationWidth: Double(value.translation.width)); turntable = next
                        }
                        .onEnded { _ in
                            var next = turntable ?? table
                            next.endDrag(); turntable = next
                        })
                    .onTapGesture {
                        var next = turntable ?? table
                        next.tap()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { turntable = next }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        var next = turntable ?? table
                        next.tap()
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.8)) { turntable = next }
                    }
                    .accessibilityIdentifier("objects.badge.turntable")
                if let hint = table.hintKey {
                    Text(LocalizedStringKey(hint)).cyText(.meta).foregroundStyle(palette.textSecondary)
                        .accessibilityIdentifier("objects.badge.turntableHint")
                }
                if !parameters.subtitle.isEmpty {
                    CYListRow(verbatim: parameters.subtitle, trailing: .none, card: true) { EmptyView() }
                }
                HStack(spacing: CYSpacing.sm) {
                    CYStatusChip(LocalizedStringKey("objects.rarity." + String(parameters.rarity)), tone: .info)
                    CYStatusChip(LocalizedStringKey(parameters.style == "glow" ? "objects.glow" : (parameters.style == "pin" ? "objects.pin" : "objects.enamel")))
                }
            } else { CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "objects.sessionChanged") }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.player)
        .tint(CYDomainPalette(.player).brand)
        .cyPageTitle("profile.badges.detail")
        .cyHideTabBar()
        .privacySensitive()
    }
}
