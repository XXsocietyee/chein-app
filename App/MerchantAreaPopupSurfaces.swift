import SwiftUI

/// Locale-aware copy selector matching the mini-program `zh-Hans` copy and natural English equivalents.
enum MerchantAreaCopy {
    static func text(_ zh: String, _ en: String, _ locale: Locale) -> String {
        locale.language.languageCode?.identifier == "zh" ? zh : en
    }

    static func cancel(_ locale: Locale) -> String { text("取消", "Cancel", locale) }
    static func confirm(_ locale: Locale) -> String { text("确认", "Confirm", locale) }
    static func keepEditing(_ locale: Locale) -> String { text("继续编辑", "Keep editing", locale) }
    static func discard(_ locale: Locale) -> String { text("放弃", "Discard", locale) }
    static func deleteAction(_ locale: Locale) -> String { text("删除", "Delete", locale) }
    static func gotIt(_ locale: Locale) -> String { text("知道了", "OK", locale) }
}

/// Reusable DesignSystem confirmation overlay matching `CYModal` + `palette.overlay`, replacing native `.alert` / `.confirmationDialog`.
struct MerchantModalOverlayModifier: ViewModifier {
    let isPresented: Bool
    let title: String
    let message: String
    let consequences: [CYConfirmConsequence]
    let cancelTitle: String
    let confirmTitle: String
    let lighterAlternativeTitle: String?
    let showCancel: Bool
    let isDestructive: Bool
    let isConfirmLoading: Bool
    let cancelIdentifier: String?
    let confirmIdentifier: String?
    let onCancel: () -> Void
    let onLighterAlternative: (() -> Void)?
    let onConfirm: () -> Void

    func body(content: Content) -> some View {
        content.cyModalOverlay(isPresented: isPresented) {
            CYModal(
                title: title,
                message: message,
                consequences: consequences,
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                lighterAlternativeTitle: lighterAlternativeTitle,
                showCancel: showCancel,
                isDestructive: isDestructive,
                isConfirmLoading: isConfirmLoading,
                confirmIdentifier: confirmIdentifier,
                cancelIdentifier: cancelIdentifier,
                onCancel: onCancel,
                onLighterAlternative: onLighterAlternative,
                onConfirm: onConfirm
            )
        }
    }
}

extension View {
    func cyModalConfirm(
        isPresented: Bool,
        title: String,
        message: String = "",
        consequences: [CYConfirmConsequence] = [],
        cancelTitle: String = "取消",
        confirmTitle: String = "确认",
        lighterAlternativeTitle: String? = nil,
        showCancel: Bool = true,
        isDestructive: Bool = false,
        isConfirmLoading: Bool = false,
        cancelIdentifier: String? = nil,
        confirmIdentifier: String? = nil,
        onCancel: @escaping () -> Void,
        onLighterAlternative: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) -> some View {
        modifier(
            MerchantModalOverlayModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                consequences: consequences,
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                lighterAlternativeTitle: lighterAlternativeTitle,
                showCancel: showCancel,
                isDestructive: isDestructive,
                isConfirmLoading: isConfirmLoading,
                cancelIdentifier: cancelIdentifier,
                confirmIdentifier: confirmIdentifier,
                onCancel: onCancel,
                onLighterAlternative: onLighterAlternative,
                onConfirm: onConfirm
            )
        )
    }

    func cyPromptModalOverlay(
        isPresented: Bool,
        title: String,
        message: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        validationMessage: String? = nil,
        cancelTitle: String = "取消",
        confirmTitle: String = "确认",
        isDestructive: Bool = false,
        isConfirmLoading: Bool = false,
        cancelIdentifier: String? = nil,
        confirmIdentifier: String? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) -> some View {
        cyModalOverlay(isPresented: isPresented) {
            CYPromptModal(
                title: title,
                message: message,
                text: text,
                placeholder: placeholder,
                validationMessage: validationMessage,
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                isDestructive: isDestructive,
                isConfirmLoading: isConfirmLoading,
                cancelIdentifier: cancelIdentifier,
                confirmIdentifier: confirmIdentifier,
                onCancel: onCancel,
                onConfirm: onConfirm
            )
        }
    }
}

