import SwiftUI

@MainActor struct MerchantStoreFieldEntry: View {
    @ObservedObject var document: MerchantOperationsViewModel
    @ObservedObject var presentation: MerchantStoreFieldPresentation
    let field: MerchantStoreTextField
    @Environment(\.scenePhase) private var scenePhase
    private var editable: Bool { MerchantStoreFieldSession.canOpen(document, field: field) }
    var body: some View {
        let permit = presentation.generation
        Button {
            guard scenePhase == .active else { return }
            presentation.open(permit: permit, document: document, field: field)
        } label: {
            HStack(alignment: .top) {
                Text(LocalizedStringKey(field.titleKey)); Spacer()
                if editable, let draft = document.coordinator.draft, let value = field.value(in: draft) {
                    if value.isEmpty { Text("merchant.storeField.empty").foregroundStyle(.secondary) }
                    else { Text(verbatim: value).lineLimit(2).foregroundStyle(.secondary) }
                }
                Image(systemName: "chevron.right").accessibilityHidden(true)
            }.frame(minHeight: 44).contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!editable || !presentation.active)
            .accessibilityIdentifier("merchant.storeField.open." + field.rawValue)
    }
}

/// Owned by the stable editor, never by a virtualized Form row.
@MainActor struct MerchantStoreFieldStablePresentation: ViewModifier {
    @ObservedObject var document: MerchantOperationsViewModel
    @ObservedObject var presentation: MerchantStoreFieldPresentation
    @Environment(\.scenePhase) private var scenePhase
    private var editable: Bool {
        guard let session = presentation.session else { return true }
        return MerchantStoreFieldSession.canOpen(document, field: session.buffer.field)
    }
    func body(content: Content) -> some View {
        content.background {
            Color.clear.frame(width: 0, height: 0)
                .sheet(item: presentation.presentationBinding()) { selected in
                    Group {
                        MerchantStoreFieldSheet(session: selected) { presentation.close(selected.id) }
                    }
                    .presentationDetents([.large]).presentationDragIndicator(.visible)
                }
                // A newly selected session gets a fresh sheet binding owner, including first open.
                .id(presentation.session?.id)
        }
        .onAppear { presentation.viewAppeared(sceneIsActive: scenePhase == .active) }
        .onChange(of: document.revision) { _, _ in if presentation.session?.isCurrent == false { presentation.invalidate() } }
        .onChange(of: document.coordinator.draftIdentity) { _, _ in presentation.invalidate() }
        .onChange(of: document.coordinator.reader.scope) { _, _ in presentation.invalidate() }
        .onChange(of: editable) { _, value in if !value { presentation.invalidate() } }
        .onChange(of: scenePhase) { _, phase in presentation.sceneChanged(isActive: phase == .active) }
        .onDisappear { presentation.viewDisappeared() }
    }
}

