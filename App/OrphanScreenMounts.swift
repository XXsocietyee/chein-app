import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MARK: - L8 orphan screen mounts
// Entry points for screens that were built but never reached from production. Each entry hides
// itself until its capability or binding exists; nothing here grants a write or invents data.
// The bindings below are stubs for Cursor (composition/logic): their defaults keep every entry hidden.

/// The CITY fairness reader for the signed-in player, scoped to the board the CITY lease last
/// loaded. Nil (no lease, no board yet) hides the entry.
/// Return a factory, not a reader, so a render never constructs a reader.
@MainActor enum CityFairnessEntryBinding {
    static var makeReader: @MainActor (AppSession) -> (@MainActor () -> CityFairnessReader)? = { $0.makeCityFairnessReaderFactory() }
}

/// The player's own orienteering score for one participation. Mini-program
/// `scene-member-participation-detail` shows "定向成绩" only when `_resultEntry()` resolves the signed-in
/// member's topic/activity pair and `productType == 1`. Return nil for every other participation.
@MainActor enum OrientScoreEntryBinding {
    static var makeLoader: @MainActor (ParticipationDetail, AppSession) -> ((Int?) async throws -> OrientScoreLoad)? = { detail, session in
        OrientScoreEntryProduction.loader(detail: detail, session: session)
    }
}

private struct MerchantPerkTemplatesDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = nil
}
private struct MerchantAuthoringDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor () -> AnyView)? = { AnyView(BeGapMerchantHubView()) }
}
private struct TopicTemplateCopiedDestinationKey: EnvironmentKey {
    static let defaultValue: (@MainActor (Int) -> Void)? = nil
}

extension EnvironmentValues {
    /// `pages/merchant/decor/perks`. Set by the merchant workbench from its cooperation reader.
    var merchantPerkTemplatesDestination: (@MainActor () -> AnyView)? {
        get { self[MerchantPerkTemplatesDestinationKey.self] }
        set { self[MerchantPerkTemplatesDestinationKey.self] = newValue }
    }
    /// Store AI draft authoring. Cursor sets this once a `MerchantAuthoringCoordinator` exists and has
    /// adopted the signed-in account, merchant, store and permission revision. Nil hides the entry.
    var merchantAuthoringDestination: (@MainActor () -> AnyView)? {
        get { self[MerchantAuthoringDestinationKey.self] }
        set { self[MerchantAuthoringDestinationKey.self] = newValue }
    }
    /// Opens the server-confirmed topic draft after "use this template" (mini `pages/publish/fabu?id=`).
    var topicTemplateCopiedDestination: (@MainActor (Int) -> Void)? {
        get { self[TopicTemplateCopiedDestinationKey.self] }
        set { self[TopicTemplateCopiedDestinationKey.self] = newValue }
    }
}

/// Owns the perks coordinator for the life of the pushed screen. With no executor the list is
/// read-only: add and delete are hidden, not offered and then refused.
@MainActor struct MerchantPerkTemplatesHost: View {
    @State private var model: MerchantPerkTemplatesCoordinator
    private let writesEnabled: Bool

    init(reader: any CoopFlowReading, executor: (any CoopFlowExecuting)? = nil) {
        _model = State(initialValue: MerchantPerkTemplatesFactory.makeCoordinator(reader: reader, executor: executor))
        writesEnabled = executor != nil
    }

    var body: some View {
        MerchantPerkTemplatesView(model: model, writesEnabled: writesEnabled)
    }
}

/// Mini mycanyuinfo "定向成绩" card, pushing `subpackageMember/orient-score`.
@MainActor struct OrientScoreParticipationEntry: View {
    let detail: ParticipationDetail

    var body: some View {
        if ParticipationOrientScoreEntry.canAskSession(detail) {
            OrientScoreParticipationSessionEntry(detail: detail)
        }
    }
}

/// Reads the signed-in session only after the payload already has a member, a topic,
/// an activity id (0 for a topic registration), and product type 1. A presentation
/// fixture without those fields never asks for `AppSession`.
@MainActor private struct OrientScoreParticipationSessionEntry: View {
    let detail: ParticipationDetail
    @EnvironmentObject private var session: AppSession
    @Environment(\.locale) private var locale
    /// Bumped by 重新加载 so the binding is asked again.
    @State private var attempt = 0

    var body: some View {
        let loader = OrientScoreEntryBinding.makeLoader(detail, session)
        if loader == nil {
            // PLY-23-8: MP mycanyuinfo cy-error 角色卡与成绩入口暂不可用 + 重新加载, instead of hiding the entry.
            let c = CoreLoopCopy(locale: locale)
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(verbatim: c.t("角色卡与成绩入口暂不可用", "Character card and score are unavailable right now"))
                        .cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                    Button { attempt += 1 } label: { Text(verbatim: c.t("重新加载", "Reload")) }
                        .buttonStyle(.borderless)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .accessibilityIdentifier("playerJourney.orientScore.entry.retry")
                }
                .id(attempt)
                .accessibilityIdentifier("playerJourney.orientScore.entry.issue")
            }
        }
        if let loader {
            Section {
                NavigationLink {
                    OrientScoreView(model: OrientScoreModel(rounds: loader))
                        .environment(\.orientScoreSession, session)
                } label: {
                    Label {
                        Text("orphanMount.orientScore.entry", tableName: "OrphanMounts")
                    } icon: {
                        Image(systemName: "list.number")
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("playerJourney.orientScore.entry")
            }
        }
    }
}

/// CITY fairness entry on the city player hub. Hidden until the reader binding exists.
@MainActor struct CityFairnessEntry: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        if let makeReader = CityFairnessEntryBinding.makeReader(session) {
            NavigationLink {
                CityFairnessView(reader: makeReader())
            } label: {
                Label {
                    Text("fairness.title", tableName: "CityFairness")
                } icon: {
                    Image(systemName: "scale.3d")
                }
            }
            .padding()
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityIdentifier("city.fairness.entry")
        }
    }
}

/// Status strip for my-project list writes. Re-reads the list after a server-confirmed mutation.
@MainActor struct MyProjectMutationStrip: View {
    @ObservedObject var model: MyProjectMutationModel
    let onReload: () -> Void

    var body: some View {
        MyProjectMutationStatusView(model: model)
            .onChange(of: model.reloadToken) { _, _ in onReload() }
    }
}

private struct MyProjectMutationModelKey: EnvironmentKey {
    static let defaultValue: MyProjectMutationModel? = nil
}

private struct MyProjectTopicCancelKey: EnvironmentKey { static let defaultValue: ((Int) -> Void)? = nil }
extension EnvironmentValues {
    /// PC-D-1-2: opens the topic's publisher cancel-and-refund flow. Nil (no publisher host) hides the row.
    var myProjectTopicCancel: ((Int) -> Void)? {
        get { self[MyProjectTopicCancelKey.self] }
        set { self[MyProjectTopicCancelKey.self] = newValue }
    }
    /// Present only when `MyProjectMutationFactory.isLive`; nil keeps the row menu empty.
    var myProjectMutation: MyProjectMutationModel? {
        get { self[MyProjectMutationModelKey.self] }
        set { self[MyProjectMutationModelKey.self] = newValue }
    }
}
