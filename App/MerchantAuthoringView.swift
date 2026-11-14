import SwiftUI

/// Store authoring flow. Review lines are read from server evidence; this view has no approval action.
struct MerchantAuthoringView: View {
    @Bindable var coordinator: MerchantAuthoringCoordinator
    let owner: MerchantAuthoringOwner

    var body: some View {
        Form {
            if coordinator.owner != owner {
                Text("私有内容已清除")
            } else {
            switch coordinator.phase {
            case .list, .returned:
                Text("本店草稿")
                Button { Task { await coordinator.reload() } } label: { Text("刷新") }
                    .accessibilityIdentifier("merchant.authoring.list")
                Button { Task { await coordinator.beginNew() } } label: { Text("新建草稿") }
                    .accessibilityIdentifier("merchant.authoring.new")
            case .drafting:
                fields
                Button { Task { await coordinator.generate() } } label: { Text("生成") }
                    .accessibilityIdentifier("merchant.authoring.generate")
            case .generating:
                ProgressView()
                Text("正在生成")
                Button { Task { await coordinator.cancel() } } label: { Text("取消") }
                    .accessibilityIdentifier("merchant.authoring.cancel")
            case .unknown:
                Text("结果未知，只查询原任务")
                if !coordinator.themeMainLineBlocked { Text("主题主线仍可继续") }
                Button { Task { await coordinator.queryOriginal() } } label: { Text("查询原任务") }
                    .accessibilityIdentifier("merchant.authoring.query")
                Button { Task { await coordinator.openMainLine() } } label: { Text("主题主线") }
                    .accessibilityIdentifier("merchant.authoring.mainLine")
            case .editing:
                fields
                Button { Task { await coordinator.save() } } label: { Text("保存") }
                    .accessibilityIdentifier("merchant.authoring.save")
                Button { Task { await coordinator.loadReview() } } label: { Text("查看审核状态") }
                    .accessibilityIdentifier("merchant.authoring.review")
            case .review:
                if let presentation = coordinator.presentation {
                    Text(verbatim: presentation.merchantFactsReviewStatus)
                    Text(verbatim: presentation.themeContentReviewStatus)
                    if !presentation.clientMaySelfApprove { Text("客户端不能自行批准") }
                }
                Button { coordinator.showPublishConfirm() } label: { Text("去发布确认") }
                    .accessibilityIdentifier("merchant.authoring.publish")
            case .publishConfirm:
                Text("确认后提交发布，取消不会变成已发布")
                Button { Task { await coordinator.confirmPublish() } } label: { Text("确认发布") }
                    .accessibilityIdentifier("merchant.authoring.publish")
                Button { Task { await coordinator.cancel() } } label: { Text("取消") }
                    .accessibilityIdentifier("merchant.authoring.cancel")
            case .readBack:
                Text("权威回读 \(coordinator.releaseID ?? "")")
                Button { Task { await coordinator.readBack() } } label: { Text("再次回读") }
                    .accessibilityIdentifier("merchant.authoring.readback")
                Button { Task { await coordinator.previewPublic() } } label: { Text("公开预览") }
                    .accessibilityIdentifier("merchant.authoring.preview")
            case .preview:
                if let read = coordinator.publicRead {
                    Text(verbatim: read.releaseID)
                    ForEach(read.facts.keys.sorted(), id: \.self) { key in Text(verbatim: key + "=" + (read.facts[key] ?? "")) }
                }
                Button { Task { await coordinator.finish() } } label: { Text("返回") }
                    .accessibilityIdentifier("merchant.authoring.back")
            case .cancelled:
                Text("已取消，未发布")
                Button { Task { await coordinator.finish() } } label: { Text("返回") }
                    .accessibilityIdentifier("merchant.authoring.back")
            }
            if let note = coordinator.statusNote { Text(verbatim: note) }
            if let refusal = coordinator.refusal { Text(verbatim: String(describing: refusal)) }
            }
        }
        .navigationTitle(Text("本店 AI 草稿"))
        .task { coordinator.restore(owner) }
        .onChange(of: owner) { _, new in coordinator.adopt(new) }
        .cyDomainScreen(.merchant)
    }

    @ViewBuilder private var fields: some View {
        TextField(text: $coordinator.scene) { Text("场景") }
        TextField(text: $coordinator.binding) { Text("主题绑定") }
        TextField(text: $coordinator.templateID) { Text("已批准模板") }
        TextField(text: $coordinator.prompt) { Text("生成说明") }
        TextField(text: $coordinator.plot) { Text("剧情") }
        TextField(text: $coordinator.variablesText) { Text("允许变量") }
        TextField(text: $coordinator.branchesText) { Text("已批准分支") }
        TextField(text: $coordinator.rulesText) { Text("服务端动作规则") }
        TextField(text: $coordinator.durationText) { Text("时长分钟") }
        TextField(text: $coordinator.participantsText) { Text("人数") }
        TextField(text: $coordinator.businessHours) { Text("营业时段") }
        TextField(text: $coordinator.noise) { Text("噪音与拍摄") }
        TextField(text: $coordinator.accessible) { Text("无障碍替代") }
        TextField(text: $coordinator.offline) { Text("离线替代") }
        TextField(text: $coordinator.failureExit) { Text("失败退出") }
        TextField(text: $coordinator.rewardRuleID) { Text("奖励规则编号") }
        Button { coordinator.reward = .noReward } label: { Text("无奖励") }
        Button { let id = coordinator.rewardRuleID.trimmingCharacters(in: .whitespacesAndNewlines); if !id.isEmpty { coordinator.reward = .approvedRule(id: id) } } label: { Text("引用已批准奖励规则") }
        TextField(text: $coordinator.skuID) { Text("既有 SKU") }
        Button { coordinator.needsStaff = true } label: { Text("需要店员") }
        Button { coordinator.needsStaff = false } label: { Text("不需要店员") }
    }
}
