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
    @FocusState private var editingTitle: Bool

    @Environment(\.cyPalette) private var palette

    var body: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                GeometryReader { geometry in
                    if let imageURL, !imageURL.isEmpty {
                        // The shared loader draws 16:10; centre it and clip to 16:9.
                        CYCachedAsyncImage(imageURL, role: .cover)
                            .frame(width: geometry.size.width, height: geometry.size.width * 10.0 / 16.0)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    } else {
                        palette.coverFallback
                            .overlay(Image(systemName: "photo").accessibilityHidden(true).font(.title).foregroundStyle(palette.onCoverFgDim))
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                    TextField(text: $title, prompt: EditorKitText.text("editorKit.cover.untitled").foregroundStyle(Color.white.opacity(0.75)), axis: .vertical) {
                        Text("templateAuthor.field.title")
                    }
                    .lineLimit(1...3)
                    .cyText(.sectionTitle)
                    .foregroundStyle(Color.white)
                    .tint(Color.white)
                    .submitLabel(.done)
                    .focused($editingTitle)
                    .disabled(!editable)
                    .accessibilityIdentifier("templateAuthor.field.title")
                    if editable {
                        Button { editingTitle = true } label: {
                            Image(systemName: "pencil")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.white)
                                .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("templateAuthor.field.title"))
                        .accessibilityHint(EditorKitText.text("editorKit.cover.editTitleHint"))
                    }
                }
                .padding(.leading, CYSpacing.lg)
                .padding(.trailing, CYSpacing.xs)
                .padding(.vertical, CYSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                // verify-r1 2.9: a fixed dark scrim (45% to 70% black) so the white title reaches 4.5:1 on a pale cover or
                // on the light placeholder; the theme overlay token was too light on the editor domain.
                .background(LinearGradient(colors: [.black.opacity(0.45), .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: EditorKitMetric.cardRadius, style: .continuous))
            .textCase(nil)
            .padding(.bottom, CYSpacing.sm)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("editorKit.templateCoverHeader")
    }
}
