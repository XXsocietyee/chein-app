import SwiftUI

/// Mini-program `pages/templatedetail` sections the base native detail lacked:
/// publisher with the 官方 badge, 审核反馈 (own scope only), the stat cards,
/// 核验方式 / 节点题面, 分类与适用场景, 所需物料 chips, 评价, the
/// 不能直接开团 notice and the inert 节点交互预览 sheet. Display only: nothing here
/// sends a request, grades an answer or records a preview.
@MainActor
struct DiscoveryTemplateDetailParitySections: View {
    let presentation: DiscoveryPlayTemplateDetailPresentation
    @State private var preview: TemplateNodePreviewState?

    var body: some View {
        Section {
            if showsPublisherRow { publisherRow }
            if let feedback = presentation.reviewFeedback {
                Text("discovery.templateDetail.reviewFeedback \(feedback)")
                    .font(.subheadline).foregroundStyle(.orange)
                    .accessibilityIdentifier("discovery.templateDetail.reviewFeedback")
            }
            if !stats.isEmpty {
                HStack(alignment: .top) {
                    ForEach(stats, id: \.kind) { stat in
                        VStack(spacing: 2) {
                            statValue(stat).font(.headline).monospacedDigit().foregroundStyle(.primary)
                            Text(statLabel(stat.kind)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("discovery.templateDetail.stat.\(stat.kind.rawValue)")
                    }
                }
            }
        }.discoveryCardRow()
        if presentation.verificationMethodText != nil || presentation.questionText != nil {
            Section {
                if let method = presentation.verificationMethodText {
                    LabeledContent("discovery.templateDetail.verificationMethod", value: method)
                }
                if let question = presentation.questionText {
                    LabeledContent("discovery.templateDetail.nodeQuestion", value: question)
                }
                if let node = presentation.nodePreview {
                    Button { preview = TemplateNodePreviewState(preview: node) } label: {
                        Label("discovery.templateDetail.previewNode", systemImage: "eye")
                    }
                    .accessibilityIdentifier("discovery.templateDetail.previewNode")
                }
            } header: { DiscoverySectionHeader("discovery.templateDetail.howVerified", art: MPAsset.FeatureIcon.magnifier) }.discoveryCardRow()
        }
        sceneSection(presentation.sceneChips)
        chipSection("discovery.templateDetail.materials", chips: presentation.materialChips, id: "discovery.templateDetail.materials", art: MPAsset.FeatureIcon.flashlight)
        if let rating = presentation.rating {
            Section {
                HStack {
                    Text(verbatim: rating).font(.largeTitle.weight(.semibold)).monospacedDigit()
                    if let count = presentation.commentCount, count > 0 {
                        Text("discovery.templateDetail.reviewCount \(count)")
                    } else {
                        Text("discovery.templateDetail.reviewSource")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("discovery.templateDetail.reviews")
            } header: { DiscoverySectionHeader("discovery.templateDetail.reviews", art: MPAsset.FeatureIcon.star) }.discoveryCardRow()
        }
        DiscoveryTemplateNoticeSection()
        .cySheet(item: $preview) { state in Group {
            TemplateNodePreviewSheet(state: state) { preview = nil }
        }.cySheet() }
    }

    /// Use count and duration already render in the base metadata/presentation.
    private var stats: [DiscoveryPlayTemplateDetailPresentation.Stat] {
        presentation.stats.filter { $0.kind != .uses && $0.kind != .duration }
    }

    private var showsPublisherRow: Bool {
        if case .named(_, let official) = presentation.publisher { return official }
        return true
    }

    @ViewBuilder private var publisherRow: some View {
        HStack {
            switch presentation.publisher {
            case .named(_, let official):
                // The name itself is already shown by DiscoveryPlayTemplatePresentationView.
                if official { officialBadge }
            case .mine: Text("discovery.templateDetail.publisher.mine")
            case .creator: Text("discovery.templateDetail.publisher.creator")
            case .platform:
                Text("discovery.templateDetail.publisher.platform")
                officialBadge
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery.templateDetail.publisher")
    }
    private var officialBadge: some View {
        Label("discovery.templateDetail.publisher.official", systemImage: "checkmark.seal.fill")
            .font(.subheadline)
            .foregroundStyle(.tint)
    }
    /// Round 4 image parity (MP templatedetail.wxml:140-152): 分类与适用场景 is a row of 3D category icons, one per chip.
    @ViewBuilder private func sceneSection(_ chips: [String]) -> some View {
        if !chips.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: CYSpacing.md) {
                        ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                            VStack(spacing: CYSpacing.xs) {
                                TemplateSceneArt.icon(chip).resizable().scaledToFit()
                                    .accessibilityHidden(true)
                                    .frame(width: 44, height: 44)
                                Text(verbatim: chip).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityIdentifier("discovery.templateDetail.scenes")
            } header: { DiscoverySectionHeader("discovery.templateDetail.scenes", art: MPAsset.FeatureIcon.city) }.discoveryCardRow()
        }
    }
    @ViewBuilder private func chipSection(_ title: LocalizedStringKey, chips: [String], id: String, art: Image? = nil) -> some View {
        if !chips.isEmpty {
            Section {
                Text(verbatim: chips.joined(separator: " · "))
                    .accessibilityIdentifier(id)
            } header: { DiscoverySectionHeader(title, art: art) }.discoveryCardRow()
        }
    }
    @ViewBuilder private func statValue(_ stat: DiscoveryPlayTemplateDetailPresentation.Stat) -> some View {
        if (stat.kind == .duration || stat.kind == .totalTime), Int(stat.value) != nil {
            Text("discovery.templateDetail.minutes \(stat.value)")
        } else {
            Text(verbatim: stat.value)
        }
    }
    private func statLabel(_ kind: DiscoveryPlayTemplateDetailPresentation.StatKind) -> LocalizedStringKey {
        switch kind {
        case .uses: return "discovery.templateDetail.stat.uses"
        case .rating: return "discovery.templateDetail.stat.rating"
        case .duration: return "discovery.templateDetail.stat.duration"
        case .chapters: return "discovery.templateDetail.stat.chapters"
        case .nodes: return "discovery.templateDetail.stat.nodes"
        case .totalTime: return "discovery.templateDetail.stat.totalTime"
        }
    }
}

/// 这是玩法模板，不能直接开团: outside both tabs in the mini-program, so the 能力 tab repeats it (CU-M-130).
struct DiscoveryTemplateNoticeSection: View {
    var body: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("discovery.templateDetail.notice.title")
                    Text("discovery.templateDetail.notice.body.mp").font(.footnote).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "info.circle").foregroundStyle(.tint)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("discovery.templateDetail.notice")
        }.discoveryCardRow()
    }
}

extension TemplateNodePreviewState: Identifiable {
    public var id: String { String(describing: preview) }
}

/// 节点交互预览. 完成预览 only closes once answered; the answer never leaves the sheet.
@MainActor
struct TemplateNodePreviewSheet: View {
    @State var state: TemplateNodePreviewState
    let close: () -> Void
    @State private var hint = false

    var body: some View {
        NavigationStack {
            Form {
                switch state.preview {
                case .text(let question):
                    if let question { Text(verbatim: question).font(.headline) }
                    TextField("discovery.templateDetail.preview.answerPlaceholder", text: Binding(get: { state.answer }, set: { state.type($0) }))
                        .accessibilityIdentifier("discovery.templateDetail.preview.answer")
                    completeButton
                case .choice(let question, let options):
                    if let question { Text(verbatim: question).font(.headline) }
                    ForEach(options, id: \.key) { option in
                        Button { state.select(option.key) } label: {
                            HStack {
                                Text(verbatim: "\(option.key). \(option.text)")
                                Spacer()
                                if state.selectedOption == option.key { Image(systemName: "checkmark").foregroundStyle(.tint) }
                            }
                        }
                        .accessibilityIdentifier("discovery.templateDetail.preview.option.\(option.key)")
                    }
                    completeButton
                case .unsupported(let method):
                    if let method {
                        Text("discovery.templateDetail.preview.unsupported \(method)")
                    } else {
                        Text("discovery.templateDetail.preview.unsupportedOther")
                    }
                }
                if hint {
                    Text("discovery.templateDetail.preview.answerFirst").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityIdentifier("discovery.templateDetail.preview.answerFirst")
                }
            }
            .accessibilityIdentifier("discovery.templateDetail.preview")
            .navigationTitle(Text("discovery.templateDetail.preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { close() } label: { Label("discovery.templateDetail.preview.close", systemImage: "xmark") }
                        .accessibilityLabel(Text("discovery.templateDetail.preview.close"))
                        .accessibilityIdentifier("discovery.templateDetail.preview.close")
                }
            }
        }
    }
    private var completeButton: some View {
        Button("discovery.templateDetail.preview.complete") {
            if state.canComplete { close() } else { hint = true }
        }
        .accessibilityIdentifier("discovery.templateDetail.preview.complete")
    }
}

/// MP templatedetail.js:92-106 `SCENE_ICON_RULES` / `sceneIcon`: a category or place name picks its 3D category art;
/// anything else is `art/cat/other.png`. Also the cover when a play template has none (templatedetail.wxml:41).
enum TemplateSceneArt {
    private static let rules: [(String, () -> Image)] = [
        ("运动|健身|徒步|户外|跑", { MPAsset.FeatureIcon.pagesTemplatedetailArtCatSport }),
        ("科技|数码|电子", { MPAsset.FeatureIcon.tech }),
        ("咖啡|茶饮|饮品", { MPAsset.FeatureIcon.pagesTemplatedetailArtCatCoffee }),
        ("美食|烹饪|餐|吃", { MPAsset.FeatureIcon.food }),
        ("娱乐|游戏|达人|电竞", { MPAsset.FeatureIcon.fun }),
        ("宠物", { MPAsset.FeatureIcon.pet }),
        ("商务|职场|办公", { MPAsset.FeatureIcon.biz }),
        ("世界|旅行|旅游", { MPAsset.FeatureIcon.world }),
        ("出行|交通|驾", { MPAsset.FeatureIcon.travel }),
        ("戏剧|演出|剧场|表演|话剧", { MPAsset.FeatureIcon.stage }),
        ("文化|历史|人文|博物|古迹", { MPAsset.FeatureIcon.culture }),
        ("设计|美学|艺术|文艺|手作", { MPAsset.FeatureIcon.art }),
        ("衣物|洗护|服饰", { MPAsset.FeatureIcon.cloth }),
        ("家政|维修", { MPAsset.FeatureIcon.repair }),
        ("亲子|家庭|儿童", { MPAsset.FeatureIcon.family }),
        ("摄影|拍照|影像", { MPAsset.FeatureIcon.photo }),
        ("城市|街区|城区|商圈", { MPAsset.FeatureIcon.pagesTemplatedetailArtCatCity }),
    ]
    static func icon(_ name: String?) -> Image {
        let text = name ?? ""
        for (pattern, image) in rules where text.range(of: pattern, options: .regularExpression) != nil { return image() }
        return MPAsset.FeatureIcon.other
    }
}
