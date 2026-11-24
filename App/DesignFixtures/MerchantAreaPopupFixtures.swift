#if DEBUG
import SwiftUI

/// DEBUG fixtures for merchant / coop / publish / creator / template popups and sheets.
/// Reachable with `--design-fixture merchant-popup-<kind>`. Synthetic data only; never ships in Release.
enum MerchantAreaPopupFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "merchant-popup-discard":
            return lightWrap(.merchant, MerchantPopupDiscardFixture())
        case "merchant-popup-exit-guard":
            return lightWrap(.topicEditor, MerchantPopupExitGuardFixture())
        case "merchant-popup-danger-confirm":
            return lightWrap(.merchant, MerchantPopupDangerConfirmFixture())
        case "merchant-popup-prompt":
            return lightWrap(.topicEditor, MerchantPopupPromptFixture())
        case "merchant-popup-coop-score":
            return lightWrap(.merchant, MerchantPopupCoopScoreFixture())
        case "merchant-popup-bind-node":
            return lightWrap(.topicEditor, MerchantPopupBindNodeFixture())
        case "merchant-popup-toast":
            return lightWrap(.merchant, MerchantPopupToastFixture())
        default:
            return nil
        }
    }

    @MainActor private static func lightWrap<V: View>(_ domain: ThemeDomain, _ view: V) -> AnyView {
        AnyView(
            view
                .themeDomain(domain)
                .preferredColorScheme(.light)
                .environment(\.locale, Locale(identifier: "zh-Hans"))
        )
    }
}

@MainActor private struct MerchantPopupDiscardFixture: View {
    @State private var showModal = true

    var body: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.md) {
                Text(verbatim: "商家资料编辑页 (DEBUG)")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                CYPillButton("merchant.coopField.discard") { showModal = true }
            }
            .padding(CYSpacing.lg)
            .navigationTitle(Text(verbatim: "编辑门店字段")).navigationBarTitleDisplayMode(.inline)
        }
        .cyModalConfirm(
            isPresented: $showModal,
            title: "放弃尚未保存的修改？",
            message: "其余草稿修改将保留在本地。",
            cancelTitle: "继续编辑",
            confirmTitle: "放弃",
            isDestructive: true,
            cancelIdentifier: "merchant.coopField.keepEditing",
            confirmIdentifier: "merchant.coopField.discard",
            onCancel: { showModal = false },
            onConfirm: { showModal = false }
        )
    }
}

@MainActor private struct MerchantPopupExitGuardFixture: View {
    @State private var showModal = true

    var body: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.md) {
                Text(verbatim: "互动模板编辑器 (DEBUG)")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                CYPillButton("action.leave") { showModal = true }
            }
            .padding(CYSpacing.lg)
            .navigationTitle(Text(verbatim: "互动模板编辑")).navigationBarTitleDisplayMode(.inline)
        }
        .cyModalConfirm(
            isPresented: $showModal,
            title: "离开创作编辑？",
            message: "无法确认草稿已保存。可重新检查、继续编辑，或不保存离开。",
            consequences: [
                CYConfirmConsequence(systemImage: "exclamationmark.triangle", text: "未保存的本地改动会丢失"),
                CYConfirmConsequence(systemImage: "arrow.clockwise", text: "可先重新检查当前本地草稿保存状态"),
            ],
            cancelTitle: "继续编辑",
            confirmTitle: "不保存，直接离开",
            lighterAlternativeTitle: "重新检查保存状态",
            isDestructive: true,
            cancelIdentifier: "templateAuthorExit.continue",
            confirmIdentifier: "templateAuthorExit.leave",
            onCancel: { showModal = false },
            onLighterAlternative: { showModal = false },
            onConfirm: { showModal = false }
        )
    }
}

@MainActor private struct MerchantPopupDangerConfirmFixture: View {
    @State private var confirmed = false

    var body: some View {
        CYConfirmSheet(
            title: "删除门店桌台锚点？",
            message: "删除后顾客扫码将不再识别此桌台，可在商家工作台重新绑定。",
            confirmTitle: confirmed ? "已删除" : "删除锚点",
            isDestructive: true,
            consequences: [
                CYConfirmConsequence(systemImage: "qrcode", text: "桌台 A-04 的静态二维码立即失效"),
                CYConfirmConsequence(systemImage: "clock", text: "已开始的游玩会话不受影响"),
            ],
            onConfirm: { confirmed = true }
        )
    }
}

@MainActor private struct MerchantPopupPromptFixture: View {
    @State private var presented = true
    @State private var name = "线索：老街门牌"

    var body: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.md) {
                Text(verbatim: "创作者工具 · 状态键管理 (DEBUG)")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                CYPillButton("creatorEditor.keys.rename") { presented = true }
            }
            .padding(CYSpacing.lg)
            .navigationTitle(Text(verbatim: "重命名状态键")).navigationBarTitleDisplayMode(.inline)
        }
        .cyPromptModalOverlay(
            isPresented: $presented,
            title: "重命名",
            message: "更新后所有引用该状态键的章节条件保持同步。",
            text: $name,
            placeholder: "名称",
            validationMessage: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "请输入名称" : nil,
            cancelTitle: "取消",
            confirmTitle: "保存",
            onCancel: { presented = false },
            onConfirm: {
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                presented = false
            }
        )
    }
}

@MainActor private struct MerchantPopupCoopScoreFixture: View {
    @State private var selectedID: String? = "5"

    var body: some View {
        MerchantChoiceOptionSheet(
            title: "这次合作打几分",
            options: CoopReviewScore.allCases.map { $0.option(locale: Locale(identifier: "zh-Hans")) },
            domain: .merchant,
            selectedID: $selectedID,
            onSelect: { selectedID = $0.id },
            onClose: {}
        )
    }
}

@MainActor private struct MerchantPopupBindNodeFixture: View {
    @State private var selectedID: String? = "102"

    var body: some View {
        MerchantChoiceOptionSheet(
            title: "绑定到哪个节点",
            options: [
                MerchantChoiceOption(id: "101", title: "茶馆起点 · 武康路 12 号", systemImage: "mappin.and.ellipse"),
                MerchantChoiceOption(id: "102", title: "钟楼广场 · 中山路 88 号", systemImage: "mappin.and.ellipse"),
                MerchantChoiceOption(id: "103", title: "老码头终点 · 滨江大道 5 号", systemImage: "mappin.and.ellipse"),
            ],
            domain: .topicEditor,
            selectedID: $selectedID,
            onSelect: { selectedID = $0.id },
            onClose: {}
        )
    }
}

@MainActor private struct MerchantPopupToastFixture: View {
    @State private var toastMessage: String? = "电话号码已复制，请在拨打时核对合作编号"

    var body: some View {
        NavigationStack {
            VStack(spacing: CYSpacing.md) {
                Text(verbatim: "合作与城市节点提示 (DEBUG)")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                CYPillButton("coopflow.copyPhone") {
                    toastMessage = "电话号码已复制，请在拨打时核对合作编号"
                }
            }
            .padding(CYSpacing.lg)
            .navigationTitle(Text(verbatim: "合作详情")).navigationBarTitleDisplayMode(.inline)
        }
        .cyToast(verbatimMessage: $toastMessage, tone: .info)
    }
}
#endif
