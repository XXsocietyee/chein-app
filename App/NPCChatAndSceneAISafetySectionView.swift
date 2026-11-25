import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#elseif canImport(Core)
import Core
#endif

/// Self-contained safety row for `G-W04` Scene AI guard and `I08` NPC chat deletion fence status.
public struct NPCSceneAISafetyRow: Identifiable, Equatable, Sendable {
    public let guardID: String
    public let title: String
    public let detail: String
    public let isEnforced: Bool

    public var id: String { guardID }

    public init(
        guardID: String,
        title: String,
        detail: String,
        isEnforced: Bool
    ) {
        self.guardID = guardID
        self.title = title
        self.detail = detail
        self.isEnforced = isEnforced
    }
}

/// Self-contained snapshot for `G-W04` Scene AI guard (default non-generative kill switch,
/// scope isolation, narrative action whitelist) and `I08` NPC chat deletion re-read fence.
public struct NPCChatAndSceneAISafetySnapshot: Equatable, Sendable {
    public static let canonicalGuardIDs: [String] = [
        "SceneAIKillSwitch",
        "SceneAIScopeIsolation",
        "NPCNarrativeEffectWhitelist",
        "NPCChatDeletionFence"
    ]

    public let globalGenerationEnabled: Bool
    public let streamingDisplayAllowed: Bool
    public let enforcesScopeEchoAndIsolation: Bool
    public let dropsForbiddenBusinessEffects: Bool
    public let enforcesNPCChatDeletionReReadFence: Bool
    public let rows: [NPCSceneAISafetyRow]
    public let figureRenderer: NPCLowPolyFigureRenderer
    public let authoringContract: NPCAuthoringFormParityContract
    public let locale: Locale

    public init(
        globalGenerationEnabled: Bool = false,
        streamingDisplayAllowed: Bool = false,
        enforcesScopeEchoAndIsolation: Bool = true,
        dropsForbiddenBusinessEffects: Bool = true,
        enforcesNPCChatDeletionReReadFence: Bool = true,
        customRows: [NPCSceneAISafetyRow]? = nil,
        figureRenderer: NPCLowPolyFigureRenderer = NPCLowPolyFigureRenderer(),
        authoringContract: NPCAuthoringFormParityContract = NPCAuthoringFormParityContract(),
        locale: Locale = .current
    ) {
        self.locale = locale
        self.globalGenerationEnabled = globalGenerationEnabled
        self.streamingDisplayAllowed = streamingDisplayAllowed
        self.enforcesScopeEchoAndIsolation = enforcesScopeEchoAndIsolation
        self.dropsForbiddenBusinessEffects = dropsForbiddenBusinessEffects
        self.enforcesNPCChatDeletionReReadFence = enforcesNPCChatDeletionReReadFence
        self.figureRenderer = figureRenderer
        self.authoringContract = authoringContract

        let killSwitchCompliant = !globalGenerationEnabled && !streamingDisplayAllowed
        if let customRows {
            self.rows = customRows
        } else {
            self.rows = [
                NPCSceneAISafetyRow(
                    guardID: "SceneAIKillSwitch",
                    title: bilingualCopy("G-W04 生成式总闸与流式开关", "G-W04 generation kill switch and streaming toggle", locale: locale),
                    detail: killSwitchCompliant
                        ? bilingualCopy("默认非生成式兜底已生效 · 流式输出已关闭", "Non-generative fallback is active by default · streaming output is off", locale: locale)
                        : bilingualCopy("生成式开关或流式展示未处于默认关闭状态", "Generation or streaming display is not in its default-off state", locale: locale),
                    isEnforced: killSwitchCompliant
                ),
                NPCSceneAISafetyRow(
                    guardID: "SceneAIScopeIsolation",
                    title: bilingualCopy("G-W04 场景作用域与审计回显隔离", "G-W04 scene scope and audit echo isolation", locale: locale),
                    detail: enforcesScopeEchoAndIsolation
                        ? bilingualCopy("跨主题/跨场次/跨门店隔离键与审计回显校验已启用", "Cross-topic / cross-session / cross-store isolation keys and audit echo checks are enabled", locale: locale)
                        : bilingualCopy("缺少作用域隔离键或审计版本回显校验", "Scope isolation key or audit version echo check is missing", locale: locale),
                    isEnforced: enforcesScopeEchoAndIsolation
                ),
                NPCSceneAISafetyRow(
                    guardID: "NPCNarrativeEffectWhitelist",
                    title: bilingualCopy("G-W04 叙事动作白名单与禁区拦截", "G-W04 narrative action allowlist and forbidden-zone blocking", locale: locale),
                    detail: dropsForbiddenBusinessEffects
                        ? bilingualCopy("发奖、扣库存、改价、完赛、支付等业务副作用一律丢弃", "Business side effects such as granting rewards, deducting stock, changing prices, completing sessions and payments are always dropped", locale: locale)
                        : bilingualCopy("业务副作用白名单拦截未生效", "Business side-effect allowlist blocking is not enforced", locale: locale),
                    isEnforced: dropsForbiddenBusinessEffects
                ),
                NPCSceneAISafetyRow(
                    guardID: "NPCChatDeletionFence",
                    title: bilingualCopy("I08 NPC 对话与记忆删除重读围栏", "I08 NPC chat and memory deletion re-read fence", locale: locale),
                    detail: enforcesNPCChatDeletionReReadFence
                        ? bilingualCopy("已删除会话与记忆条目禁止被陈旧回读恢复", "Deleted conversations and memory entries cannot be restored by stale re-reads", locale: locale)
                        : bilingualCopy("NPC 删除重读围栏未启用", "The NPC deletion re-read fence is not enabled", locale: locale),
                    isEnforced: enforcesNPCChatDeletionReReadFence
                )
            ]
        }
    }

