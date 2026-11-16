import SwiftUI

/// Design hand-off r1 CF-44: the gameplay editor opens on a 16:9 cover with the title over its bottom
/// edge (it was a 1:1 cover that filled the first screen). The cover uses the gated cached image loader;
/// with no cover it shows the neutral fallback, never a placeholder glyph block.
struct TemplateAuthoringCoverHeader: View {
    let imageURL: String?
    let title: String

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
                            .overlay(Image(systemName: "photo").font(.title).foregroundStyle(palette.onCoverFgDim))
                    }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Group {
                    if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        EditorKitText.text("editorKit.cover.untitled")
                    } else {
                        Text(verbatim: title)
                    }
                }
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(CYSpacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                // verify-r1 2.9: a fixed dark scrim (to 55% black) so the white title reaches 4.5:1 on a pale cover or
                // on the light placeholder; the theme overlay token was too light on the editor domain.
                .background(LinearGradient(colors: [.black.opacity(0), .black.opacity(0.55)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: EditorKitMetric.cardRadius, style: .continuous))
            .textCase(nil)
            .padding(.bottom, CYSpacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("editorKit.templateCoverHeader")
    }
}
