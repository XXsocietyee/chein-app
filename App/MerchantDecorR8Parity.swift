import SwiftUI

// fix/r8-merchant-coop (decor / node cluster): small native pieces mounted by the decor hub, the decor deep-link host,
// the profile editor and the city-node pages. No Core change; every write still goes through the existing reviewed save.

// MARK: - 申请入驻 on an inactive identity (MC8-20-1, MC8-22-1, MC8-24-7, MC8-25-2)

/// MP `cy-empty` + 去商家入驻 / 申请入驻 for a merchant page reached by an identity that is not active yet.
/// Uses the injected `merchantOpenApplication` (workbench root) when present; otherwise pushes the MP apply page
/// (`pages/merchant/apply/index`) through the reviewed page screen, so a deep-link host never shows a dead end.
struct MerchantInactiveApplyState: View {
    let title: LocalizedStringKey
    var message: LocalizedStringKey? = nil
    var actionTitle: LocalizedStringKey = "merchantCoop.decor.openApplication"
    let identifier: String
    @Environment(\.merchantOpenApplication) private var openApplication

    var body: some View {
        ContentUnavailableView {
            VStack(spacing: CYSpacing.md) {
                MPAsset.FeatureIcon.iconShop
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .accessibilityHidden(true)
                Text(title)
            }
        } description: {
            if let message { Text(message) }
        } actions: {
            if let openApplication {
                Button(action: openApplication) { Text(actionTitle).frame(minHeight: CYSpacing.minTouchTarget) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(identifier + ".action")
            } else {
                NavigationLink {
                    MPReviewedPageScreen(page: "pages/merchant/apply/index", query: [:])
                } label: { Text(actionTitle).frame(minHeight: CYSpacing.minTouchTarget) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(identifier + ".action")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier(identifier)
    }
}

// MARK: - 看公开主页 (MC8-19-1)

private struct MerchantPublicHomePreviewKey: EnvironmentKey {
    static let defaultValue: (@MainActor (PublicMerchantOwnerID) -> AnyView)? = nil
}
extension EnvironmentValues {
    /// MP decor `goPreview` (index.wxml:84-92): the store's own public home. The host builds it with the session's
    /// public-merchant context; nil hides the row.
    var merchantPublicHomePreview: (@MainActor (PublicMerchantOwnerID) -> AnyView)? {
        get { self[MerchantPublicHomePreviewKey.self] }
        set { self[MerchantPublicHomePreviewKey.self] = newValue }
    }
}

/// The hub row 看公开主页 for an active store whose owner member id is known.
struct MerchantDecorPublicHomeRow: View {
    let access: MerchantOperationsAccess
    @Environment(\.merchantPublicHomePreview) private var preview
    var body: some View {
        if access.identity.active, let preview,
           let owner = (access.identity.ownerMemberID ?? access.identity.principalMemberID).flatMap(PublicMerchantOwnerID.init) {
            Section {
                NavigationLink { preview(owner) } label: {
                    Label("merchantCoop.decor.previewPublicHome", systemImage: "eye")
                }
                .accessibilityIdentifier("merchant.operations.entry.publicHome")
            }
        }
    }
}

// MARK: - 门店相册 N 张照片 (MC8-19-8)

/// Trailing value on the hub's 门店相册 row: the gallery document's photo count (MP `gallery.length || 0` 张照片).
/// One read of the existing gallery document; nothing is shown until it answers.
struct MerchantDecorGalleryCount: View {
    let reader: any MerchantOperationsReading
    @State private var count: Int?
    var body: some View {
        Group {
            if let count { Text("merchantCoop.decor.galleryCount \(count)").foregroundStyle(CYColor.textSecondary).monospacedDigit() }
        }
        .task(id: reader.scope) {
            let scope = reader.scope
            guard let document = try? await reader.document(.gallery), !Task.isCancelled, scope == reader.scope,
                  case .draft(.gallery(let value)) = document else { return }
            count = value.gallery.count
        }
    }
}

// MARK: - 经营类目 multi-select (MC8-19-2)

/// MP decor `openPreference` / `saveChipSheet` (index.js:44-62, 1053-1060, 1120-1123): a fixed category list plus any
/// existing custom values, joined with 、 into `preference` (max 100 characters). The pick edits the local draft only;
/// the editor's existing reviewed save sends it.
@MainActor struct MerchantPreferenceEntry: View {
    @ObservedObject var model: MerchantOperationsViewModel
    @State private var showsSheet = false
    static let options = ["城市运动", "户外活动", "健康生活", "美食", "咖啡", "茶饮", "烘焙甜品", "酒吧小酌",
                          "手作", "亲子", "夜生活", "文化艺术", "展览", "书店阅读", "音乐现场", "剧本密室", "桌游", "电玩",
                          "摄影", "城市漫步", "骑行", "露营", "瑜伽", "球类", "水上运动", "花艺", "美容美发", "宠物友好"]

    static func parse(_ value: String) -> [String] {
        var seen: [String] = []
        let parts = value.components(separatedBy: CharacterSet(charactersIn: "、,，·/|").union(.whitespacesAndNewlines))
        for part in parts.map({ $0.trimmingCharacters(in: .whitespaces) }) where !part.isEmpty && !seen.contains(part) {
            seen.append(part)
        }
        return seen
    }

    private var current: String {
        if case .profile(let value) = model.coordinator.draft { return value.preference }
        return ""
    }

    var body: some View {
        Button { showsSheet = true } label: {
            LabeledContent("merchantCoop.decor.preference") {
                if current.isEmpty { Text("merchantCoop.decor.unset") } else { Text(verbatim: current).lineLimit(2) }
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .disabled(!model.coordinator.isCurrent || model.coordinator.isBusy || model.coordinator.isLocked)
        .accessibilityIdentifier("merchant.operations.field.preference")
        .sheet(isPresented: $showsSheet) {
            MerchantPreferenceSheet(initial: Self.parse(current)) { picked in
                guard case .profile(var value) = model.coordinator.draft else { return false }
                let joined = picked.joined(separator: "、")
                guard joined.count <= 100 else { return false }
                value.preference = joined
                model.edit(.profile(value))
                return true
            }
            .presentationDetents([.medium, .large])
            .themeDomain(.merchant)
        }
    }
}

@MainActor private struct MerchantPreferenceSheet: View {
    let initial: [String]
    let apply: ([String]) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var selected: [String] = []
    @State private var tooLong = false

    private var options: [String] {
        MerchantPreferenceEntry.options + initial.filter { !MerchantPreferenceEntry.options.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(options, id: \.self) { label in
                        Toggle(isOn: Binding(get: { selected.contains(label) }, set: { on in
                            if on { if !selected.contains(label) { selected.append(label) } }
                            else { selected.removeAll { $0 == label } }
                        })) {
                            HStack(spacing: CYSpacing.sm) {
                                if let icon = MerchantTagIcons.image(for: label) {
                                    icon.resizable().scaledToFit().frame(width: 18, height: 18).accessibilityHidden(true)
                                }
                                Text(verbatim: label)
                            }
                        }
                        .accessibilityIdentifier("merchant.preference.option." + label)
                    }
                } footer: {
                    if tooLong { Text("merchantCoop.decor.preference.tooLong").foregroundStyle(CYColor.dangerText) }
                }
            }
            .navigationTitle(Text("merchantCoop.decor.preference"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("merchantCoop.decor.preference.save") {
                        if apply(selected) { dismiss() } else { tooLong = true }
                    }
                    .accessibilityIdentifier("merchant.preference.save")
                }
            }
            .onAppear { selected = initial }
        }
    }
}

// MARK: - 联系运营开通 (MC8-19-5)

/// MP decor 升级权益 → 联系运营开通 (index.wxml:327-330): opens the same reviewed support contact Settings uses
/// (`WithdrawalSupportContactView`, server-side contact); nothing is submitted.
struct MerchantContactOperationsRow: View {
    @State private var showsSupport = false
    var body: some View {
        Button { showsSupport = true } label: {
            Label("merchantCoop.decor.contactOps", systemImage: "bubble.left.and.bubble.right")
                .frame(minHeight: CYSpacing.minTouchTarget)
        }
        .accessibilityIdentifier("merchant.operations.contactOps")
        .sheet(isPresented: $showsSupport) {
            WithdrawalSupportContactView()
                .cyDomainSheet(detents: [.half, .full])
                .themeDomain(.merchant)
        }
    }
}
