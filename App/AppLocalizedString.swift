import Foundation

/// Unlike String(localized:locale:), the resource locale selects the lookup language
/// as well as formatting. Never derive operational region or currency from this value.
func appLocalized(_ key:String.LocalizationValue,locale:Locale)->String {
    String(localized:LocalizedStringResource(key,locale:locale))
}

/// Wraps quoted player text in the reader's quotation marks: corner brackets in Chinese
/// (the mini-program's style), the locale's own marks elsewhere (curly quotes in en_US).
func appQuoted(_ text: String, locale: Locale) -> String {
    if locale.language.languageCode?.identifier == "zh" { return "\u{300C}" + text + "\u{300D}" }
    let open = locale.quotationBeginDelimiter ?? "\u{201C}"
    let close = locale.quotationEndDelimiter ?? "\u{201D}"
    return open + text + close
}

/// Joins a name and its detail for VoiceOver: a full-width comma in Chinese, ", " elsewhere.
func appJoinedPair(_ first: String, _ second: String, locale: Locale) -> String {
    first + (locale.language.languageCode?.identifier == "zh" ? "\u{FF0C}" : ", ") + second
}

import SwiftUI
private struct AppNavigationTitle: ViewModifier {
    let key: String.LocalizationValue
    @Environment(\.locale) private var locale
    func body(content: Content) -> some View {
        content.navigationTitle(appLocalized(key, locale: locale))
    }
}
extension View {
    func appNavigationTitle(_ key: String.LocalizationValue) -> some View {
        modifier(AppNavigationTitle(key: key))
    }
    func appNavigationTitle(key: String) -> some View {
        modifier(AppNavigationTitle(key: String.LocalizationValue(stringLiteral: key)))
    }
}
