import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Seam for the topic-template "use" writer. Production is gated (nothing is sent, the button explains
/// "Not available yet"). Composition replaces `makeUser` once a write route and grant are approved.
@MainActor enum TopicTemplateUseFactory {
    static var makeUser: () -> TopicTemplateUsing = { GatedTopicTemplateUser() }

    /// True once composition replaced the gated writer. While false hosts do not show the section.
    static var isLive: Bool { !(makeUser() is GatedTopicTemplateUser) }
}

/// U02-03 / U02-05 seams. Gated defaults hide the place to-dos and the image credits.
@MainActor enum TopicTemplateAdoptionFactory {
    static var makeBindingClient: () -> TopicLocationBindingClient = { GatedTopicLocationBindingClient() }
    static var makeAttributionReader: () -> MediaAttributionReading = { GatedMediaAttributionReader() }

    static var bindingIsLive: Bool { !(makeBindingClient() is GatedTopicLocationBindingClient) }
    static var attributionIsLive: Bool { !(makeAttributionReader() is GatedMediaAttributionReader) }

    /// Composition calls this once the route grants for /use, /binding-status, /binding and
    /// /api/media/asset/attribution exist. One client serves all four.
    static func install(_ service: TopicTemplateAdoptionService) {
        TopicTemplateUseFactory.makeUser = { service }
        makeBindingClient = { service }
        makeAttributionReader = { service }
    }
}

extension AppCompositionRoot {
    /// H1: template copy, place to-dos and image credits go live only with the reviewed China player-write grant;
    /// every request still passes the session transport's player-write lease.
    func installTemplateAdoption(_ session: AppSession) -> AppSession {
        guard reviewed?.playerWritesEnabled == true, reviewed?.regional.market == .china,
              let api = reviewed?.regional.apiConfiguration else { return session }
        TopicTemplateAdoptionFactory.install(TopicTemplateAdoptionService(configuration: api,
            transport: session.runtimeHTTPTransport, token: { [weak session] in session?.token }))
        return session
    }
}

/// Drop-in "Use this template" row for the topic-template detail screen. On a server-confirmed copy it
/// calls `onCopied(topicID)` so the host can open the draft in the editor (mini: pages/publish/fabu?id=).
/// A second tap after the copy reopens that same draft; an unconfirmed result re-asks with the same requestId.
@MainActor struct TopicTemplateUseSection: View {
    let templateID: Int
    let scope: String?
    let readOnly: Bool
    let plan: TopicTemplateAdoptionPlan
    let onCopied: (Int) -> Void
    @StateObject private var model: TopicTemplateUseModel
    @Environment(\.analyticsEventClient) private var analytics
    @Environment(\.offlineWriteSession) private var offlineWriteSession

    init(templateID: Int, scope: String?, readOnly: Bool, plan: TopicTemplateAdoptionPlan = .init(delivery: nil),
         onCopied: @escaping (Int) -> Void) {
        self.templateID = templateID
        self.scope = scope
        self.readOnly = readOnly
        self.plan = plan
        self.onCopied = onCopied
        _model = StateObject(wrappedValue: TopicTemplateUseModel(writer: TopicTemplateUseFactory.makeUser(), readOnly: readOnly))
    }

    private var buttonTitle: String {
        switch model.state {
        case .using: return W8Text.t("正在复制…", "Copying…")
        case .copied: return W8Text.t("打开我的草稿", "Open my draft")
        case .unknown: return W8Text.t("查询复制结果", "Check copy result")
        default: return W8Text.t("使用此模板", "Use this template")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            // U02-02: what adoption does with places (owner ruling: no city switch; addresses are replaced in the editor).
            if model.copiedReceipt == nil {
                Text(plan.keepsPlaces
                     ? W8Text.t("复制成你自己的草稿，先沿用原地点；在编辑器的「地点待办」里逐个替换并确认地址。原模板不变。",
                                "Copies into your own draft that keeps the original places for now. Replace and confirm each address under Place to-dos in the editor. The template itself is unchanged.")
                     : W8Text.t("复制成你自己的草稿，修改不影响原模板。", "Copies into your own draft. Your edits never change the template."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("topicTemplate.useIntent")
            }
            Button {
                if scope != "my" {
                    MiniProgramAnalytics.track(analytics, "template_reuse", bizType: "template", bizID: MiniProgramAnalytics.bizID(templateID), pagePath: "/pages/templatedetail/templatedetail")
                }
                Task {
                    await SessionOfflineSyncModel.shared.performWriteOptIn(
                        environmentSession: offlineWriteSession.session,
                        routes: ["/api/template/topic-template/use"]
                    ) {
                        await model.use(id: templateID, scope: scope, plan: plan)
                    }
                }
            } label: {
                Text(buttonTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.state == .using)
            .accessibilityIdentifier("topicTemplate.use")
            CYScreenOfflineWriteBanner(
                routes: ["/api/template/topic-template/use"],
                session: offlineWriteSession.session
            )
            SourceLineageSection(revisionID: model.copiedReceipt?.sourceContentRevisionId ?? plan.sourceContentRevisionId)
            if let message = TopicTemplateUseModel.message(for: model.state) {
                Label(message, systemImage: model.copiedReceipt == nil ? "exclamationmark.circle" : "checkmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("topicTemplate.useMessage")
            }
        }
        .onChange(of: model.openRequest) { _, request in
            if let request { onCopied(request.topicId) }
        }
    }
}

/// U02-01 "采用条件": only rows backed by a server fact (mini r2-create b4-u02-01). No rows -> no section.
@MainActor struct TopicTemplateAdoptionConditionsSection: View {
    let delivery: TopicTemplateContentDelivery?
    var canViewEvidence: Bool = false

    var body: some View {
        let rows = TopicTemplateAdoptionConditions.rows(delivery, canViewEvidence: canViewEvidence)
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    LabeledContent {
                        Text(row.value)
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                    } label: {
                        Text(row.label)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("topicTemplate.condition.\(row.key)")
                }
            } header: {
                Text("u02.template.adoptionConditions")
            }
            .accessibilityIdentifier("topicTemplate.adoptionConditions")
        }
    }
}

/// U02-05 credit under a node image. Reads once per reference; nothing on failure.
@MainActor struct TopicTemplateNodeCredit: View {
    let reference: String
    @State private var credit: String?

    var body: some View {
        Group {
            if let credit {
                Text(credit).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    .accessibilityLabel(Text(W8Text.t("图片署名：\(credit)", "Image credit: \(credit)")))
                    .accessibilityIdentifier("topicTemplate.nodeCredit")
            }
        }
        .task(id: reference) {
            credit = nil
            let value = await TopicTemplateAdoptionFactory.makeAttributionReader().credit(reference: reference)
            guard !Task.isCancelled else { return }
            credit = value
        }
    }
}
