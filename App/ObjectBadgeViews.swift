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

/// Additive replacement for the old wall's unrestricted AsyncImage and static detail.
/// Same ProfileService two-endpoint/partial-result reads; no new endpoint or model assets.
@MainActor struct ObjectBadgeWallView: View {
    let reader: any ProfileReading
    var media: (any ObjectCardImageLoading)? = nil
    /// Play-side badge code to read back on the loaded wall (source query `badgeCode`).
    var focusBadgeCode: String? = nil
    @State private var layoutSelection = ObjectBadgeWallLayoutSelection()
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var layoutOwner: ObjectBadgeWallLayoutOwner {
        .init(readerID: ObjectIdentifier(reader), identity: reader.identity, isConfigured: reader.isConfigured)
    }
    var body: some View {
        let owner = layoutOwner
        let layout = layoutSelection.value(for: owner)
        ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.badges", load: { try await reader.profileBadges() }) { wall in
            List {
                ObjectBadgeWallParityHeader(wall: wall, focusBadgeCode: focusBadgeCode)
                Section {
                    ObjectBadgeWallLayoutControl(selection: Binding(
                        get: { layoutSelection.value(for: layoutOwner) },
                        set: { layoutSelection.choose($0, rendered: owner, current: layoutOwner) }))
                }
                if wall.isPartial {
                    Section {
                        Text("profile.badges.partial")
                        if let message = wall.medalFailureMessage, !message.isEmpty { Text(verbatim: message) }
                    }
                }
                if wall.isEmpty {
                    CYEmptyState(systemImage: "medal", "profile.badges.empty")
                        .accessibilityIdentifier("profile.badges.emptyState")
                }
                if !wall.identities.isEmpty {
                    Section("profile.badges.identities") {
                        badgeRows(ObjectBadgeWallOrdering.litFirst(wall.identities).map { .identity($0) }, accessibilityPrefix: "profile.badge.identity", layout: layout, wall: wall)
                    }
                }
                if let medals = wall.medals {
                    let city = medals.filter { !$0.isAchievement }
                    let achievements = medals.filter(\.isAchievement)
                    if !city.isEmpty {
                        Section("profile.badges.medals") {
                            badgeRows(city.map { .medal($0) }, accessibilityPrefix: "profile.badge.medal", layout: layout, wall: wall)
                        }
                    }
                    if !achievements.isEmpty {
                        Section("profile.badges.achievements") {
                            badgeRows(achievements.map { .medal($0) }, accessibilityPrefix: "profile.badge.achievement", layout: layout, wall: wall)
                        }
                    }
                }
            }
        }.scrollContentBackground(.hidden).cyDomainPageBackground().appNavigationTitle("profile.badges.title")
            // The typed internal badge-path entry is not a player feature and is not offered here.
            .onChange(of: layoutOwner) { _, _ in layoutSelection.retire() }
    }
    @ViewBuilder private func badgeRows(_ badges: [ProfileBadgeSelection], accessibilityPrefix: String, layout: ObjectBadgeWallLayout, wall: ProfileBadgeWall) -> some View {
        if layout == .wall {
            LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize
                ? [GridItem(.flexible(), alignment: .topLeading)]
                : [GridItem(.adaptive(minimum: 160), spacing: 12, alignment: .topLeading)], alignment: .leading, spacing: 12) {
                ForEach(Array(badges.enumerated()), id: \.offset) { index, badge in
                    link(badge, identifier: "\(accessibilityPrefix).\(index)", layout: layout, wall: wall).buttonStyle(.plain)
                }
            }.padding(.vertical, 4)
        } else {
            ForEach(Array(badges.enumerated()), id: \.offset) { index, badge in
                link(badge, identifier: "\(accessibilityPrefix).\(index)", layout: layout, wall: wall)
            }
        }
    }
    private func link(_ badge: ProfileBadgeSelection, identifier: String, layout: ObjectBadgeWallLayout, wall: ProfileBadgeWall) -> some View {
        let capturedIdentity = reader.identity
        return NavigationLink {
            ObjectBadgeDetailView(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media,
                                  collection: wall.isPartial ? nil : ObjectBadgeWallSummary(wall: wall))
                .modifier(ObjectBadgeThreeDEntry(badge: badge, reader: reader, expectedIdentity: capturedIdentity, media: media))
        } label: {
            ObjectBadgeWallBadgeLabel(badge: badge, layout: layout)
        }.accessibilityIdentifier(identifier)
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
    var body: some View {
        if layout == .wall {
            VStack(spacing: CYSpacing.sm) {
                CYFoilMedal(unlocked: !badge.isLocked, size: 76) {
                    ZStack {
                        LinearGradient(colors: [Color(hue: 0.12, saturation: 0.7, brightness: 0.9).opacity(0.9), Color(hue: 0.08, saturation: 0.7, brightness: 0.4)], startPoint: .top, endPoint: .bottom)
                        Image(systemName: "medal.fill").font(.title2).foregroundStyle(.white.opacity(0.9))
                    }
                }.padding(6)
                description.fixedSize(horizontal: false, vertical: true).multilineTextAlignment(.center)
            }.frame(maxWidth: .infinity, minHeight: 72)
                .cyDomainCard(padding: CYSpacing.md)
                .accessibilityElement(children: .combine)
        } else {
            HStack {
                CYRowIcon(systemImage: badge.isLocked ? "lock" : "medal")
                description
            }
            .accessibilityElement(children: .combine)
        }
    }
    private var description: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            if badge.name.isEmpty { Text(badge.familyKey) } else { Text(verbatim: badge.name) }
            CYStatusChip(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked", tone: badge.isLocked ? .neutral : .success)
        }
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
                        Text(verbatim: displayName).font(CYTypography.display).multilineTextAlignment(.center)
                            .foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: CYSpacing.sm) {
                            CYStatusChip(badge.isLocked ? "profile.badges.locked" : "profile.badges.unlocked",
                                         tone: badge.isLocked ? .neutral : .success, systemImage: badge.isLocked ? "lock.fill" : "checkmark.seal.fill")
                            if let obtained, !obtained.isEmpty { CYStatusChip(verbatim: obtained) }
                        }
                    }
                    requirementCard
                    if let collection, collection.total > 0 { collectionCard(collection) }
                }.padding(.horizontal, CYSpacing.pageHorizontal).padding(.top, CYSpacing.lg).padding(.bottom, CYSpacing.xxl)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if valid, !badge.isLocked {
                ShareLink(item: ChannelCopy.text("我在「成印」点亮了徽章「\(displayName)」", "I earned the “\(displayName)” badge on Chengyin", locale: locale)) {
                    Label { Text(verbatim: ChannelCopy.text("分享徽章", "Share badge", locale: locale)) } icon: { Image(systemName: "square.and.arrow.up") }
                        .font(CYTypography.cardTitle).foregroundStyle(CYColor.textInverse)
                        .frame(maxWidth: .infinity, minHeight: 56).background(CYColor.textPrimary, in: Capsule())
                }
                .padding(.horizontal, CYSpacing.pageHorizontal).padding(.vertical, CYSpacing.md)
                .background(CYColor.bgPage.opacity(0.96))
                .accessibilityIdentifier("objects.badge.share")
            }
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .appNavigationTitle("profile.badges.detail").privacySensitive()
        .sensoryFeedback(.success, trigger: celebrate)
        .onAppear { if valid, !badge.isLocked { celebrate = true } }
        .accessibilityIdentifier("objects.badge.detail")
    }
    /// Large foil medal with a requirement ring around it: full when earned, an empty track while locked (no per-badge progress is available).
    private var stage: some View {
        CYProgressRing(progress: badge.isLocked ? nil : 1, lineWidth: 6, tint: tint.opacity(0.9), track: CYColor.bgRaised) {
            CYFoilMedal(unlocked: !badge.isLocked, size: 188, tint: tint) {
                if media == nil || badge.image.isEmpty {
                    ZStack {
                        LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)
                        Image(systemName: "medal.fill").font(.system(size: 76, weight: .semibold)).foregroundStyle(.white.opacity(0.92))
                            .symbolEffect(.bounce, value: celebrate && !reduceMotion)
                    }
                } else {
                    ObjectCardArtwork(url: badge.image, label: badge.name, media: media,
                        expectedScope: mediaScope, currentScope: { valid ? mediaScope : expiredScope })
                }
            }
        }
        .frame(width: 244, height: 244)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: displayName))
    }
    private var requirementCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: ChannelCopy.text(badge.isLocked ? "如何点亮" : "获得条件", badge.isLocked ? "How to unlock" : "How it was earned", locale: locale))
                .font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
            Text(verbatim: requirement.isEmpty ? "—" : requirement)
                .font(CYTypography.body).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true)
            if case .identity(let value) = badge, !value.statement.isEmpty, value.statement != requirement {
                Text(verbatim: value.statement).font(CYTypography.meta).foregroundStyle(CYColor.textTertiary).fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(CYSpacing.lg)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }
    private func collectionCard(_ summary: ObjectBadgeWallSummary) -> some View {
        HStack(spacing: CYSpacing.lg) {
            CYProgressRing(progress: Double(summary.unlocked) / Double(summary.total), lineWidth: 7, tint: tint) {
                Text(verbatim: "\(summary.unlocked)").font(CYTypography.dataXL).foregroundStyle(CYColor.textPrimary)
            }.frame(width: 76, height: 76)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ChannelCopy.text("已收集 \(summary.unlocked) / \(summary.total)", "\(summary.unlocked) of \(summary.total) collected", locale: locale))
                    .font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
                Text(verbatim: ChannelCopy.text("还有 \(summary.locked) 枚等你点亮", "\(summary.locked) still to unlock", locale: locale))
                    .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
            }
            Spacer(minLength: 0)
        }.padding(CYSpacing.lg)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .accessibilityElement(children: .combine)
    }
}

/// For the existing /badge query route only. Identity category tracks are not rarity.
@MainActor struct ObjectBadgeRoutePreview: View {
    let parameters: ObjectBadgeDetailParameters
    let expectedScope: UUID
    let currentScope: () -> UUID
    var media: (any ObjectCardImageLoading)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                    Text(LocalizedStringKey(hint)).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
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
        .appNavigationTitle("profile.badges.detail")
        .privacySensitive()
    }
}
