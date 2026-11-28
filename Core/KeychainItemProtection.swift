import Foundation
import Security

/// Shared read check for device-only Keychain items. A hit that is missing the class, or that
/// can sync, is not a credential this process may use.
enum KeychainItemProtection {
    static func isDeviceOnlyUnlocked(_ attributes: [String: Any]) -> Bool {
        (attributes[kSecAttrAccessible as String] as? String) == (kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
            && (attributes[kSecAttrSynchronizable as String] as? NSNumber)?.boolValue == false
    }
}
