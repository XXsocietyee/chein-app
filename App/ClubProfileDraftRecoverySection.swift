import SwiftUI

@MainActor struct ClubProfileDraftRecoverySection: View {
    @ObservedObject var flow: ClubProfileLocalDraftFlow
    let busy: Bool
    let restore: () -> Void
    let discard: () -> Void
    let readFresh: () -> Void
    let useCurrentImages: () -> Void
    @State private var confirmsDiscard = false
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            Text(LocalizedStringKey("localDraft." + String(describing: flow.state)), tableName: "ClubProfileLocalDraft")
                .accessibilityIdentifier("club.profile.draft.state")
            if flow.restored { Text("localDraft.restored", tableName: "ClubProfileLocalDraft") }
            if flow.canRestore {
                Button { restore() } label: { Text("localDraft.restore", tableName: "ClubProfileLocalDraft") }
                    .disabled(busy).accessibilityIdentifier("club.profile.draft.restore")
            }
            if flow.canDiscard {
                Button(role: .destructive) { confirmsDiscard = true } label: { Text("localDraft.discard", tableName: "ClubProfileLocalDraft") }
                    .disabled(busy).accessibilityIdentifier("club.profile.draft.discard")
            }
            if !flow.differences.isEmpty {
                Text("localDraft.comparison", tableName: "ClubProfileLocalDraft").font(.headline)
                ForEach(flow.differences) { difference in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("localDraft.field." + difference.id), tableName: "ClubProfileLocalDraft").font(.subheadline.bold())
                        if difference.id == "logo" || difference.id == "cover" {
                            Text("localDraft.imageDifference", tableName: "ClubProfileLocalDraft")
                        } else {
                            Text("localDraft.savedValue", tableName: "ClubProfileLocalDraft").font(.footnote).foregroundStyle(.secondary)
                            Text(verbatim: difference.saved).textSelection(.enabled)
                            Text("localDraft.currentValue", tableName: "ClubProfileLocalDraft").font(.footnote).foregroundStyle(.secondary)
                            Text(verbatim: difference.current).textSelection(.enabled)
                        }
                    }.accessibilityIdentifier("club.profile.draft.compare." + difference.id)
                }
            }
            if flow.mediaRequiresSelection {
                Text("localDraft.mediaRequiresSelection", tableName: "ClubProfileLocalDraft")
                Button { useCurrentImages() } label: { Text("localDraft.useCurrentImages", tableName: "ClubProfileLocalDraft") }
                    .disabled(busy || flow.blocksEditing).accessibilityIdentifier("club.profile.draft.currentImages")
            }
            if flow.blocksEditing {
                Button { readFresh() } label: { Text("localDraft.readFresh", tableName: "ClubProfileLocalDraft") }
                    .disabled(busy).accessibilityIdentifier("club.profile.draft.readFresh")
            }
        } header: { Text("localDraft.title", tableName: "ClubProfileLocalDraft") } footer: {
            Text("localDraft.localOnly", tableName: "ClubProfileLocalDraft")
        }
        .confirmationDialog(String(localized: LocalizedStringResource("localDraft.discardTitle", table: "ClubProfileLocalDraft", locale: locale)),
                            isPresented: $confirmsDiscard, titleVisibility: .visible) {
            Button(String(localized: LocalizedStringResource("localDraft.discard", table: "ClubProfileLocalDraft", locale: locale)), role: .destructive) {
                confirmsDiscard = false
                discard()
            }
            Button(String(localized: LocalizedStringResource("localDraft.cancel", table: "ClubProfileLocalDraft", locale: locale)), role: .cancel) {
                confirmsDiscard = false
            }
        } message: {
            Text("localDraft.discardMessage", tableName: "ClubProfileLocalDraft")
        }
    }
}
