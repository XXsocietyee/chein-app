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

/// Mini "发布单场活动" row above a non-empty activity list.
@MainActor struct MyProjectCreateActivityRow: View {
    let type: String
    let rowCount: Int
    @Environment(\.myProjectPublishEntry) private var entry
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    var body: some View {
        if type == MyProjectTab.activity.rawValue, rowCount > 0, let entry, entry.canPublishActivity, !merchantScopeAccess.isBrowseOnly {
            NavigationLink { entry.make() } label: { Label("myProject.cta.activity", systemImage: "plus") }
                .accessibilityIdentifier("myProject.createActivity")
        }
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
        if let address = project.addressName { Text(verbatim: address).cyText(.meta).foregroundStyle(.secondary) }
        MyProjectTopicFactLine(project: project)
    }
}

/// Long-press list management. Every mutation stays disabled: toggle/cancel/delete have no reviewed
/// endpoint allowlist entry yet, so the menu only explains which actions the mini-program offers here.
@MainActor struct MyProjectRowOperationsMenu: View {
    let project: CreatorContentProject
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    static func hasOperations(_ rows: [CreatorContentProject], merchantScopeAccess: MyProjectMerchantScopeAccess = .init()) -> Bool {
        rows.contains { !MyProjectListPresentation.card($0, merchantScopeAccess: merchantScopeAccess).operations.isEmpty }
    }
    @Environment(\.myProjectMutation) private var mutation
    var body: some View {
        // While 上下架 / 取消 / 删除 are gated the long-press menu offers nothing rather than a column of
        // disabled rows. Once composition supplies a live mutator the list injects its model here.
        let card = MyProjectListPresentation.card(project, merchantScopeAccess: merchantScopeAccess)
        if let mutation, let biz = MyProjectBiz(rawValue: project.bizType) {
            ForEach(card.operations, id: \.self) { operation in
                switch operation {
                case .toggle:
                    Button(LocalizedStringKey(card.toggleKey)) {
                        Task { await mutation.begin(.toggleOnline(biz: biz, id: project.sourceID, currentlyOnline: card.online)) }
                    }
                    .accessibilityIdentifier("myProject.op.toggle.\(project.id)")
                case .cancel where biz == .activity:
                    // Topic cancel goes through the source cancel-preview flow, which has no native model yet.
                    Button("myProject.op.cancel", role: .destructive) {
                        Task { await mutation.begin(.cancelActivity(id: project.sourceID)) }
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
