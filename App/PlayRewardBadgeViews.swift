import SwiftUI

/// Source completion card: stable code, explicit collection readback, and Continue.
/// No timer dismisses the card and no local completion/award mutation is performed.
@MainActor struct PlayRewardBadgeRows: View {
    let targets: [PlayRewardBadgeTarget]
    var destination: ((PlayRewardBadgeTarget) -> AnyView)? = nil
    @State private var continued = false
    var body: some View {
        if !targets.isEmpty && !continued {
            VStack(alignment: .leading, spacing: 12) {
                // Unlock moment: medal lands with a spring, light confetti, success haptic (Reduce Motion: still).
                if let first = targets.first {
                    CYBadgeMedal(seed: first.name ?? first.code, size: 96)
                        .frame(maxWidth: .infinity)
                        .overlay { CYConfettiBurst(fireOnAppear: true).frame(height: 160) }
                        .cyStampSlam(trigger: true)
                }
                CYSectionHeader("playBadge.receipt")
                ForEach(targets) { target in
                    VStack(alignment: .leading, spacing: 6) {
                        // mp-journey r3 (MP pages/play/index.wxml `rdrop`): the reward, then 已记在你的收藏里, then 查看收藏 · 继续.
                        Text(verbatim: target.name ?? target.code).font(.headline).fixedSize(horizontal: false, vertical: true)
                        Text("playBadge.savedLine").cyText(.bodyCompact).foregroundStyle(.secondary)
                        if let destination {
                            NavigationLink { destination(target) } label: { Label("playBadge.open", systemImage: "medal") }
                                .accessibilityIdentifier("playBadge.open." + target.code)
                        } else { Text("playBadge.unavailable").cyText(.bodyCompact) }
                    }
                }
                CYPillButton("playBadge.continue") { continued = true }
                    .accessibilityIdentifier("playBadge.continue")
            }.accessibilityIdentifier("playBadge.receipt")
        }
    }
}

@MainActor struct PlayRewardBadgeCollectionView: View {
    let reader: any ProfileReading
    var growthReader: (any GrowthCenterReading)? = nil
    @State private var model: PlayRewardBadgeReadModel
    @State private var reads = ManualMapReadTaskOwner()
    init(target: PlayRewardBadgeTarget, reader: any ProfileReading, growthReader: (any GrowthCenterReading)? = nil,
         isCurrent: @escaping () -> Bool = { true }) {
        self.reader = reader; self.growthReader = growthReader
        _model = State(initialValue: PlayRewardBadgeReadModel(target: target, reader: reader, isCurrent: isCurrent))
    }
    var body: some View {
        List {
            if model.identity == nil { Text("profile.signInRequired") }
            else if !model.isConfigured { CYEmptyState(systemImage: "medal", "playBadge.unavailable") }
            else {
                Section {
                    Text(verbatim: model.target.name ?? model.target.code).cyText(.cardTitle)
                    LabeledContent("playBadge.code", value: model.target.code)
                    Text("playBadge.readbackHint").cyText(.bodyCompact).foregroundStyle(.secondary)
                }
                if model.isLoading { CYSkeleton(label: "profile.loading") }
                else if model.failed { Text("playBadge.failed").accessibilityIdentifier("playBadge.failed") }
                else if let focus = model.focus { PlayRewardBadgeFocusContent(focus: focus) }
                // BWALL-1: MP 查看收藏 reads the earned badge back on the wall (badge-wall?badgeCode=); 成长中心 stays secondary.
                Section {
                    NavigationLink("playBadge.openWall") { ObjectBadgeWallView(reader: reader, focusBadgeCode: model.target.code) }
                        .accessibilityIdentifier("playBadge.openWall")
                    if let growthReader {
                        NavigationLink("growth.title") { GrowthCenterView(reader: growthReader).id(growthReader.scope) }
                            .accessibilityIdentifier("playBadge.growth")
                    }
                }
            }
        }.cyGroupedSurface()
        .privacySensitive().navigationTitle("playBadge.collection").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("playBadge.collection")
        .toolbar {
            Button("profile.refresh", systemImage: "arrow.clockwise") { reads.start { await model.load() } }
                .disabled(model.isLoading || model.identity == nil || !model.isConfigured)
                .accessibilityIdentifier("playBadge.refresh")
        }
        .task(id: PlayRewardBadgeViewKey(identity: model.identity, configured: model.isConfigured)) {
            guard !Task.isCancelled else { return }
            reads.activate(); model.activate(); await reads.run { await model.load() }
        }
        .refreshable { await reads.run { await model.load() } }
        .onDisappear { reads.deactivate(); model.deactivate() }
    }
}

@MainActor struct PlayRewardBadgeFocusContent: View {
    let focus: PlayRewardBadgeFocus
    var body: some View {
        Section {
            Text(LocalizedStringKey(focus.statusKey)).cyText(.cardTitle)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(focus.statusKey)
            switch focus {
            case .identity(let badge):
                Text("profile.badges.identities").cyText(.meta)
                if !badge.badgeName.isEmpty { Text(verbatim: badge.badgeName) }
                ProfileOptionalRow(key: "profile.badges.statement", value: badge.statement)
                ProfileOptionalRow(key: "profile.badges.unlockHint", value: badge.unlockHint)
                if badge.unlocked { ProfileOptionalRow(key: "profile.badges.obtained", value: badge.unlockTime) }
            case .achievement(let badge):
                Text("profile.badges.achievements").cyText(.meta)
                if !badge.medalName.isEmpty { Text(verbatim: badge.medalName) }
                ProfileOptionalRow(key: "profile.badges.obtained", value: badge.getTime)
            case .missingFromWall, .incompleteWall, .ambiguous:
                Text("playBadge.notIssuanceProof").cyText(.meta).foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlayRewardBadgeViewKey: Hashable {
    let identity: ProfileReadIdentity?
    let configured: Bool
}
