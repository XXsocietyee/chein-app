import SwiftUI

/// Host-provided own-shelf for the "模板" tab of mini-program subpackageA/pages/myproject.
/// Absent hosts show an explicit unavailable state instead of reusing `api/project/my` rows.
struct MyProjectTemplateShelfHost {
    let make: @MainActor () -> AnyView
}

private struct MyProjectTemplateShelfKey: EnvironmentKey {
    static let defaultValue: MyProjectTemplateShelfHost? = nil
}

extension EnvironmentValues {
    var myProjectTemplateShelf: MyProjectTemplateShelfHost? {
        get { self[MyProjectTemplateShelfKey.self] }
        set { self[MyProjectTemplateShelfKey.self] = newValue }
    }
}

/// Host-provided publishing entry for the empty-state CTA and the activity create row.
/// `canPublishActivity` mirrors the mini's local `roleGuard.role() === 'club'` gate; the publishing
/// hub re-checks `api/publish/home` before any activity review, so this only decides visibility.
struct MyProjectPublishEntry {
    let canPublishActivity: Bool
    let make: @MainActor () -> AnyView
}

private struct MyProjectPublishEntryKey: EnvironmentKey {
    static let defaultValue: MyProjectPublishEntry? = nil
}

extension EnvironmentValues {
    var myProjectPublishEntry: MyProjectPublishEntry? {
        get { self[MyProjectPublishEntryKey.self] }
        set { self[MyProjectPublishEntryKey.self] = newValue }
    }
}

/// R7-PC-D1-5 (MP myproject ops sheet 收到的申请 → `/pages/coop/list/index?tab=received`). The host owns the push.
private struct MyProjectReceivedAppliesKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var myProjectReceivedApplies: (() -> Void)? {
        get { self[MyProjectReceivedAppliesKey.self] }
        set { self[MyProjectReceivedAppliesKey.self] = newValue }
    }
}

enum MyProjectReceivedAppliesRule {
    /// MP `canViewApplies`: a topic whose pool is open (clubOpen / merchantOpen) or already accepted.
    static func applies(_ project: CreatorContentProject) -> Bool {
        project.bizType == "topic" && ["clubOpen", "merchantOpen", "clubAccepted", "merchantAccepted"].contains(project.acceptStatus ?? "")
    }
}

/// MP `open-address.js`. Address-only search stays a query. Both coordinates also set `ll` so Maps drops a pin.
enum MyProjectAddressLink {
    @MainActor static func open(address: String, name: String?, latitude: Double? = nil, longitude: Double? = nil, openURL: OpenURLAction) {
        var items = [URLQueryItem]()
        if let latitude, let longitude, latitude.isFinite, longitude.isFinite {
            items.append(URLQueryItem(name: "ll", value: "\(latitude),\(longitude)"))
        }
        items.append(URLQueryItem(name: "q", value: address))
        var components = URLComponents(string: "https://maps.apple.com/")
        components?.queryItems = items
        if let url = components?.url { openURL(url) }
    }
}

