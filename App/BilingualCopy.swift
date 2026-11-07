import Foundation

/// Picks the Simplified Chinese or English variant for copy that is composed in code (diagnostic rows,
/// dynamic summaries) instead of looked up in a string catalog. Mirrors the app's inline copy("中文","English") pattern.
func bilingualCopy(_ zh: String, _ en: String, locale: Locale = .current) -> String {
    locale.language.languageCode?.identifier == "zh" ? zh : en
}
