import SwiftUI

@MainActor struct MerchantNPCFieldEntry: View {
    @ObservedObject var document: MerchantOperationsViewModel
    @ObservedObject var presentation: MerchantNPCFieldPresentation
    let field: MerchantNPCTextField
    @Environment(\.scenePhase) private var scenePhase
    private var editable: Bool { MerchantNPCFieldSession.canOpen(document, field: field) }
    var body: some View {
        let permit = presentation.generation
        Button {
            guard scenePhase == .active else { return }
            presentation.open(permit: permit, document: document, field: field)
        } label: {
            HStack(alignment: .top) {
                Text(LocalizedStringKey(field.titleKey)); Spacer()
                if editable, let draft = document.coordinator.draft, let value = field.value(in: draft) {
                    if value.isEmpty { Text("merchant.npcField.empty").foregroundStyle(.secondary) }
                    else { Text(verbatim: value).lineLimit(2).foregroundStyle(.secondary) }
                }
                Image(systemName: "chevron.forward").accessibilityHidden(true)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!editable || !presentation.active)
            .accessibilityIdentifier("merchant.npcField.open." + field.rawValue)
    }
}

/// Owned by the stable editor, never by a virtualized Form row.
@MainActor struct MerchantNPCFieldStablePresentation: ViewModifier {
    @ObservedObject var document: MerchantOperationsViewModel
    @ObservedObject var presentation: MerchantNPCFieldPresentation
    @Environment(\.scenePhase) private var scenePhase
    private var editable: Bool {
        guard let session = presentation.session else { return true }
        return MerchantNPCFieldSession.canOpen(document, field: session.buffer.field)
    }
    func body(content: Content) -> some View {
        content.background {
            Color.clear.frame(width: 0, height: 0)
                .cySheet(item: presentation.presentationBinding()) { selected in
                    Group {
                        MerchantNPCFieldSheet(session: selected) { presentation.close(selected.id) }
                    }
                    .presentationDetents([.large]).presentationDragIndicator(.visible)
                }
                // A newly selected session gets a fresh sheet binding owner, including first open.
                .id(presentation.session?.id)
        }
        .onAppear { if scenePhase == .active { presentation.activate() } }
        .onChange(of: document.revision) { _, _ in if presentation.session?.isCurrent == false { presentation.invalidate() } }
        .onChange(of: document.coordinator.draftIdentity) { _, _ in presentation.invalidate() }
        .onChange(of: document.coordinator.reader.scope) { _, _ in presentation.invalidate() }
        .onChange(of: editable) { _, value in if !value { presentation.invalidate() } }
        .onChange(of: scenePhase) { _, phase in if phase == .active { presentation.activate() } else { presentation.deactivate() } }
        .onDisappear { presentation.deactivate() }
    }
}

@MainActor private struct MerchantNPCFieldSheet: View {
    @ObservedObject var session: MerchantNPCFieldSession
    let close: () -> Void
    @Environment(\.locale) private var locale
    private var text: Binding<String> { .init(get: { session.buffer.value }, set: { _ = session.update($0) }) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("merchant.npcField.boundary").cyText(.bodyCompact).foregroundStyle(.secondary)
                    if session.buffer.field.multiline {
                        TextEditor(text: text).frame(minHeight: 160)
                            .accessibilityLabel(Text(LocalizedStringKey(session.buffer.field.titleKey)))
                            .accessibilityIdentifier("merchant.npcField.input")
                    } else {
                        TextField(LocalizedStringKey(session.buffer.field.titleKey), text: text)
                            .textInputAutocapitalization(.sentences).autocorrectionDisabled()
                            .accessibilityIdentifier("merchant.npcField.input")
                    }
                    Text("\(session.buffer.value.utf16.count) / \(session.buffer.field.limit)")
                        .cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
                    if let key = session.buffer.issueKey { Text(LocalizedStringKey(key)).foregroundStyle(.secondary).accessibilityIdentifier("merchant.npcField.issue") }
                }
                Section {
                    Button("merchant.npcField.apply") { if session.apply() { close() } }
                        .disabled(!session.canApply).accessibilityIdentifier("merchant.npcField.apply")
                }
            }.disabled(!session.isCurrent || session.asksDiscard)
                .appNavigationTitle(key: session.buffer.field.titleKey).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { if session.requestClose() { close() } }.accessibilityIdentifier("merchant.npcField.cancel")
                } }
        }
        .privacySensitive()
        .interactiveDismissDisabled(session.buffer.isDirty || session.asksDiscard)
        .cyModalConfirm(
            isPresented: session.asksDiscard,
            title: appLocalized("merchant.npcField.discardTitle", locale: locale),
            message: appLocalized("merchant.npcField.discardBody", locale: locale),
            cancelTitle: appLocalized("merchant.npcField.keepEditing", locale: locale),
            confirmTitle: appLocalized("merchant.npcField.discard", locale: locale),
            isDestructive: true,
            cancelIdentifier: "merchant.npcField.keepEditing",
            confirmIdentifier: "merchant.npcField.discard",
            onCancel: { session.keepEditing() },
            onConfirm: { if session.discard() { close() } }
        )
        .onDisappear { session.cancel() }
    }
}
