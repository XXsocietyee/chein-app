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
            Text("template.imageCrop.title").font(.headline)
            if let rect, let preview = try? TemplateImageCropRenderer.preview(draft.source, rect: rect) {
                Image(uiImage: preview).resizable()
                    .aspectRatio(CGFloat(draft.source.width) / CGFloat(draft.source.height), contentMode: .fit)
                    .frame(maxHeight: 240)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("image.crop.preview")
                Text("image.crop.horizontal").font(.subheadline).foregroundStyle(.secondary)
                Slider(value: $horizontal, in: 0...1).disabled(zoom == 1)
                    .accessibilityLabel("image.crop.horizontal")
                    .accessibilityIdentifier("template.imageCrop.horizontal")
                Text("image.crop.vertical").font(.subheadline).foregroundStyle(.secondary)
                Slider(value: $vertical, in: 0...1).disabled(zoom == 1)
                    .accessibilityLabel("image.crop.vertical")
                    .accessibilityIdentifier("template.imageCrop.vertical")
                Text("image.crop.zoom").font(.subheadline).foregroundStyle(.secondary)
                Slider(value: $zoom, in: 1...4).accessibilityLabel("image.crop.zoom")
                    .accessibilityIdentifier("template.imageCrop.zoom")
                // One solid action (mini 选取); reset / use-original / cancel stay quiet.
                Button { confirm(draft.id, rect) } label: { Text("template.imageCrop.confirm").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
                    .accessibilityIdentifier("template.imageCrop.confirm")
                Button { horizontal = 0.5; vertical = 0.5; zoom = 1 } label: { Label("template.imageCrop.reset", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(.borderless)
                    .accessibilityIdentifier("template.imageCrop.reset")
                // Mini pages/crop "使用原图": the identity rect keeps the original bytes unchanged.
                if let original = try? TemplateImageCropRect(sourceWidth: draft.source.width, sourceHeight: draft.source.height,
                                                             horizontal: 0.5, vertical: 0.5, zoom: 1) {
                    Button { confirm(draft.id, original) } label: { Text("publishParity.crop.useOriginal").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered).controlSize(.large)
                        .accessibilityIdentifier("template.imageCrop.useOriginal")
                }
            } else {
                // pages/crop error copy from CropPageModel: a non-positive size or an unrenderable preview.
                let page = CropPageModel.facts(hasOpener: true, paths: [draft.id.uuidString],
                                               width: Double(draft.source.width), height: Double(draft.source.height),
                                               failed: true)
                Text(LocalizedStringKey(page.copyKey)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("template.imageCrop.failed")
            }
            Button("image.retained.cancel", role: .cancel) { cancel(draft.id) }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("template.imageCrop.cancel")
        }
        .onDisappear { cancel(draft.id) }
    }
}
