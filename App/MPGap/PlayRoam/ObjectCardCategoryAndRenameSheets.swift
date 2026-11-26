import SwiftUI

/// `OCARDS-3` / `OCARDS-4`: Object card category sheet (system list rows) and sheet-based rename
/// (64-char limit + inline error). Mounted from `ObjectCardsView` (filter) and `ObjectCardRenameButton` (rename).
/// Native structure: system inline title, one cancellation item (owner native-iOS rule).
public struct ObjectCardCategorySheetView: View {
    public let categories: [ObjectCardCategoryOption]
    public let selectedID: String?
    public var onSelect: (String) -> Void
    public var onClose: () -> Void
    /// MP `catIcon[item.key]` (subpackageP3/images/cat/*.png). Nil falls back to the option's SF symbol.
    var icon: ((String) -> Image?)? = nil
    /// Tile accessibility identifier (the host keeps its existing `objects.category.<key>` ids for UI tests).
    var tileIdentifier: (String) -> String = { "objects.categorySheet.\($0.isEmpty ? "all" : $0)" }

    public init(
        categories: [ObjectCardCategoryOption],
        selectedID: String?,
        onSelect: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.categories = categories
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.onClose = onClose
    }

    init(categories: [ObjectCardCategoryOption], selectedID: String?, icon: @escaping (String) -> Image?,
         tileIdentifier: @escaping (String) -> String, onSelect: @escaping (String) -> Void, onClose: @escaping () -> Void) {
        self.init(categories: categories, selectedID: selectedID, onSelect: onSelect, onClose: onClose)
        self.icon = icon
        self.tileIdentifier = tileIdentifier
    }

    public var body: some View {
        NavigationStack {
            // OCARDS-3b: system rows (MP category icon + name + checkmark) instead of the custom tile grid.
            List(categories) { category in
                let isSelected = category.id == selectedID
                Button {
                    onSelect(category.id)
                    onClose()
                } label: {
                    HStack {
                        Label {
                            Text(verbatim: category.title)
                        } icon: {
                            if let image = icon?(category.id) {
                                image.resizable().scaledToFit()
                            } else {
                                Image(systemName: category.systemImage)
                            }
                        }
                        Spacer()
                        if isSelected { Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true) }
                    }
                }
                .foregroundStyle(.primary)
                // MP aria-label / aria-selected.
                .accessibilityLabel(Text(verbatim: category.title))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                .accessibilityIdentifier(tileIdentifier(category.id))
            }
            .navigationTitle(Text("objects.category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) { Label("action.close", systemImage: "xmark") }.labelStyle(.iconOnly)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

public struct ObjectCardRenameSheetView: View {
    @State private var name: String
    public let errorMessage: String?
    public let isSaving: Bool
    public var onSave: (String) -> Void
    public var onClose: () -> Void

    public init(
        initialName: String,
        errorMessage: String? = nil,
        isSaving: Bool = false,
        onSave: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self._name = State(initialValue: ObjectCardRenameValidator.clamped(initialName))
        self.errorMessage = errorMessage
        self.isSaving = isSaving
        self.onSave = onSave
        self.onClose = onClose
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    // MP cy-field (label 卡名, maxlength 64, show-count); catalog keys 卡片名称 / 输入藏品名称.
                    TextField("objects.rename.placeholder", text: $name)
                        .submitLabel(.done)
                        .onSubmit { if canSave { onSave(trimmed) } }
                        .onChange(of: name) { _, newValue in
                            let clamped = ObjectCardRenameValidator.clamped(newValue)
                            if clamped != newValue { name = clamped }
                        }
                        .accessibilityIdentifier("objects.rename.field")
                } header: {
                    Text("playerGap.card.renamePlaceholder")
                } footer: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(verbatim: errorMessage)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.dangerText)
                                .accessibilityIdentifier("objects.rename.error")
                        }
                        Text(verbatim: "\(name.count)/\(ObjectCardRenameValidator.maxLength)")
                            .cyText(.meta, monospacedDigit: true)
                            .foregroundStyle(CYColor.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .navigationTitle(Text("playerGap.card.rename"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: onClose) { Label("action.close", systemImage: "xmark") }.labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("common.save") { onSave(trimmed) }
                            .disabled(!canSave)
                            .accessibilityIdentifier("objects.rename.save")
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled(isSaving)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !isSaving && ObjectCardRenameValidator.isValid(name) }
}
