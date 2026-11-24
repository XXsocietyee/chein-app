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
    @Environment(\.cyPalette) private var palette

    var body: some View {
        Section {
            if showsPublisherRow { publisherRow }
            if let feedback = presentation.reviewFeedback {
                Text("discovery.templateDetail.reviewFeedback \(feedback)")
                    .cyText(.bodyCompact).foregroundStyle(palette.warning)
                    .accessibilityIdentifier("discovery.templateDetail.reviewFeedback")
            }
            if !stats.isEmpty {
                HStack(alignment: .top) {
                    ForEach(stats, id: \.kind) { stat in
                        VStack(spacing: 2) {
                            statValue(stat).cyText(.numericBody).foregroundStyle(palette.textPrimary)
                            Text(statLabel(stat.kind)).cyText(.caption).foregroundStyle(palette.textSecondary)
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
            } header: { DiscoverySectionHeader("discovery.templateDetail.howVerified") }.discoveryCardRow()
        }
        chipSection("discovery.templateDetail.scenes", chips: presentation.sceneChips, id: "discovery.templateDetail.scenes")
        chipSection("discovery.templateDetail.materials", chips: presentation.materialChips, id: "discovery.templateDetail.materials")
        if let rating = presentation.rating {
            Section {
                HStack {
                    Text(verbatim: rating).cyText(.dataXL).monospacedDigit()
                    if let count = presentation.commentCount, count > 0 {
                        Text("discovery.templateDetail.reviewCount \(count)")
                    } else {
                        Text("discovery.templateDetail.reviewSource")
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("discovery.templateDetail.reviews")
            } header: { DiscoverySectionHeader("discovery.templateDetail.reviews") }.discoveryCardRow()
        }
        DiscoveryTemplateNoticeSection()
        .sheet(item: $preview) { state in Group {
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
        .cyText(.label)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("discovery.templateDetail.publisher")
    }
    private var officialBadge: some View {
        Text("discovery.templateDetail.publisher.official").cyText(.caption, weight: .bold)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(.tint.opacity(0.15), in: Capsule())
    }
    @ViewBuilder private func chipSection(_ title: LocalizedStringKey, chips: [String], id: String) -> some View {
        if !chips.isEmpty {
            Section {
                Text(verbatim: chips.joined(separator: " · "))
                    .cyText(.body).foregroundStyle(palette.textSecondary)
                    .accessibilityIdentifier(id)
            } header: { DiscoverySectionHeader(title) }.discoveryCardRow()
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
    @Environment(\.cyPalette) private var palette
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text("discovery.templateDetail.notice.title").cyText(.label)
                Text("discovery.templateDetail.notice.body.mp").cyText(.meta).foregroundStyle(palette.textSecondary)
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
                    if let question { Text(verbatim: question).cyText(.cardTitle) }
                    TextField("discovery.templateDetail.preview.answerPlaceholder", text: Binding(get: { state.answer }, set: { state.type($0) }))
                        .accessibilityIdentifier("discovery.templateDetail.preview.answer")
                    completeButton
                case .choice(let question, let options):
                    if let question { Text(verbatim: question).cyText(.cardTitle) }
                    ForEach(options, id: \.key) { option in
                        Button { state.select(option.key) } label: {
                            HStack {
                                Text(verbatim: "\(option.key). \(option.text)")
                                Spacer()
                                if state.selectedOption == option.key { Image(systemName: "checkmark") }
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
                    Text("discovery.templateDetail.preview.answerFirst").cyText(.bodyCompact).foregroundStyle(.secondary)
                        .accessibilityIdentifier("discovery.templateDetail.preview.answerFirst")
                }
            }
            .accessibilityIdentifier("discovery.templateDetail.preview")
            .navigationTitle(Text("discovery.templateDetail.preview.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { close() } label: { Image(systemName: "xmark") }
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
