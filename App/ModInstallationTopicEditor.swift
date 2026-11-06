import SwiftUI

/// Existing editor and transport approvals remain authoritative. This is a receipt route, not an owner grant.
@MainActor struct ModInstallationTopicEditor: View {
    let receipt: ModInstallationReceipt
    let isCurrent: () -> Bool
    @EnvironmentObject private var session: AppSession
    @Environment(\.dismiss) private var dismiss
    @State private var openingScope: UUID?
    var body: some View {
        Group {
            if isCurrent(), let openingScope, openingScope == session.creatorContentReader.scope,
               let target = ProjectEditRemoteTarget(installationReceipt: receipt, readerScope: openingScope) {
                ProjectRemoteEditorDestination(target: target, reader: session.creatorContentReader,
                    revision: session.sessionRevision, makeEditor: { session.projectEditor(target: $0) },
                    editorContextID: session.projectEditorContextID,
                    publisherClient: session.publisherLifecycleContext?.client,
                    publisherHost: { AnyView(SessionPublisherLifecycleView(session: session, resource: $0)) })
            } else { Text("projectRemote.stale") }
        }
        .onAppear { if openingScope == nil && isCurrent() { openingScope = session.creatorContentReader.scope } }
        .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("modInstallation.back", tableName: "ModInstallation") } } }
    }
}

struct InstallationTopicGraphContent: View {
    let graph: ModInstallationTopicGraph
    @Environment(\.locale) private var locale
    private var isChinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(verbatim: graph.title).font(.headline)
            Text(verbatim: graph.description).textSelection(.enabled)
            Text(verbatim: graph.startNodeKey).font(.caption)
            if let locale = graph.locale {
                Text(verbatim: locale).font(.caption)
                Text("modInstallation.graph.qaBoundary", tableName: "ModInstallation").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(graph.moduleFrames) { frame in
                VStack(alignment: .leading) {
                    Text(isChinese ? "子模组 \(frame.dependency.packageId) · \(frame.dependency.packageVersion)" : "Child module \(frame.dependency.packageId) · \(frame.dependency.packageVersion)").font(.headline)
                    Text(isChinese ? "入口 \(frame.entryNodeId) → 原映射 \(frame.compiledEntryNodeId)" : "Entry \(frame.entryNodeId) → original mapping \(frame.compiledEntryNodeId)")
                    Text(isChinese ? "子 END 返回父节点 \(frame.returnNodeId)" : "Child END returns to parent node \(frame.returnNodeId)")
                    Text(isChinese ? "节点映射 \(frame.nodeMap.count) 项；地点槽映射 \(frame.venueSlotMap.count) 项" : "Node mappings: \(frame.nodeMap.count); venue-slot mappings: \(frame.venueSlotMap.count)")
                    Text(isChinese ? "编译 \(frame.compilerVersion) · \(frame.compiledHash)" : "Compiler \(frame.compilerVersion) · \(frame.compiledHash)").font(.caption)
                }
            }
            ForEach(graph.nodes) { node in
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: node.id + " · " + node.sourceType + " · " + node.title).font(.headline)
                    Text(verbatim: node.body).textSelection(.enabled)
                    if let dependency = node.dependency {
                        Text(verbatim: dependency.packageId + " @ " + dependency.packageVersion).font(.caption)
                        Text(verbatim: "artifact=" + (node.artifactHash ?? "")).font(.caption.monospaced())
                        Text(isChinese ? "由原 H5 服务端结果决定分支；关闭宿主不算放弃。" : "The original H5 server result determines the branch. Closing the host does not count as abandoning the challenge.").font(.footnote)
                        if let policy = node.attemptPolicy {
                            if let count = policy.maxAttempts { Text(isChinese ? "最多尝试 \(count) 次；用尽后走已审核失败分支。" : "Maximum attempts: \(count). Once exhausted, follow the reviewed failure branch.") }
                            if let seconds = policy.timeoutSeconds { Text(isChinese ? "挑战期限 \(seconds) 秒，从原服务端会话创建起计算。" : "Challenge deadline: \(seconds) seconds from creation of the original server session.") }
                            ForEach(policy.branches.keys.sorted(), id: \.self) { code in Text("\(code) → \(policy.branches[code] ?? "")") }
                        } else { Text(isChinese ? "未配置有限次数或挑战期限；失败保持原无限重试。" : "No attempt limit or challenge deadline is configured. Failures retain the original unlimited retries.").font(.footnote) }
                    }
                    if node.sourceType == "ADVANCED_GAME", let qa = try? ModInstallationQaPick(json: node.advancedConfigJson) {
                        InstallationQaPickContent(question: qa)
                    }
                    ForEach(node.choices ?? []) { choice in
                        Text(verbatim: choice.id + " · " + choice.label + " → " + choice.next)
                        if choice.id == node.fallbackChoiceId {
                            Text("modInstallation.graph.fallback", tableName: "ModInstallation").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(graph.edges.filter { $0.fromNodeKey == node.id }) { edge in
                        Text(verbatim: edge.id + " · " + edge.trigger.outcomeCode + " → " + edge.toNodeKey).font(.caption.monospaced())
                    }
                }
            }
            Text("modInstallation.graph.topicBoundary", tableName: "ModInstallation").font(.caption).foregroundStyle(.secondary)
            Text(verbatim: graph.guide).font(.caption.monospaced()).textSelection(.enabled)
        }
    }
}

private struct InstallationQaPickContent: View {
    let question: ModInstallationQaPick
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: question.lead).textSelection(.enabled)
            Text(question.multi ? "modInstallation.graph.qaMulti" : "modInstallation.graph.qaSingle", tableName: "ModInstallation")
            Text("modInstallation.graph.qaAttempts", tableName: "ModInstallation") + Text(verbatim: " · \(question.maxTries)")
            ForEach(question.options) { option in
                Text(verbatim: option.id + " · " + option.label).font(.body)
                if option.correct { Text("modInstallation.graph.qaAnswer", tableName: "ModInstallation").font(.caption) }
                if let feedback = option.fb { Text(verbatim: feedback).textSelection(.enabled) }
            }
        }
    }
}
