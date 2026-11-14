import SwiftUI

/// Explicit visual/validation state for `CYField` (Part 4: `idle`, `filled`, `focused`, `error`, `help`, `success`, `disabled`).
public enum CYFieldState: Equatable, Sendable {
    case idle
    case filled
    case focused
    case error(String)
    case help(String)
    case success
    case disabled
}

/// Domain-aware single-line or multiline input field implementing DESIGN.md Part 4 input specs.
/// Supports automatic state detection from text/focus/error/help AND explicit `forcedState` previews.
public struct CYField: View {
    private let label: String
    private let placeholder: String
    @Binding private var text: String
    private let isRequired: Bool
    private let maxLength: Int?
    private let multiline: Bool
    private let helperText: String?
    private let errorText: String?
    private let isSuccess: Bool
    private let isDisabled: Bool
    private let forcedState: CYFieldState?

    @FocusState private var isFocused: Bool
    @Environment(\.cyPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    public init(
        label: String,
        placeholder: String = "",
        text: Binding<String>,
        isRequired: Bool = false,
        maxLength: Int? = nil,
        multiline: Bool = false,
        helperText: String? = nil,
        errorText: String? = nil,
        isSuccess: Bool = false,
        isDisabled: Bool = false,
        forcedState: CYFieldState? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.isRequired = isRequired
        self.maxLength = maxLength
        self.multiline = multiline
        self.helperText = helperText
        self.errorText = errorText
        self.isSuccess = isSuccess
        self.isDisabled = isDisabled
        self.forcedState = forcedState
    }

    private var resolvedState: CYFieldState {
        if let forcedState { return forcedState }
        if isDisabled { return .disabled }
        if let errorText, !errorText.isEmpty { return .error(errorText) }
        if isFocused { return .focused }
        if isSuccess { return .success }
        if !text.isEmpty { return .filled }
        if let helperText, !helperText.isEmpty { return .help(helperText) }
        return .idle
    }

    private var boxBackground: Color {
        switch resolvedState {
        case .disabled:
            return palette.inputDisabledBg
        case .filled, .focused, .success:
            return palette.inputFilledBg
        case .idle, .help, .error:
            return text.isEmpty ? palette.inputIdleBg : palette.inputFilledBg
        }
    }

    private var borderStroke: (color: Color, width: CGFloat) {
        switch resolvedState {
        case .error:
            return (palette.danger, 1)
        case .focused:
            return (palette.textPrimary, 2)
        case .filled:
            return colorScheme == .light ? (palette.textPrimary, 1) : (.clear, 0)
        case .idle, .help, .success, .disabled:
            return colorScheme == .light ? (palette.borderSubtle, 1) : (.clear, 0)
        }
    }

    private var footerMessage: (text: String, isError: Bool)? {
        switch resolvedState {
        case .error(let msg):
            return (msg, true)
        case .help(let msg):
            return (msg, false)
        default:
            if let errorText, !errorText.isEmpty { return (errorText, true) }
            if let helperText, !helperText.isEmpty { return (helperText, false) }
            return nil
        }
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
        VStack(alignment: .leading, spacing: CYSpacing.s1_5) {
            headerRow
            inputContainer(shape: shape)
            if let footer = footerMessage {
                HStack(spacing: CYSpacing.xs) {
                    if footer.isError {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(CYTypography.micro.weight(.semibold))
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: footer.text)
                        .font(CYTypography.micro)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(footer.isError ? palette.danger : palette.textTertiary)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var headerRow: some View {
        HStack(spacing: CYSpacing.xs) {
            HStack(spacing: CYSpacing.xxs) {
                Text(verbatim: label)
                    .font(CYTypography.caption.weight(.medium))
                    .foregroundStyle(palette.textSecondary)
                if isRequired {
                    Text(verbatim: "*")
                        .font(CYTypography.caption.weight(.bold))
                        .foregroundStyle(palette.danger)
                        .accessibilityHidden(true)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            if let maxLength {
                Text(verbatim: "\(text.count)/\(maxLength)")
                    .font(CYTypography.micro.monospacedDigit())
                    .foregroundStyle(text.count > maxLength ? palette.danger : palette.textTertiary)
            }
        }
    }

    @ViewBuilder
    private func inputContainer(shape: RoundedRectangle) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: CYSpacing.sm) {
            if multiline {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text(verbatim: placeholder)
                            .font(CYTypography.body)
                            .foregroundStyle(palette.textPlaceholder)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: boundedBinding)
                        .font(CYTypography.body)
                        .foregroundStyle(resolvedState == .disabled ? palette.textDisabled : palette.textPrimary)
                        .scrollContentBackground(.hidden)
                        .focused($isFocused)
                        .disabled(resolvedState == .disabled)
                        .frame(minHeight: 84)
                }
            } else {
                TextField(
                    "",
                    text: boundedBinding,
                    prompt: Text(verbatim: placeholder).foregroundStyle(palette.textPlaceholder)
                )
                .font(CYTypography.body)
                .foregroundStyle(resolvedState == .disabled ? palette.textDisabled : palette.textPrimary)
                .focused($isFocused)
                .disabled(resolvedState == .disabled)
            }

            if resolvedState == .success {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(palette.success)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, CYSpacing.md)
        .padding(.vertical, multiline ? CYSpacing.sm : CYSpacing.s2_5)
        .frame(minHeight: multiline ? 100 : CYSpacing.minTouchTarget)
        .background(shape.fill(boxBackground))
        .overlay {
            if borderStroke.width > 0 {
                shape.strokeBorder(borderStroke.color, lineWidth: borderStroke.width)
            }
        }
        .onTapGesture {
            if resolvedState != .disabled { isFocused = true }
        }
    }

    private var boundedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { next in
                if let maxLength, next.count > maxLength {
                    text = String(next.prefix(maxLength))
                } else {
                    text = next
                }
            }
        )
    }
}