extension View {
    /// Binding forms used by the editor restyles; dismissal stays with the caller's onCancel/onConfirm.
    func cyModalConfirm(
        isPresented: Binding<Bool>, title: String, message: String = "", consequences: [CYConfirmConsequence] = [],
        cancelTitle: String = "取消", confirmTitle: String = "确认", lighterAlternativeTitle: String? = nil,
        showCancel: Bool = true, isDestructive: Bool = false, isConfirmLoading: Bool = false,
        cancelIdentifier: String? = nil, confirmIdentifier: String? = nil,
        onCancel: @escaping () -> Void, onLighterAlternative: (() -> Void)? = nil, onConfirm: @escaping () -> Void
    ) -> some View {
        cyModalConfirm(isPresented: isPresented.wrappedValue, title: title, message: message, consequences: consequences,
                       cancelTitle: cancelTitle, confirmTitle: confirmTitle, lighterAlternativeTitle: lighterAlternativeTitle,
                       showCancel: showCancel, isDestructive: isDestructive, isConfirmLoading: isConfirmLoading,
                       cancelIdentifier: cancelIdentifier, confirmIdentifier: confirmIdentifier,
                       onCancel: onCancel, onLighterAlternative: onLighterAlternative, onConfirm: onConfirm)
    }

    func cyPromptModalOverlay(
        isPresented: Binding<Bool>, title: String, message: String? = nil, text: Binding<String>, placeholder: String = "",
        validationMessage: String? = nil, cancelTitle: String = "取消", confirmTitle: String = "确认",
        isDestructive: Bool = false, isConfirmLoading: Bool = false, cancelIdentifier: String? = nil,
        confirmIdentifier: String? = nil, onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void
    ) -> some View {
        cyPromptModalOverlay(isPresented: isPresented.wrappedValue, title: title, message: message, text: text,
                             placeholder: placeholder, validationMessage: validationMessage, cancelTitle: cancelTitle,
                             confirmTitle: confirmTitle, isDestructive: isDestructive, isConfirmLoading: isConfirmLoading,
                             cancelIdentifier: cancelIdentifier, confirmIdentifier: confirmIdentifier,
                             onCancel: onCancel, onConfirm: onConfirm)
    }
}

/// Option item backed by DesignSystem `CYOptionSheet`, supporting merchant light or player dark domain.
struct MerchantChoiceOption: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let systemImage: String?
    let isDestructive: Bool

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isDestructive: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isDestructive = isDestructive
    }
}

struct MerchantChoiceOptionSheet: View {
    let title: String
    let options: [MerchantChoiceOption]
    let domain: ThemeDomain
    @Binding var selectedID: String?
    let onSelect: (MerchantChoiceOption) -> Void
    let onClose: () -> Void

    init(
        title: String,
        options: [MerchantChoiceOption],
        domain: ThemeDomain = .merchant,
        selectedID: Binding<String?> = .constant(nil),
        onSelect: @escaping (MerchantChoiceOption) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.options = options
        self.domain = domain
        self._selectedID = selectedID
        self.onSelect = onSelect
        self.onClose = onClose
    }

    var body: some View {
        CYOptionSheet(
            title: title,
            items: options.map {
                CYOptionSheetItem(
                    id: $0.id,
                    title: $0.title,
                    subtitle: $0.subtitle,
                    systemImage: $0.systemImage,
                    isDestructive: $0.isDestructive
                )
            },
            selectedID: selectedID,
            onSelect: { id in
                selectedID = id
                if let match = options.first(where: { $0.id == id }) {
                    onSelect(match)
                }
            },
            onClose: onClose
        )
        .cyDomainSheet(detents: [.half, .full])
        .themeDomain(domain)
    }
}

/// Cooperation review score options mirroring `pages/coop/invite-detail` `reviewSheetItems` (`这次合作打几分`).
enum CoopReviewScore: String, CaseIterable, Identifiable {
    case five = "5"
    case four = "4"
    case three = "3"
    case two = "2"
    case one = "1"

    var id: String { rawValue }
    var scoreValue: Int { Int(rawValue) ?? 5 }

    func option(locale: Locale) -> MerchantChoiceOption {
        switch self {
        case .five:
            return MerchantChoiceOption(id: rawValue, title: MerchantAreaCopy.text("5 星 · 很满意", "5 ★ · Very satisfied", locale), systemImage: "star.fill")
        case .four:
            return MerchantChoiceOption(id: rawValue, title: MerchantAreaCopy.text("4 星 · 不错", "4 ★ · Good", locale), systemImage: "star.fill")
        case .three:
            return MerchantChoiceOption(id: rawValue, title: MerchantAreaCopy.text("3 星 · 一般", "3 ★ · Average", locale), systemImage: "star.leadinghalf.filled")
        case .two:
            return MerchantChoiceOption(id: rawValue, title: MerchantAreaCopy.text("2 星 · 有问题", "2 ★ · Had issues", locale), systemImage: "star")
        case .one:
            return MerchantChoiceOption(id: rawValue, title: MerchantAreaCopy.text("1 星 · 很差", "1 ★ · Poor", locale), systemImage: "star.slash", isDestructive: true)
        }
    }
}
