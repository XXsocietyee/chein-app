import SwiftUI

/// Formal-host adapter around `MiniCropView`: ratio choice plus the gesture
/// crop itself, bound to one export draft ID. Replacement retires the old view.
/// Embedded in a parent form. `MiniCropView` already shows the one screen title and the one primary.
@MainActor struct CreatorCropExportView: View {
    let draft: CreatorCropExportDraft
    let confirm: (UUID, [MiniCropView.Result]) -> Void
    let cancel: (UUID) -> Void
    @State private var ratio = "free"

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .center, spacing: CYSpacing.md) {
                CYRowIcon(systemImage: "crop")
                Picker("publishParity.crop.ratio", selection: $ratio) {
                    ForEach(MiniCropGeometry.presets, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(CYColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget, alignment: .leading)
                .accessibilityIdentifier("creatorCrop.ratio")
            }
            MiniCropView(images: draft.images, ratio: ratio,
                         onFinish: { confirm(draft.id, $0) },
                         onCancel: { cancel(draft.id) })
        }
        .background(CYColor.bgPage.ignoresSafeArea())
        .id(draft.id)
        .onDisappear { cancel(draft.id) }
    }
}
