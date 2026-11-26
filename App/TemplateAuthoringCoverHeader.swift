import SwiftUI

/// Design hand-off r1 CF-44: the gameplay editor opens on a 16:9 cover with the title over its bottom
/// edge (it was a 1:1 cover that filled the first screen). The cover uses the gated cached image loader;
/// with no cover it shows the neutral fallback, never a placeholder glyph block.
///
/// verify-r1 2.9 (`237:43689`): the title on the cover is the name field itself (white, with a pencil), so the page has
/// no separate 名称 row. The field keeps the `templateAuthor.field.title` identifier.
struct TemplateAuthoringCoverHeader: View {
    let imageURL: String?
    @Binding var title: String
    var editable: Bool = true
    /// Round 4 image parity (MP publish/temp wxml:1240 `formData.imgUrl || defaultCover`, utils/template-display.js
    /// `gameTemplateCover`): with no uploaded cover, a built-in interaction game shows its MP default art.
    var defaultCover: Image? = nil
    @FocusState private var editingTitle: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Color.clear
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        if let imageURL, !imageURL.isEmpty {
                            // The shared loader draws 16:10; centre it and clip to 16:9.
                            CYCachedAsyncImage(imageURL, role: .cover)
                                .frame(width: geometry.size.width, height: geometry.size.width * 10.0 / 16.0)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        } else if let defaultCover {
                            defaultCover
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .accessibilityHidden(true)
                        } else {
                            Color(.secondarySystemFill)
                                .overlay(Image(systemName: "photo").accessibilityHidden(true).font(.title).foregroundStyle(.secondary))
                        }
                    }
                }
                // Image crop only: the cover artwork keeps the system grouped-row corner.
                .clipShape(.rect(cornerRadius: EditorKitMetric.cardRadius, style: .continuous))
            // verify-r1 2.9: the title is the name field itself (no separate 名称 row); a plain system text field
            // below the cover instead of white text on a scrim.
            TextField(text: $title, prompt: EditorKitText.text("editorKit.cover.untitled"), axis: .vertical) {
                Text("templateAuthor.field.title")
            }
            .lineLimit(1...3)
            .font(.title2.bold())
            .foregroundStyle(.primary)
            .submitLabel(.done)
            .focused($editingTitle)
            .disabled(!editable)
            .accessibilityIdentifier("templateAuthor.field.title")
            .accessibilityHint(editable ? EditorKitText.text("editorKit.cover.editTitleHint") : Text(verbatim: ""))
        }
        .textCase(nil)
        .padding(.bottom, CYSpacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("editorKit.templateCoverHeader")
    }
}