    public var hasCanonicalGuards: Bool {
        rows.map(\.guardID) == Self.canonicalGuardIDs
    }

    public var isAllCompliant: Bool {
        !globalGenerationEnabled
            && !streamingDisplayAllowed
            && enforcesScopeEchoAndIsolation
            && dropsForbiddenBusinessEffects
            && enforcesNPCChatDeletionReReadFence
            && hasCanonicalGuards
            && rows.allSatisfy(\.isEnforced)
            && authoringContract.isAuthoringAndChatParityCompliant
    }
}

/// SwiftUI section rendering `G-W04` Scene AI guard and `I08` NPC chat deletion fence status
/// with inline bilingual (zh-Hans / en) copy.
@MainActor public struct NPCChatAndSceneAISafetySectionView: View {
    public let snapshot: NPCChatAndSceneAISafetySnapshot

    public init(snapshot: NPCChatAndSceneAISafetySnapshot = NPCChatAndSceneAISafetySnapshot()) {
        self.snapshot = snapshot
    }

    public var statusHeadline: String {
        if snapshot.globalGenerationEnabled || snapshot.streamingDisplayAllowed {
            return bilingualCopy("G-W04 门控告警：Scene AI 默认必须保持非生成式且关闭流式展示", "G-W04 gate alert: Scene AI must stay non-generative with streaming off by default", locale: snapshot.locale)
        }
        if !snapshot.enforcesScopeEchoAndIsolation || !snapshot.dropsForbiddenBusinessEffects {
            return bilingualCopy("G-W04 边界告警：缺少作用域回显校验或叙事动作白名单拦截", "G-W04 boundary alert: scope echo check or narrative action allowlist is missing", locale: snapshot.locale)
        }
        if !snapshot.enforcesNPCChatDeletionReReadFence {
            return bilingualCopy("I08 围栏告警：NPC 对话与记忆删除重读围栏未启用", "I08 fence alert: the NPC chat and memory deletion re-read fence is not enabled", locale: snapshot.locale)
        }
        if !snapshot.isAllCompliant {
            return bilingualCopy("NPC 对话与 Scene AI 安全门控存在未达标项", "Some NPC chat and Scene AI safety gates are not met", locale: snapshot.locale)
        }
        return bilingualCopy("G-W04 场景 AI 安全门控（默认关闭）与 I08 NPC 删除围栏全部就绪", "G-W04 Scene AI safety gates (default off) and the I08 NPC deletion fence are all ready", locale: snapshot.locale)
    }

    private var summaryLine: String {
        let loc = snapshot.locale
        let on = bilingualCopy("开启", "On", locale: loc), off = bilingualCopy("默认关闭", "Off by default", locale: loc)
        let enforced = snapshot.enforcesNPCChatDeletionReReadFence
        return bilingualCopy("生成式总闸：", "Generation: ", locale: loc) + (snapshot.globalGenerationEnabled ? on : off)
            + bilingualCopy(" · 流式展示：", " · Streaming: ", locale: loc) + (snapshot.streamingDisplayAllowed ? on : off)
            + bilingualCopy(" · I08 删除围栏：", " · I08 deletion fence: ", locale: loc)
            + (enforced ? bilingualCopy("已生效", "Enforced", locale: loc) : bilingualCopy("未生效", "Not enforced", locale: loc))
    }

    public var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: statusHeadline)
                    .cyText(.bodyMedium)
                    .accessibilityIdentifier("npcSceneAISafety.statusHeadline")
                Text(verbatim: summaryLine)
                    .cyText(.meta)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("npcSceneAISafety.summary")
                Text(verbatim: bilingualCopy(
                    "3D 低多边形立绘 (\(snapshot.figureRenderer.canonicalBoxFaceCount) 面) · 导出预览上限 \(NPCChatTranscriptExporter.previewLimit) 条 · 节点/门店 NPC 表单与 ChatMessageBubble 复用已对齐",
                    "3D low-poly figure (\(snapshot.figureRenderer.canonicalBoxFaceCount) faces) · export preview limit \(NPCChatTranscriptExporter.previewLimit) messages · node/store NPC forms share ChatMessageBubble",
                    locale: snapshot.locale))
                    .cyText(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("npcSceneAISafety.paritySummary")
            }

            ForEach(snapshot.rows) { row in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: row.isEnforced ? "lock.shield.fill" : "exclamationmark.triangle.fill")
                        .accessibilityHidden(true).foregroundStyle(row.isEnforced ? .green : .red)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.title)
                            .cyText(.bodyMedium)
                        Text(verbatim: row.detail)
                            .cyText(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(verbatim: row.isEnforced ? bilingualCopy("已生效", "Enforced", locale: snapshot.locale) : bilingualCopy("未生效", "Not enforced", locale: snapshot.locale))
                        .cyText(.meta, weight: .semibold)
                        .foregroundStyle(row.isEnforced ? .green : .red)
                }
                .accessibilityIdentifier("npcSceneAISafety.row." + row.guardID)
            }
        } header: {
            Text(verbatim: bilingualCopy("G-W04 场景 AI 门控与 I08 NPC 删除围栏", "G-W04 Scene AI gates and I08 NPC deletion fence", locale: snapshot.locale))
        }
        .accessibilityIdentifier("npcSceneAISafety.section")
    }
}
