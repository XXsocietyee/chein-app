import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

extension PhoneCountryCode {
    /// US launch r1: the picker default on every phone entry. The device region (`Locale.current.region`) wins
    /// when it is US or CN; any other region falls back to the storefront market of this build.
    static var launchDefault: PhoneCountryCode {
        .default(region: Locale.current.region?.identifier, marketCode: RegionalLaunchConfiguration.storefrontMarket?.rawValue)
    }
}

/// US launch r1: +86 / +1 phone entry for forms that keep the server string in their draft (activity
/// registration, profile participants). `wire` carries the server value: China the bare digits it always
/// sent, the US E.164 `+1XXXXXXXXXX`. The field shows the US number grouped as `(555) 123-4567`.
struct PhoneCountryField<Field: Hashable>: View {
    private let titleKey: LocalizedStringKey
    @Binding private var wire: String
    private let prompt: Text?
    private let identifier: String
    private let focus: FocusState<Field?>.Binding
    private let focusValue: Field
    @State private var country: PhoneCountryCode
    @State private var text: String

    init(_ titleKey: LocalizedStringKey, wire: Binding<String>, prompt: Text? = nil, identifier: String,
         focus: FocusState<Field?>.Binding, equals focusValue: Field) {
        self.titleKey = titleKey
        _wire = wire
        self.prompt = prompt
        self.identifier = identifier
        self.focus = focus
        self.focusValue = focusValue
        let stored = PhoneCountryCode.split(wire: wire.wrappedValue)
        let start = wire.wrappedValue.isEmpty ? PhoneCountryCode.launchDefault : stored.country
        _country = State(initialValue: start)
        // A stored China value is shown as it came (a masked value is never rebuilt); the US is grouped.
        _text = State(initialValue: start == .china ? stored.national : start.fieldText(stored.national))
    }

    var body: some View {
        HStack(spacing: 8) {
            countryMenu
            TextField(titleKey, text: $text, prompt: prompt)
                .monospacedDigit()
                .keyboardType(.phonePad).textContentType(.telephoneNumber)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused(focus, equals: focusValue)
                .accessibilityIdentifier(identifier)
        }
        .onChange(of: text) { _, value in
            let formatted = country.fieldText(value)
            if formatted != value { text = formatted }
            publish(formatted)
        }
        .onChange(of: country) { _, picked in
            let formatted = picked.fieldText(text)
            if formatted != text { text = formatted }
            publish(formatted)
        }
        .onChange(of: wire) { _, value in
            // A saved participant picked elsewhere replaces the draft; mirror it without echoing back.
            guard value != country.draftWire(text) else { return }
            let stored = PhoneCountryCode.split(wire: value)
            if !value.isEmpty { country = stored.country }
            text = stored.country == .china ? stored.national : stored.country.fieldText(stored.national)
        }
    }

    private func publish(_ formatted: String) {
        let next = country.draftWire(formatted)
        if next != wire { wire = next }
    }

    /// Same chip as the sign-in form: dial code only, country names in the menu rows.
    private var countryMenu: some View {
        Menu {
            Picker(selection: $country) {
                ForEach(PhoneCountryCode.allCases) { option in
                    (Text(LocalizedStringKey(option.nameKey)) + Text(verbatim: " " + option.dialCode)).tag(option)
                }
            } label: {
                Text("auth.phone.countryCode")
            }
        } label: {
            HStack(spacing: 2) {
                Text(verbatim: country.dialCode).monospacedDigit()
                Image(systemName: "chevron.up.chevron.down").imageScale(.small).accessibilityHidden(true)
            }
            .foregroundStyle(.secondary)
            .fixedSize()
        }
        .accessibilityLabel(Text("auth.phone.countryCode"))
        .accessibilityValue(Text(LocalizedStringKey(country.nameKey)) + Text(verbatim: " " + country.dialCode))
        .accessibilityIdentifier(identifier + ".countryCode")
    }
}