@MainActor private struct MerchantStoreFieldSheet: View {
    @ObservedObject var session: MerchantStoreFieldSession
    let close: () -> Void
    @Environment(\.locale) private var locale
    private var text: Binding<String> { .init(get: { session.buffer.value }, set: { _ = session.update($0) }) }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if session.buffer.field == .preference {
                        // MC7-19-2: MP decor 经营类目 is a fixed multi-select list (PREFERENCE_OPTIONS), joined with 、.
                        MerchantPreferenceChoices(value: text)
                    } else if session.buffer.field == .description {
                        TextEditor(text: text).frame(minHeight: 160)
                            .accessibilityLabel(Text(LocalizedStringKey(session.buffer.field.titleKey)))
                            .accessibilityIdentifier("merchant.storeField.input")
                    } else {
                        TextField(LocalizedStringKey(session.buffer.field.titleKey), text: text)
                            .textInputAutocapitalization(.sentences).autocorrectionDisabled()
                            .accessibilityIdentifier("merchant.storeField.input")
                    }
                    Text("\(session.buffer.value.utf16.count) / \(session.buffer.field.limit)")
                        .cyText(.meta).monospacedDigit().foregroundStyle(.secondary)
                    if let key = session.buffer.issueKey { Text(LocalizedStringKey(key)).foregroundStyle(.secondary).accessibilityIdentifier("merchant.storeField.issue") }
                }
                Section {
                    Button("merchant.storeField.apply") { if session.apply() { close() } }
                        .disabled(!session.canApply).accessibilityIdentifier("merchant.storeField.apply")
                }
            }.disabled(!session.isCurrent || session.asksDiscard)
                .appNavigationTitle(key: session.buffer.field.titleKey).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { if session.requestClose() { close() } }.accessibilityIdentifier("merchant.storeField.cancel")
                } }
        }
        .privacySensitive()
        .interactiveDismissDisabled(session.buffer.isDirty || session.asksDiscard)
        .cyModalConfirm(
            isPresented: session.asksDiscard,
            title: appLocalized("merchant.storeField.discardTitle", locale: locale),
            message: appLocalized("merchant.storeField.discardBody", locale: locale),
            cancelTitle: appLocalized("merchant.storeField.keepEditing", locale: locale),
            confirmTitle: appLocalized("merchant.storeField.discard", locale: locale),
            isDestructive: true,
            cancelIdentifier: "merchant.storeField.keepEditing",
            confirmIdentifier: "merchant.storeField.discard",
            onCancel: { session.keepEditing() },
            onConfirm: { if session.discard() { close() } }
        )
        .onDisappear { session.cancel() }
    }
}

/// MP pages/merchant/decor/index.js:42-60 `PREFERENCE_OPTIONS` / `parsePreference`: the fixed 经营类目 list plus any
/// value the store already has, multi-select, written back as one 「、」-joined string (same server field).
enum MerchantPreferenceOptions {
    static let fixed = ["城市运动", "户外活动", "健康生活", "美食", "咖啡", "茶饮", "烘焙甜品", "酒吧小酌",
                        "手作", "亲子", "夜生活", "文化艺术", "展览", "书店阅读", "音乐现场", "剧本密室", "桌游", "电玩",
                        "摄影", "城市漫步", "骑行", "露营", "瑜伽", "球类", "水上运动", "花艺", "美容美发", "宠物友好"]
    private static let separators = CharacterSet(charactersIn: "、,，·/|").union(.whitespacesAndNewlines)
    static func parse(_ value: String) -> [String] {
        var seen: [String] = []
        for part in value.components(separatedBy: separators) {
            let item = part.trimmingCharacters(in: .whitespaces)
            if !item.isEmpty, !seen.contains(item) { seen.append(item) }
        }
        return seen
    }
    static func options(current: [String]) -> [String] { fixed + current.filter { !fixed.contains($0) } }
    static func join(_ picked: [String]) -> String { picked.joined(separator: "、") }
}

@MainActor private struct MerchantPreferenceChoices: View {
    @Binding var value: String
    @State private var options: [String] = []
    private var picked: [String] { MerchantPreferenceOptions.parse(value) }
    var body: some View {
        ForEach(options, id: \.self) { option in
            let isOn = picked.contains(option)
            Button {
                var next = picked
                if isOn { next.removeAll { $0 == option } } else { next.append(option) }
                // Keep the list order, like the MP chip sheet's checked keys.
                value = MerchantPreferenceOptions.join(options.filter { next.contains($0) })
            } label: {
                HStack {
                    Text(verbatim: option).foregroundStyle(CYColor.textPrimary)
                    Spacer()
                    if isOn { Image(systemName: "checkmark").foregroundStyle(CYColor.brand).accessibilityHidden(true) }
                }
                .frame(minHeight: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
            .accessibilityIdentifier("merchant.storeField.preference.\(option)")
        }
        .onAppear { if options.isEmpty { options = MerchantPreferenceOptions.options(current: picked) } }
    }
}
