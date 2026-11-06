import SwiftUI

/// Explicit package-content language; app UI locale and the original scan command are independent.
@MainActor struct ModVenueContentLanguagePicker: View {
    @Bindable var model: PlayExperienceCoordinator
    let nodeID: Int
    var body: some View {
        if let projection = model.modVenueContentLanguageProjection(nodeID: nodeID),
           let selected = model.modVenueSelectedContentLanguage(nodeID: nodeID), let generation = model.mediaSnapshotGeneration {
            Picker("内容语言 / Content language", selection: Binding(get: { selected }, set: { locale in
                Task { await model.selectModVenueContentLanguage(locale, nodeID: nodeID, expectedGeneration: generation, expectedProjection: projection) }
            })) {
                ForEach(projection.locales, id: \.self) { language in
                    Text(verbatim: language == "en" ? "English" : "简体中文").tag(language)
                }
            }
            .disabled(!model.canSelectModVenueContentLanguage(nodeID: nodeID))
            .accessibilityIdentifier("qmod.venue.contentLanguage.\(nodeID)")
            if model.modVenueContentLanguageIssue != nil {
                Text("内容语言偏好暂不可恢复或保存；当前显示已审核的内容，请刷新重试。 / The content-language preference could not be restored or saved. Refresh to retry.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }
}
