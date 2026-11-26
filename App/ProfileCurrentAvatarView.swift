import SwiftUI
import UIKit
import Observation

/// Mount ownership is distinct from scene activity. Foreground cannot resurrect a dismissed owner.
@MainActor @Observable final class ProfileSavedMediaVisibility {
    private(set) var mounted = false
    private(set) var active = false
    private(set) var lifetime = UUID()
    func appear(active: Bool) { mounted = true; scene(active: active) }
    func scene(active: Bool) {
        lifetime = UUID(); self.active = mounted && active
    }
    func disappear() { mounted = false; active = false; lifetime = UUID() }
    func matches(_ value: UUID) -> Bool { mounted && active && lifetime == value }
}

/// This is the saved self snapshot, never the staged upload or its moderation result.
@MainActor struct ProfileCurrentAvatarView: View {
    @ObservedObject var model: ProfileEditModel
    let reader: ProfileCurrentAvatarReader?
    @State private var visibility = ProfileSavedMediaVisibility()
    @State private var image: UIImage?
    @State private var loadedKey: ProfileCurrentAvatarReadKey?
    @State private var failedKey: ProfileCurrentAvatarReadKey?
    @State private var retry = 0
    @Environment(\.scenePhase) private var scenePhase
    private var key: ProfileCurrentAvatarReadKey? {
        guard visibility.active, scenePhase == .active, let snapshot = model.savedAvatarReadSnapshot else { return nil }
        return reader?.key(snapshot: snapshot, identity: model.coordinator.identity,
                           viewerRevision: model.coordinator.viewerRevision)
    }
    private var editBadge: some View {
        Image(systemName: "pencil.circle.fill").font(.title2)
            .symbolRenderingMode(.hierarchical).foregroundStyle(.tint)
            .accessibilityHidden(true)
    }
    private struct Load: Hashable {
        let key: ProfileCurrentAvatarReadKey?
        let retry: Int
        let lifetime: UUID
    }
    var body: some View {
        let load = Load(key: key, retry: retry, lifetime: visibility.lifetime)
        VStack(spacing: 8) {
            // MP gerenziliao.wxml:20 `.rv-bg` (default `/pages/gerenziliao/images/mer1.jpg`, js:71): kept as the one plain
            // header image of the first section (native r2: no fade, no overlay).
            Color.clear
                .frame(height: 120)
                .overlay { MPAsset.BannerCover.pagesGerenziliaoImagesMer1.resizable().scaledToFill() }
                .clipped()
                .accessibilityHidden(true)
            if let key, loadedKey == key, let image {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: 112, height: 112).clipShape(Circle())
                    .overlay(alignment: .bottomTrailing) { editBadge }
                    .accessibilityLabel(Text("profile.currentAvatar.saved", tableName: "ProfileCurrentMediaUI"))
            } else if let key, failedKey == key {
                Label { Text("profile.currentAvatar.failed", tableName: "ProfileCurrentMediaUI") } icon: { Image(systemName: "person.crop.circle.badge.exclamationmark") }
                Button("action.retry") { retry += 1 }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("profile.avatar.current.retry")
            } else if key != nil {
                ProgressView().frame(width: 112, height: 112)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text("profile.currentAvatar.loading", tableName: "ProfileCurrentMediaUI"))
                    .accessibilityIdentifier("profile.avatar.current.loading")
            } else {
                // MP gerenziliao.wxml:28 `avatarSrc || '/images/d_profile.png'`.
                MPAsset.AvatarDefault.dProfile.resizable().scaledToFill()
                    .frame(width: 112, height: 112).clipShape(Circle())
                    .overlay(alignment: .bottomTrailing) { editBadge }
                    .accessibilityHidden(true)
                (model.savedAvatarReadSnapshot?.avatar.isEmpty == true ? Text("profile.currentAvatar.empty", tableName: "ProfileCurrentMediaUI") : Text("profile.currentAvatar.unavailable", tableName: "ProfileCurrentMediaUI"))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("profile.avatar.current.unavailable")
            }
            // A3-10 (gerenziliao.wxml:31 `.rv-name`): the saved nickname under the centred avatar, 城瘾玩家 when empty.
            Group {
                if let name = model.coordinator.snapshot?.nickname.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                    Text(verbatim: name)
                } else {
                    Text("member.card.defaultName", tableName: "MemberProfile")
                }
            }
            .font(.title2.weight(.semibold)).foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("profile.avatar.current.name")
            Text("profile.currentAvatar.saved", tableName: "ProfileCurrentMediaUI").font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityIdentifier("profile.avatar.current")
        .privacySensitive()
        .task(id: load) {
            guard !Task.isCancelled, visibility.matches(load.lifetime), self.key == load.key else { return }
            image = nil; loadedKey = nil; failedKey = nil
            let lifetime = load.lifetime
            guard visibility.matches(lifetime), let key, let reader, let snapshot = model.savedAvatarReadSnapshot else { return }
            do {
                let bytes = try await reader.image(snapshot: snapshot, key: key,
                    currentSnapshot: { visibility.matches(lifetime) && self.key == key ? model.savedAvatarReadSnapshot : nil })
                try Task.checkCancellation()
                let clean = try RetainedImageSanitizer.sanitize(bytes)
                guard !Task.isCancelled, visibility.matches(lifetime), self.key == key else { return }
                guard let decoded = UIImage(data: clean.jpeg) else { throw RetainedImageFailure.invalid }
                image = decoded; loadedKey = key
            } catch {
                guard !Task.isCancelled, visibility.matches(lifetime), self.key == key else { return }
                failedKey = key
            }
        }
        .onAppear { visibility.appear(active: scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in
            visibility.scene(active: phase == .active); image = nil; loadedKey = nil; failedKey = nil
        }
        .onChange(of: key) { _, _ in image = nil; loadedKey = nil; failedKey = nil }
        .onDisappear { visibility.disappear(); image = nil; loadedKey = nil; failedKey = nil }
    }
}
