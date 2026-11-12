import Foundation

extension Locale {
    /// Inline zh-Hans / en copy for views that still carry their own literals.
    func pick(_ zh: String, _ en: String) -> String {
        AppLanguage.interfaceIsChinese(self) ? zh : en
    }
}
