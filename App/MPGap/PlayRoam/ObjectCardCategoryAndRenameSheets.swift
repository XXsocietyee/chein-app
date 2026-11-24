import SwiftUI

/// `OCARDS-3` / `OCARDS-4`: Object card 3-column category icon sheet and sheet-based rename
/// (64-char limit + inline error).
public struct ObjectCardCategorySheetView: View {
    public let categories: [ObjectCardCategoryOption]
    public let selectedID: String?
    public var onSelect: (String) -> Void
    public var onClose: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: CYSpacing.sm), count: 3)

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

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("objects.category"), style: .player, onClose: onClose)
            ScrollView {
                LazyVGrid(columns: columns, spacing: CYSpacing.sm) {
                    ForEach(categories) { category in
                        let isSelected = category.id == selectedID
                        Button {
                            onSelect(category.id)
                            onClose()
                        } label: {
                            VStack(spacing: CYSpacing.xs) {
                                // TODO: MPAsset.FeatureIcon.* (subpackageP3/images/cat/*.png)
                                Image(systemName: category.systemImage)
                                    .cyText(.sectionTitle)
                                Text(category.title)
                                    .cyText(.label)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 72)
                            .padding(CYSpacing.xs)
                            .foregroundStyle(isSelected ? CYColor.actionPrimaryFg : CYColor.textPrimary)
                            .background(isSelected ? CYColor.actionPrimaryBg : CYColor.bgSurface)
                            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(CYSpacing.md)
            }
        }
        .presentationDetents([.fraction(0.6)])
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
        VStack(spacing: 0) {
            CYSheetHeader(title: Text("playerGap.card.rename"), style: .player, onClose: onClose)
            Form {
                Section {
                    TextField("objects.rename.placeholder", text: $name)
                        .onChange(of: name) { _, newValue in
                            let clamped = ObjectCardRenameValidator.clamped(newValue)
                            if clamped != newValue { name = clamped }
                        }
                } footer: {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack {
                            Spacer()
                            Text("\(name.count)/\(ObjectCardRenameValidator.maxLength)")
                                .cyText(.meta, monospacedDigit: true)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                        if let errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .cyText(.meta)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button("common.save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(isSaving || !ObjectCardRenameValidator.isValid(name))
                }
            }
        }
        .presentationDetents([.medium])
    }
}