@MainActor struct MyProjectTemplateTabSection: View {
    let shelf: MyProjectTemplateShelfHost?
    var body: some View {
        Section {
            if let shelf {
                NavigationLink { shelf.make() } label: {
                    Label("myProject.template.open", systemImage: "square.stack.3d.up")
                }.accessibilityIdentifier("myProject.template.open")
            } else {
                CYEmptyState(systemImage: "square.stack.3d.up.slash", "myProject.template.unavailable", messageIdentifier: "myProject.template.unavailable")
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
        }
    }
}

@MainActor struct MyProjectEmptyView: View {
    let type: String
    @Environment(\.myProjectPublishEntry) private var entry
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    var body: some View {
        if let tab = MyProjectTab(rawValue: type) {
            let canPublishActivity = entry?.canPublishActivity == true && !merchantScopeAccess.isBrowseOnly
            let keys = MyProjectListPresentation.emptyKeys(for: tab, canPublishActivity: canPublishActivity)
            VStack(spacing: CYSpacing.md) {
                CYStateArt(kind: .projects)
                Text(LocalizedStringKey(keys.title)).cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.center)
                if let detail = keys.detail {
                    Text(LocalizedStringKey(detail)).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                if !merchantScopeAccess.isBrowseOnly, let entry, let cta = MyProjectListPresentation.emptyCTAKey(for: tab, canPublishActivity: canPublishActivity) {
                    NavigationLink { entry.make() } label: { Text(LocalizedStringKey(cta)) }
                        .buttonStyle(.cyPrimary(fullWidth: false))
                        .padding(.top, CYSpacing.sm)
                        .accessibilityIdentifier("myProject.emptyCTA." + type)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, CYSpacing.xxl).padding(.horizontal, CYSpacing.xxl)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("myProject.empty." + type)
        } else {
            CYEmptyState(systemImage: "folder", "creatorContent.empty", kind: .projects)
        }
    }
}

private struct MyProjectMerchantScopeAccessKey: EnvironmentKey {
    static let defaultValue = MyProjectMerchantScopeAccess()
}

extension EnvironmentValues {
    var myProjectMerchantScopeAccess: MyProjectMerchantScopeAccess {
        get { self[MyProjectMerchantScopeAccessKey.self] }
        set { self[MyProjectMerchantScopeAccessKey.self] = newValue }
    }
}

@MainActor struct MyProjectMerchantBrowseOnlyBanner: View {
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    var body: some View {
        if let notice = merchantScopeAccess.browseOnlyNotice {
            Text(verbatim: notice)
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .accessibilityIdentifier("myProject.merchant.browseOnlyNotice")
        }
    }
}

/// Card lines the mini-program derives locally: role tag, pending dot, schedule text, and resolved card route.
@MainActor struct MyProjectCardMeta: View {
    let project: CreatorContentProject
    let chinese: Bool
    var canEditActivity: Bool = true
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    @Environment(\.openURL) private var openURL

    var resolvedRoute: MyProjectCardRoute? {
        MyProjectListPresentation.resolveRoute(
            project,
            canEditActivity: canEditActivity,
            merchantScopeAccess: merchantScopeAccess
        )
    }

