import SwiftUI

/// One icon row inside the consequence box of a `CYConfirmSheet`.
public struct CYConfirmConsequence: Identifiable {
    public let id = UUID()
    public let systemImage: String
    public let text: String
    public init(systemImage: String, text: String) { self.systemImage = systemImage; self.text = text }
}

/// Bottom-sheet confirmation (native r2: system sheet + Form + system buttons). Not a centered alert.
public struct CYConfirmSheet: View {
    private let title: String
    private let message: String
    private let confirmTitle: String
    private let cancelTitle: String?
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void
    private let isDestructive: Bool
    private let confirmDisabled: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let titleIdentifier: String?
    private let consequences: [CYConfirmConsequence]
    /// Join only: the sheet itself plays a stamp seal and lantern burst before it dismisses.
    private let showsJoinReward: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var rewarding = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(title: String, message: String, confirmTitle: String,
                cancelTitle: String? = nil,
                isDestructive: Bool = false, confirmDisabled: Bool = false,
                confirmIdentifier: String? = nil,
                cancelIdentifier: String? = nil, titleIdentifier: String? = nil,
                consequences: [CYConfirmConsequence] = [],
                showsJoinReward: Bool = false,
                onCancel: (() -> Void)? = nil,
                onConfirm: @escaping () -> Void) {
        self.isDestructive = isDestructive
        self.confirmDisabled = confirmDisabled
        self.consequences = consequences
        self.showsJoinReward = showsJoinReward && !isDestructive
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.titleIdentifier = titleIdentifier
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    @ViewBuilder private var confirmButton: some View {
        let label = Button(action: confirm) {
            Text(confirmTitle).frame(maxWidth: .infinity)
        }
        .disabled(confirmDisabled)
        .sensoryFeedback(.success, trigger: rewarding)
        if let confirmIdentifier {
            styled(label).accessibilityIdentifier(confirmIdentifier)
        } else {
            styled(label)
        }
    }

    @ViewBuilder private var cancelButton: some View {
        Button {
            onCancel?()
            dismiss()
        } label: {
            if let cancelTitle {
                Text(cancelTitle).frame(maxWidth: .infinity)
            } else {
                Text("action.cancel").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .pageTemplateControl(label: cancelTitle.map { Text($0) } ?? Text("action.cancel"), traits: .isButton)
        .cyOptionalAccessibilityIdentifier(cancelIdentifier)
    }

    @ViewBuilder private func styled(_ label: some View) -> some View {
        if isDestructive {
            label.buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
                .pageTemplateControl(label: Text(verbatim: confirmTitle), traits: .isButton)
        } else {
            label.buttonStyle(.borderedProminent).controlSize(.large)
                .pageTemplateControl(label: Text(verbatim: confirmTitle), traits: .isButton)
        }
    }

    /// Native r2: a system sheet (`.presentationDetents`, drag indicator, system background). The CYConfirmSheet
    /// API is a view callers present in their own `.sheet`, so it cannot become `.confirmationDialog` here; inside
    /// the sheet everything is system: a `.headline` title, `.body` secondary message, the consequences as `Label`
    /// rows in an inset grouped `Form` section, and system `.borderedProminent` / `.bordered` large buttons.
    /// No glass, burst or seal animation.
    public var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    Text(title)
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .cyOptionalAccessibilityIdentifier(titleIdentifier)
                    if !message.isEmpty {
                        Text(message)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            if !consequences.isEmpty {
                Section {
                    ForEach(consequences) { item in
                        Label {
                            Text(item.text)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: item.systemImage)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("confirm.consequences")
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            Group {
                if consequences.isEmpty {
                    // Visual order is top to bottom: confirm, then cancel.
                    VStack(spacing: CYSpacing.sm) {
                        confirmButton.pageTemplateReadingOrder(2)
                        cancelButton.pageTemplateReadingOrder(1)
                    }
                } else {
                    // Cancel left, confirm right. The stacked fallback keeps confirm above cancel.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: CYSpacing.sm) {
                            cancelButton.pageTemplateReadingOrder(2)
                            confirmButton.pageTemplateReadingOrder(1)
                        }
                        VStack(spacing: CYSpacing.sm) {
                            confirmButton.pageTemplateReadingOrder(2)
                            cancelButton.pageTemplateReadingOrder(1)
                        }
                    }
                }
            }
            .padding()
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
    }

    /// `showsJoinReward` no longer plays a seal/burst (native r2: no decorative motion); the system success haptic
    /// marks the moment and the action runs at once.
    private func confirm() {
        if showsJoinReward { rewarding.toggle() }
        onConfirm()
    }
}

private extension View {
    @ViewBuilder func cyOptionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier { accessibilityIdentifier(identifier) } else { self }
    }
}

#Preview("Confirm") {
    CYConfirmSheet(title: "Preview title", message: "Preview message for this confirmation.", confirmTitle: "Continue", onConfirm: {})
}
