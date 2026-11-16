import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

extension AppScopedStorageFactory {
    /// Project editor journals (draft, review, release). System Keychain storage, except an explicit DEBUG test-host override.
    @MainActor func projectEditStorage(scope: RegionalSessionStorageScope?) -> any ProjectEditDataStorage {
#if DEBUG
        if let syntheticProjectEditStorage { return syntheticProjectEditStorage }
#endif
        return ProjectEditSecureStorage(scope: scope)
    }
}
