import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

extension AppSession {
    /// Owner 11-28 04:30: phone sign-in for both markets. CN keeps its +86 page; the US shows the +1 page only
    /// once the deployment verified `.internationalPhone` (P27: a gated channel renders nothing).
    var supportsPhoneSignIn: Bool {
        supportsDomesticPhoneInput || regionalConfiguration?.canUseInternationalPhone == true
    }
}
