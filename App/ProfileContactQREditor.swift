import SwiftUI

@MainActor struct ProfileContactQRSection<Upload: View>: View {
    let wechat: String
    let removes: Bool
    /// A3-01: a new code is staged to replace the saved one.
    var replaced: Bool = false
    let open: () -> Void
    @ViewBuilder var upload: () -> Upload
    private var statusKey: String {
        if replaced { return "profile.contactQR.replaced" }
        return removes ? "profile.contactQR.staged" : (wechat.isEmpty ? "profile.contactQR.empty" : "profile.contactQR.available")
    }
    var body: some View {
        Section("profile.contactQR.title") {
            Button(action: open) {
                HStack {
                    Label("profile.contactQR.open", systemImage: "qrcode")
                    Spacer()
                    Text(LocalizedStringKey(statusKey))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.forward").cyText(.caption).accessibilityHidden(true)
                }
            }.buttonStyle(.plain).accessibilityIdentifier("profile.contactQR.open")
            upload()
        }
    }
}
extension ProfileContactQRSection where Upload == EmptyView {
    init(wechat: String, removes: Bool, open: @escaping () -> Void) {
        self.init(wechat: wechat, removes: removes, open: open, upload: { EmptyView() })
    }
}

/// Removal-only sheet: clearing the existing QR reference, no URL entry. A new code is uploaded from the
/// profile page's 上传二维码 row (A3-01), not here.
@MainActor struct ProfileContactQREditor: View {
    let edit: ProfileTextFieldEdit
    let reader: (any RetainedPublicImageReading)?
    let savedPreview: (() -> AnyView)?
    let cancel: () -> Void
    let confirm: (Bool) -> Void
    @State private var removes: Bool
    init(edit: ProfileTextFieldEdit, reader: (any RetainedPublicImageReading)? = nil,
         savedPreview: (() -> AnyView)? = nil, cancel: @escaping () -> Void, confirm: @escaping (Bool) -> Void) {
        self.savedPreview = savedPreview
        self.edit = edit; self.reader = reader; self.cancel = cancel; self.confirm = confirm
        _removes = State(initialValue: edit.draft.removesContactQR)
    }
    var body: some View {
        Form {
            if let savedPreview { Section { savedPreview() } }
            Section {
                if edit.snapshot.wechat.isEmpty {
                    ContentUnavailableView("profile.contactQR.empty", systemImage: "qrcode")
                        .accessibilityIdentifier("profile.contactQR.empty")
                } else if removes {
                    Label("profile.contactQR.staged", systemImage: "qrcode")
                        .accessibilityIdentifier("profile.contactQR.staged")
                    Button("profile.contactQR.restore") { removes = false }
                        .accessibilityIdentifier("profile.contactQR.restore")
                } else {
                    NativeMediaGalleryEntry(sources: [edit.snapshot.wechat], scope: edit.id,
                        titleKey: "profile.contactQR.title", reader: reader)
                    Button("profile.contactQR.remove", role: .destructive) { removes = true }
                        .accessibilityIdentifier("profile.contactQR.remove")
                }
            } footer: { Text("profile.contactQR.hint") }
            // A3-01: a new code is added from 上传二维码 on the profile page, next to this entry.
        }
        .appNavigationTitle("profile.contactQR.title").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel", role: .cancel, action: cancel)
                    .accessibilityIdentifier("profile.contactQR.cancel")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("profile.fieldEdit.apply") { confirm(removes) }
                    .accessibilityIdentifier("profile.contactQR.apply")
            }
        }
    }
}