    var body: some View {
        let card = MyProjectListPresentation.card(
            project,
            canEditActivity: canEditActivity,
            merchantScopeAccess: merchantScopeAccess
        )
        HStack(spacing: 6) {
            if card.pending { Circle().fill(CYColor.dangerText).frame(width: 6, height: 6).accessibilityHidden(true) }
            Text(LocalizedStringKey(card.roleKey)).cyText(.meta, weight: .bold)
        }
        if let when = MyProjectListPresentation.whenText(start: project.startTime, end: project.endTime, chinese: chinese) {
            Text(verbatim: when).cyText(.meta)
        }
        if let address = project.addressName {
            // R7-PC-D1-6 (MP myproject/index.wxml:47 `onAddressTap`): the address opens Maps.
            Button {
                MyProjectAddressLink.open(address: address, name: project.title,
                                          latitude: project.latitude, longitude: project.longitude, openURL: openURL)
            } label: {
                Label { Text(verbatim: address) } icon: { Image(systemName: "mappin.and.ellipse") }
                    .cyText(.meta).foregroundStyle(.secondary)
                    .frame(minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("myProject.address.open \(address)"))
            .accessibilityIdentifier("myProject.address.\(project.id)")
        }
        MyProjectTopicFactLine(project: project)
    }
}

/// Long-press list management. Every mutation stays disabled: toggle/cancel/delete have no reviewed
/// endpoint allowlist entry yet, so the menu only explains which actions the mini-program offers here.
/// PC-D-1-4: the row's operations are also on a visible 「···」 (MP PG-084); a context menu must not be the only
/// entry. Shown only when the menu would offer something.
@MainActor struct MyProjectRowMoreButton: View {
    let project: CreatorContentProject
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    @Environment(\.myProjectMutation) private var mutation
    @Environment(\.myProjectTopicCancel) private var topicCancel
    @Environment(\.myProjectReceivedApplies) private var receivedApplies
    private var hasItems: Bool {
        if receivedApplies != nil, MyProjectReceivedAppliesRule.applies(project) { return true }
        let card = MyProjectListPresentation.card(project, merchantScopeAccess: merchantScopeAccess)
        if topicCancel != nil, MyProjectBiz(rawValue: project.bizType) == .topic, card.operations.contains(.cancel) { return true }
        return mutation != nil && MyProjectBiz(rawValue: project.bizType) != nil && !card.operations.isEmpty
    }
    var body: some View {
        if hasItems {
            Menu { MyProjectRowOperationsMenu(project: project) } label: {
                Image(systemName: "ellipsis")
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textSecondary)
                    .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(Text("myProject.more"))
            .accessibilityIdentifier("myProject.more.\(project.id)")
        }
    }
}

@MainActor struct MyProjectRowOperationsMenu: View {
    let project: CreatorContentProject
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    static func hasOperations(_ rows: [CreatorContentProject], merchantScopeAccess: MyProjectMerchantScopeAccess = .init()) -> Bool {
        rows.contains { !MyProjectListPresentation.card($0, merchantScopeAccess: merchantScopeAccess).operations.isEmpty }
    }
    @Environment(\.myProjectMutation) private var mutation
    @Environment(\.myProjectTopicCancel) private var topicCancel
    @Environment(\.myProjectReceivedApplies) private var receivedApplies
    var body: some View {
        // R7-PC-D1-5: 收到的申请 sits after 编辑 in the MP ops sheet.
        if let receivedApplies, MyProjectReceivedAppliesRule.applies(project) {
            Button { receivedApplies() } label: { Label("myProject.op.viewApplies", systemImage: "list.bullet") }
                .accessibilityIdentifier("myProject.op.received.\(project.id)")
        }
        // While 上下架 / 取消 / 删除 are gated the long-press menu offers nothing rather than a column of
        // disabled rows. Once composition supplies a live mutator the list injects its model here.
        let card = MyProjectListPresentation.card(project, merchantScopeAccess: merchantScopeAccess)
        // PC-D-1-2: MP 取消主题并退款 (myproject index.js:610-638) opens the publisher cancel flow, which reads
        // `cancel_preview` (refund count) before the confirm. The refund write itself stays behind its grant.
        if let topicCancel, MyProjectBiz(rawValue: project.bizType) == .topic, card.operations.contains(.cancel) {
            Button("myProject.op.cancel", role: .destructive) { topicCancel(project.sourceID) }
                .accessibilityIdentifier("myProject.op.cancelTopic.\(project.id)")
        }
        if let mutation, let biz = MyProjectBiz(rawValue: project.bizType) {
            ForEach(card.operations, id: \.self) { operation in
                switch operation {
                case .toggle:
                    Button(LocalizedStringKey(card.toggleKey)) {
                        Task { await mutation.begin(.toggleOnline(biz: biz, id: project.sourceID, currentlyOnline: card.online)) }
                    }
                    .accessibilityIdentifier("myProject.op.toggle.\(project.id)")
                case .cancel where biz == .activity:
                    // R7-PC-D1-2 (MP myproject/index.js:589-607): read cancel_preview first; the confirm names the paid players.
                    Button("myProject.op.cancel", role: .destructive) {
                        Task { await mutation.beginActivityCancel(id: project.sourceID, title: project.title) }
                    }
                    .accessibilityIdentifier("myProject.op.cancel.\(project.id)")
                case .delete:
                    Button("myProject.op.delete", role: .destructive) {
                        Task { await mutation.begin(.delete(biz: biz, id: project.sourceID)) }
                    }
                    .accessibilityIdentifier("myProject.op.delete.\(project.id)")
                default:
                    EmptyView()
                }
            }
        }
    }
}

extension AppSession {
    /// Ordinary publishing hub; activity visibility follows the local session role like the mini.
    @MainActor func myProjectPublishEntry() -> MyProjectPublishEntry {
        .init(canPublishActivity: publishingSession?.role == "club",
              make: { AnyView(SessionPublishingModesView().environmentObject(self).id(self.publishingSession?.epoch)) })
    }

    /// Same own-shelf the template launch page opens; reads `/api/template/my-list` through the session coordinator.
    @MainActor func myProjectTemplateShelf() -> AnyView {
        AnyView(TemplateAuthoringMineView(coordinator: templateShelfCoordinator(), sessionRevision: sessionRevision,
            memberDetail: { AnyView(SessionOwnedMemberTemplateDetailView(id: $0)) },
            ownerConfiguration: { AnyView(SessionOwnedTemplateConfigurationView(id: $0)) },
            creatorConsent: { AnyView(SessionWorkshopCreatorConsentView(selection: $0)) })
            .id(templateShelfViewIdentity))
    }
}
