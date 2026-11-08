import SwiftUI

/// Local draft-ID-bound crop controls, reused by bounded template and story-image hosts.
@MainActor struct TemplateImageCropView: View {
    let draft: TemplateImageCropDraft
    let confirm: (UUID, TemplateImageCropRect) -> Void
    let cancel: (UUID) -> Void
    var body: some View {
        TemplateImageCropControls(draft: draft, confirm: confirm, cancel: cancel)
            .id(draft.id) // Replacement resets every control and retires the old view.
    }
}

@MainActor private struct TemplateImageCropControls: View {
    let draft: TemplateImageCropDraft
    let confirm: (UUID, TemplateImageCropRect) -> Void
    let cancel: (UUID) -> Void
    @State private var horizontal = 0.5
    @State private var vertical = 0.5
    @State private var zoom = 1.0
    private var rect: TemplateImageCropRect? {
        try? .init(sourceWidth: draft.source.width, sourceHeight: draft.source.height,
                   horizontal: horizontal, vertical: vertical, zoom: zoom)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("template.imageCrop.title").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
            if let rect, let preview = try? TemplateImageCropRenderer.preview(draft.source, rect: rect) {
                Image(uiImage: preview).resizable()
                    .aspectRatio(CGFloat(draft.source.width) / CGFloat(draft.source.height), contentMode: .fit)
                    .frame(maxHeight: 240)
                    // Mini stage: image on a near-black ground with a hairline frame.
                    .overlay(Rectangle().stroke(CYColor.borderStrong, lineWidth: 1))
                    .frame(maxWidth: .infinity).padding(CYSpacing.sm).background(CYColor.bgPage)
                    .accessibilityLabel("image.crop.preview")
                Text("image.crop.horizontal").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                Slider(value: $horizontal, in: 0...1).disabled(zoom == 1)
                    .accessibilityLabel("image.crop.horizontal")
                    .accessibilityIdentifier("template.imageCrop.horizontal")
                Text("image.crop.vertical").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                Slider(value: $vertical, in: 0...1).disabled(zoom == 1)
                    .accessibilityLabel("image.crop.vertical")
                    .accessibilityIdentifier("template.imageCrop.vertical")
                Text("image.crop.zoom").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                Slider(value: $zoom, in: 1...4).accessibilityLabel("image.crop.zoom")
                    .accessibilityIdentifier("template.imageCrop.zoom")
                Button("template.imageCrop.reset") { horizontal = 0.5; vertical = 0.5; zoom = 1 }
                    .accessibilityIdentifier("template.imageCrop.reset")
                // One solid action (mini 选取); reset / use-original / cancel stay quiet.
                Button("template.imageCrop.confirm") { confirm(draft.id, rect) }
                    .buttonStyle(.cyPrimary)
                    .accessibilityIdentifier("template.imageCrop.confirm")
                // Mini pages/crop "使用原图": the identity rect keeps the original bytes unchanged.
                if let original = try? TemplateImageCropRect(sourceWidth: draft.source.width, sourceHeight: draft.source.height,
                                                             horizontal: 0.5, vertical: 0.5, zoom: 1) {
                    Button("publishParity.crop.useOriginal") { confirm(draft.id, original) }
                        .accessibilityIdentifier("template.imageCrop.useOriginal")
                }
            } else { Text("image.retained.failed").font(CYTypography.body).foregroundStyle(CYColor.textSecondary) }
            Button("image.retained.cancel", role: .cancel) { cancel(draft.id) }
                .accessibilityIdentifier("template.imageCrop.cancel")
        }
        .buttonStyle(.borderless)
        .onDisappear { cancel(draft.id) }
    }
}
