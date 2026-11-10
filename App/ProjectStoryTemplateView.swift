import SwiftUI

/// The owned-draft reader provides candidates; only this explicit local apply button adopts
/// the immutable reviewed value. No remote authoring, upload, or publication controls exist.
@MainActor struct ProjectStoryTemplateView: View {
    @ObservedObject var controller: ProjectStoryTemplatePresentation
    let original: ProjectStoryTemplatePresentation.Opening
    var nodeSelection = false
    @Environment(\.locale) private var locale
    private var title: Text { nodeSelection ? Text("projectNodeTemplate.title", tableName: "ProjectNodeTemplateSelection") : Text("projectStoryTemplate.title") }
    var body: some View {
        NavigationStack {
            Form {
                Section { CYHeroHeader(verbatim: nodeSelection ? String(localized: LocalizedStringResource("projectNodeTemplate.title", table: "ProjectNodeTemplateSelection", locale: locale)) : String(localized: LocalizedStringResource("projectStoryTemplate.title", table: "Localizable", locale: locale))) }.e1HeroRow()
                Section {
                    if nodeSelection { Text("projectNodeTemplate.scope", tableName: "ProjectNodeTemplateSelection").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                    else { Text("projectStoryTemplate.scope").font(CYTypography.meta).foregroundStyle(CYColor.textTertiary) }
                }
                if let review = controller.review {
                    Section("projectStoryTemplate.previewTitle") {
                        Text(verbatim: review.source.row.title).font(CYTypography.sectionTitle).accessibilityAddTraits(.isHeader).accessibilityIdentifier("projectStoryTemplate.preview.title")
                        Group {
                            if nodeSelection { ProjectStoryTemplatePreview(source: review.source, nodeSelection: true) }
                            else { ProjectStoryTemplatePreview(source: review.source) }
                        }.accessibilityElement(children: .contain).accessibilityIdentifier("projectStoryTemplate.preview")
                    }
                    Section {
                        CYPillButton(nodeSelection ? "projectNodeTemplate.apply" : "projectStoryTemplate.apply", tableName: nodeSelection ? "ProjectNodeTemplateSelection" : nil) { _ = controller.apply(review, original: original) }
                            .disabled(controller.busy || !controller.isCurrent(original))
                            .accessibilityIdentifier("projectStoryTemplate.apply").e1ActionRow()
                        CYPillButton("projectStoryTemplate.back", style: .tertiary) { controller.back(original) }
                            .disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.back").e1ActionRow()
                    }
                } else {
                    Section {
                        CYPillButton("projectStoryTemplate.refresh", style: .secondary, systemImage: "arrow.clockwise") { _ = controller.refresh(original) }
                            .disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.refresh").e1ActionRow()
                        ForEach(controller.rows) { row in
                            Button { _ = controller.select(row, original: original) } label: {
                                CYListRow(verbatim: row.title, meta: String(row.id.rawValue)) { CYRowIcon(systemImage: "text.book.closed") }
                            }.disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.row.\(row.id.rawValue)")
                        }
                        if controller.state == .ready && controller.rows.isEmpty { CYEmptyState(systemImage: "text.book.closed", "projectStoryTemplate.empty").listRowBackground(Color.clear) }
                        if controller.nextPage != nil {
                            CYPillButton("projectStoryTemplate.more", style: .secondary) { _ = controller.loadMore(original) }
                                .disabled(controller.busy).accessibilityIdentifier("projectStoryTemplate.more").e1ActionRow()
                        }
                    }
                }
                if nodeSelection && controller.state == .unsupported { Text("projectNodeTemplate.unsupported", tableName: "ProjectNodeTemplateSelection") }
                if controller.busy { CYSkeletonBlock(height: 18).accessibilityLabel(Text("cy.state.loading")).accessibilityIdentifier("projectStoryTemplate.busy") }
                if [.failed, .changed, .saveFailed].contains(controller.state) {
                    Text(LocalizedStringKey("projectStoryTemplate." + controller.state.rawValue))
                        .accessibilityIdentifier("projectStoryTemplate.status")
                }
            }.formStyle(.grouped).cyGroupedSurface().cyHeroScreen()
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
