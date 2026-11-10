import SwiftUI

/// The owned-draft reader provides candidates; only this explicit local apply button adopts
/// the immutable reviewed value. No remote authoring, upload, or publication controls exist.
@MainActor struct ProjectStoryTemplateView: View {
    @ObservedObject var controller: ProjectStoryTemplatePresentation
    let original: ProjectStoryTemplatePresentation.Opening
    var nodeSelection = false
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if nodeSelection { CYHeroHeader("projectNodeTemplate.title", tableName: "ProjectNodeTemplateSelection") }
                    else { CYHeroHeader("projectStoryTemplate.title") }
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Section {
                    if nodeSelection { Text("projectNodeTemplate.scope", tableName: "ProjectNodeTemplateSelection").font(.footnote) }
                    else { Text("projectStoryTemplate.scope").font(.footnote) }
                }
                if let review = controller.review {
                    Section("projectStoryTemplate.previewTitle") {
                        Text(verbatim: review.source.row.title).font(.headline).accessibilityIdentifier("projectStoryTemplate.preview.title")
                        Group {
                            if nodeSelection { ProjectStoryTemplatePreview(source: review.source, nodeSelection: true) }
                            else { ProjectStoryTemplatePreview(source: review.source) }
                        }.accessibilityElement(children: .contain).accessibilityIdentifier("projectStoryTemplate.preview")
                    }
                    Section {
                        Group {
                            if nodeSelection { CYPillButton("projectNodeTemplate.apply", style: .primary, tableName: "ProjectNodeTemplateSelection") { _ = controller.apply(review, original: original) } }
                            else { CYPillButton("projectStoryTemplate.apply", style: .primary) { _ = controller.apply(review, original: original) } }
                        }
                            .disabled(controller.busy || !controller.isCurrent(original))
                            .accessibilityIdentifier("projectStoryTemplate.apply")
                        CYPillButton("projectStoryTemplate.back", style: .tertiary) { controller.back(original) }
                            .disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.back")
                    }
                } else {
                    Section {
                        CYPillButton("projectStoryTemplate.refresh", style: .secondary) { _ = controller.refresh(original) }
                            .disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.refresh")
                        ForEach(controller.rows) { row in
                            Button { _ = controller.select(row, original: original) } label: {
                                VStack(alignment: .leading) { Text(verbatim: row.title); Text(verbatim: String(row.id.rawValue)).font(.caption).foregroundStyle(.secondary) }
                            }.disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.row.\(row.id.rawValue)")
                        }
                        if controller.state == .ready && controller.rows.isEmpty { Text("projectStoryTemplate.empty") }
                        if controller.nextPage != nil {
                            CYPillButton("projectStoryTemplate.more", style: .secondary) { _ = controller.loadMore(original) }
                                .disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.more")
                        }
                    }
                }
                if nodeSelection && controller.state == .unsupported { Text("projectNodeTemplate.unsupported", tableName: "ProjectNodeTemplateSelection") }
                if controller.busy { CYLoadingStateView(rows: 1).accessibilityIdentifier("projectStoryTemplate.busy") }
                if [.failed, .changed, .saveFailed].contains(controller.state) {
                    Text(LocalizedStringKey("projectStoryTemplate." + controller.state.rawValue))
                        .accessibilityIdentifier("projectStoryTemplate.status")
                }
            }.cyGroupedSurface()
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("projectStoryTemplate.close") { controller.close(original) }
                        .accessibilityIdentifier("projectStoryTemplate.close")
                } }
        }.onDisappear { controller.close(original) }
    }
}

private struct ProjectStoryTemplatePreview: View {
    let source: ProjectStoryTemplateDraft
    var nodeSelection = false
    var body: some View {
        switch source.content {
        case .gameplay:
            if nodeSelection { Text("projectNodeTemplate.gameplay", tableName: "ProjectNodeTemplateSelection") }
            else { Text("projectStoryTemplate.gameplay") }
            LabeledContent("projectEdit.templateID", value: String(source.row.id.rawValue))
                .accessibilityIdentifier("projectStoryTemplate.preview.templateID")
        case .album(let images):
            Text("projectStoryTemplate.album")
            ForEach(Array(images.enumerated()), id: \.offset) { index, raw in
                if let image = raw.object {
                    Text(verbatim: image["url"]?.text ?? "").textSelection(.enabled)
                        .accessibilityIdentifier("projectStoryTemplate.preview.image.\(index)")
                    if let line = image["line"]?.text { Text(verbatim: line).accessibilityIdentifier("projectStoryTemplate.preview.caption.\(index)") }
                }
            }
        }
    }
}
