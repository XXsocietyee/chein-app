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

/// Single-line or multiline input field (native r2: the system `TextField`).
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

    public static func resolveState(
        forcedState: CYFieldState?,
        isDisabled: Bool,
        errorText: String?,
        isFocused: Bool,
        isSuccess: Bool,
        text: String,
        helperText: String?
    ) -> CYFieldState {
        if let forcedState { return forcedState }
        if isDisabled { return .disabled }
        if let errorText, !errorText.isEmpty { return .error(errorText) }
        if isFocused { return .focused }
        if isSuccess { return .success }
        if !text.isEmpty { return .filled }
        if let helperText, !helperText.isEmpty { return .help(helperText) }
        return .idle
    }

    static func tokens(
        for state: CYFieldState,
        hasText: Bool,
        colorScheme: ColorScheme,
        in palette: CYDomainPalette
    ) -> (
        background: Color,
        borderColor: Color,
        borderWidth: CGFloat,
        textForeground: Color,
        footerForeground: Color?,
        showsSuccessIcon: Bool
    ) {
        let background: Color
        switch state {
        case .disabled:
            background = palette.inputDisabledBg
        case .filled, .focused, .success:
            background = palette.inputFilledBg
        case .idle, .help, .error:
            background = hasText ? palette.inputFilledBg : palette.inputIdleBg
        }

        let border: (Color, CGFloat)
        switch state {
        case .error:
            border = (palette.danger, 1)
        case .focused:
            border = (palette.textPrimary, 2)
        case .filled:
            border = colorScheme == .light ? (palette.textPrimary, 1) : (.clear, 0)
        case .idle, .help, .success, .disabled:
            border = colorScheme == .light ? (palette.borderSubtle, 1) : (.clear, 0)
        }

        let textForeground = state == .disabled ? palette.textDisabled : palette.textPrimary
        let footerForeground: Color?
        switch state {
        case .error: footerForeground = palette.danger
        case .help: footerForeground = palette.textTertiary
        default: footerForeground = nil
        }

        return (
            background: background,
            borderColor: border.0,
            borderWidth: border.1,
            textForeground: textForeground,
            footerForeground: footerForeground,
            showsSuccessIcon: state == .success
        )
    }

    private var resolvedState: CYFieldState {
        Self.resolveState(
            forcedState: forcedState,
            isDisabled: isDisabled,
            errorText: errorText,
            isFocused: isFocused,
            isSuccess: isSuccess,
            text: text,
            helperText: helperText
        )
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

    /// Native r2: the system text field (`.roundedBorder`; multiline is the vertical-axis `TextField`) with the label
    /// as plain `.subheadline` secondary text above it and validation / help as a `.footnote` below (red for errors).
    /// No box, border, placeholder colour or counter drawn by us. `maxLength` is still enforced.
    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: isRequired ? label + " *" : label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            input
            if let footer = footerMessage {
                Text(verbatim: footer.text)
                    .font(.footnote)
                    .foregroundStyle(footer.isError ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var input: some View {
        if multiline {
            TextField(label, text: boundedBinding, prompt: Text(verbatim: placeholder), axis: .vertical)
                .lineLimit(3...8)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .disabled(resolvedState == .disabled)
        } else {
            TextField(label, text: boundedBinding, prompt: Text(verbatim: placeholder))
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .disabled(resolvedState == .disabled)
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
