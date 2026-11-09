import Foundation

/// How the signed-in account changed inside one process.
/// Logout remembers the last positive id so a later login can tell a return from a switch.
/// Deletion is authorized only for `accountSwitch`. Launch, logout, and the same account never delete.
public enum AccountPersistenceTransition: Equatable, Sendable {
    case logout(rememberedAccountID: Int)
    case firstLogin(accountID: Int)
    case sameAccount(accountID: Int)
    case accountSwitch(from: Int, to: Int)

    public var authorizesDeletion: Bool {
        if case .accountSwitch(let from, let to) = self { return from > 0 && to > 0 && from != to }
        return false
    }

    /// `nil` when neither side is a positive account. A non-positive id is not a switch and not a logout.
    public static func classify(rememberedAccountID: Int?, nextAccountID: Int?) -> AccountPersistenceTransition? {
        let remembered = rememberedAccountID.flatMap { $0 > 0 ? $0 : nil }
        let next = nextAccountID.flatMap { $0 > 0 ? $0 : nil }
        switch (remembered, next) {
        case (nil, nil): return nil
        case (let remembered?, nil): return .logout(rememberedAccountID: remembered)
        case (nil, let next?): return .firstLogin(accountID: next)
        case (let remembered?, let next?):
            return remembered == next ? .sameAccount(accountID: next) : .accountSwitch(from: remembered, to: next)
        }
    }
}

/// Keys the existing play-continuation reader already uses, plus the schema envelope.
public struct PlayContinuationLegacyKeys: Equatable, Sendable {
    public let scopes: String
    public let titles: String
    public let envelope: String
}

/// What one apply or record call changed. Missing keys are not listed as deleted.
public struct AccountPersistenceEffect: Equatable, Sendable {
    public var deletedKeys: [String]
    public var writtenKeys: [String]
    public static let none = AccountPersistenceEffect(deletedKeys: [], writtenKeys: [])
}

/// Account-scoped UserDefaults schema for the play-continuation index and its ledger.
///
/// Play continuation schema 1 is the shipped pair of `.scopes` / `.titles` keys with no envelope.
/// Schema 2 adds `.envelope` and leaves schema 1 keys in place so the current reader is unchanged.
/// The ledger schema is 1 and records that this writer understands play-continuation schema 2.
///
/// Operation journals, the durable play-recovery files, Keychain, and device preferences are not keys of this store.
/// `apply` deletes only when the transition is an account switch, and only the previous account's keys.
/// The incoming account is migrated (recovered) in place. Logout, first login, and the same account do not delete.
public enum AccountScopedPersistence {
    public static let playContinuationSchema = 2
    public static let ledgerSchema = 1
    /// Matches `PlayRecoveryAccountRole` in the app target. An unknown role is not a continuation slot.
    public static let continuationRoles = ["player", "club", "merchant"]

    public static func legacyKeys(namespace: String, accountID: Int, role: String) -> PlayContinuationLegacyKeys? {
        guard !namespace.isEmpty, accountID > 0, continuationRoles.contains(role) else { return nil }
        let prefix = "play.continuation.\(namespace).\(accountID).\(role)"
        return PlayContinuationLegacyKeys(scopes: prefix + ".scopes", titles: prefix + ".titles", envelope: prefix + ".envelope")
    }

    public static func ledgerKey(namespace: String, accountID: Int) -> String? {
        guard !namespace.isEmpty, accountID > 0 else { return nil }
        let identity = "\(namespace.utf8.count):\(namespace):\(accountID)"
        return "questify.persistence.ledger.v1." + Data(identity.utf8).base64EncodedString()
    }

    /// Login, logout, or account switch. Deletion runs only for a real account switch.
    public static func apply(_ transition: AccountPersistenceTransition, namespace: String, defaults: UserDefaults) -> AccountPersistenceEffect {
        guard !namespace.isEmpty else { return .none }
        switch transition {
        case .logout:
            return .none
        case .firstLogin(let accountID), .sameAccount(let accountID):
            guard accountID > 0 else { return .none }
            return migrate(accountID: accountID, namespace: namespace, defaults: defaults)
        case .accountSwitch(let from, let to):
            guard from > 0, to > 0, from != to else {
                guard to > 0 else { return .none }
                return migrate(accountID: to, namespace: namespace, defaults: defaults)
            }
            var effect = wipePreviousAccount(from, namespace: namespace, defaults: defaults)
            let recovered = migrate(accountID: to, namespace: namespace, defaults: defaults)
            effect.deletedKeys.append(contentsOf: recovered.deletedKeys)
            effect.writtenKeys.append(contentsOf: recovered.writtenKeys)
            return effect
        }
    }

    /// The continuation writer just stored schema 1. Refresh schema 2 from those bytes. Never deletes.
    /// A future envelope or a future ledger is left as it was.
    public static func recordContinuation(namespace: String, accountID: Int, role: String, defaults: UserDefaults) -> AccountPersistenceEffect {
        guard let keys = legacyKeys(namespace: namespace, accountID: accountID, role: role) else { return .none }
        if case .future = readLedger(namespace: namespace, accountID: accountID, defaults: defaults) { return .none }
        if case .future = readSlot(namespace: namespace, accountID: accountID, role: role, defaults: defaults) { return .none }
        guard let scopes = storedStrings(keys.scopes, defaults: defaults) else { return .none }
        let titles: [String: String]
        if defaults.object(forKey: keys.titles) == nil {
            titles = [:]
        } else if let decoded = storedStringMap(keys.titles, defaults: defaults) {
            titles = decoded
        } else {
            return .none
        }
        var effect = AccountPersistenceEffect.none
        writeEnvelope(scopes: scopes, titles: titles, namespace: namespace, accountID: accountID, role: role, defaults: defaults, effect: &effect)
        writeLedgerIfCurrent(accountID: accountID, namespace: namespace, defaults: defaults, effect: &effect)
        return effect
    }

    private static func migrate(accountID: Int, namespace: String, defaults: UserDefaults) -> AccountPersistenceEffect {
        if case .future = readLedger(namespace: namespace, accountID: accountID, defaults: defaults) { return .none }
        var effect = AccountPersistenceEffect.none
        for role in continuationRoles {
            if case .legacy(let scopes, let titles) = readSlot(namespace: namespace, accountID: accountID, role: role, defaults: defaults) {
                writeEnvelope(scopes: scopes, titles: titles, namespace: namespace, accountID: accountID, role: role, defaults: defaults, effect: &effect)
            }
        }
        writeLedgerIfCurrent(accountID: accountID, namespace: namespace, defaults: defaults, effect: &effect)
        return effect
    }

    /// Previous account only. A future ledger or a future slot is left untouched.
    private static func wipePreviousAccount(_ accountID: Int, namespace: String, defaults: UserDefaults) -> AccountPersistenceEffect {
        if case .future = readLedger(namespace: namespace, accountID: accountID, defaults: defaults) { return .none }
        var effect = AccountPersistenceEffect.none
        for role in continuationRoles {
            guard let keys = legacyKeys(namespace: namespace, accountID: accountID, role: role) else { continue }
            if case .future = readSlot(namespace: namespace, accountID: accountID, role: role, defaults: defaults) { continue }
            for key in [keys.scopes, keys.titles, keys.envelope] where defaults.object(forKey: key) != nil {
                defaults.removeObject(forKey: key)
                effect.deletedKeys.append(key)
            }
        }
        if let key = ledgerKey(namespace: namespace, accountID: accountID), defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
            effect.deletedKeys.append(key)
        }
        return effect
    }

    private enum Slot {
        case absent
        case legacy(scopes: [String], titles: [String: String])
        case current
        case future
        case corrupt
    }

    private enum Ledger {
        case absent
        case current
        case future
        case corrupt
    }

    private static func readSlot(namespace: String, accountID: Int, role: String, defaults: UserDefaults) -> Slot {
        guard let keys = legacyKeys(namespace: namespace, accountID: accountID, role: role) else { return .absent }
        if let data = defaults.data(forKey: keys.envelope) {
            guard let object = jsonObject(data), let schema = intValue(object["schemaVersion"]) else { return .corrupt }
            if schema > playContinuationSchema { return .future }
            guard schema == playContinuationSchema, stringArray(object["scopes"]) != nil, stringMap(object["titles"]) != nil else { return .corrupt }
            return .current
        }
        if defaults.object(forKey: keys.envelope) != nil { return .corrupt }
        let scopesObject = defaults.object(forKey: keys.scopes)
        let titlesObject = defaults.object(forKey: keys.titles)
        if scopesObject == nil && titlesObject == nil { return .absent }
        guard let scopes = storedStrings(keys.scopes, defaults: defaults) else { return .corrupt }
        if titlesObject == nil { return .legacy(scopes: scopes, titles: [:]) }
        guard let titles = storedStringMap(keys.titles, defaults: defaults) else { return .corrupt }
        return .legacy(scopes: scopes, titles: titles)
    }

    private static func readLedger(namespace: String, accountID: Int, defaults: UserDefaults) -> Ledger {
        guard let key = ledgerKey(namespace: namespace, accountID: accountID) else { return .absent }
        guard let object = defaults.object(forKey: key) else { return .absent }
        guard let data = object as? Data, let json = jsonObject(data), let schema = intValue(json["schemaVersion"]) else { return .corrupt }
        if schema > ledgerSchema { return .future }
        guard schema == ledgerSchema, intValue(json["playContinuation"]) == playContinuationSchema else { return .corrupt }
        return .current
    }

    private static func writeEnvelope(scopes: [String], titles: [String: String], namespace: String, accountID: Int, role: String, defaults: UserDefaults, effect: inout AccountPersistenceEffect) {
        guard let keys = legacyKeys(namespace: namespace, accountID: accountID, role: role),
              let data = jsonData(["schemaVersion": playContinuationSchema, "scopes": scopes, "titles": titles]) else { return }
        if defaults.data(forKey: keys.envelope) == data { return }
        defaults.set(data, forKey: keys.envelope)
        effect.writtenKeys.append(keys.envelope)
    }

    private static func writeLedgerIfCurrent(accountID: Int, namespace: String, defaults: UserDefaults, effect: inout AccountPersistenceEffect) {
        if case .future = readLedger(namespace: namespace, accountID: accountID, defaults: defaults) { return }
        let hasCurrent = continuationRoles.contains { role in
            if case .current = readSlot(namespace: namespace, accountID: accountID, role: role, defaults: defaults) { return true }
            return false
        }
        guard hasCurrent, let key = ledgerKey(namespace: namespace, accountID: accountID),
              let data = jsonData(["playContinuation": playContinuationSchema, "schemaVersion": ledgerSchema]) else { return }
        if defaults.data(forKey: key) == data { return }
        defaults.set(data, forKey: key)
        effect.writtenKeys.append(key)
    }

    private static func jsonObject(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func jsonData(_ object: [String: Any]) -> Data? {
        try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private static func intValue(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        // JSON true/false is an NSNumber too. 0 and 1 must stay integers.
        if CFGetTypeID(number as CFTypeRef) == CFBooleanGetTypeID() { return nil }
        return number.intValue
    }

    private static func stringArray(_ value: Any?) -> [String]? {
        if let values = value as? [String] { return values }
        guard let values = value as? [Any] else { return nil }
        var decoded: [String] = []
        for item in values {
            guard let text = item as? String else { return nil }
            decoded.append(text)
        }
        return decoded
    }

    private static func stringMap(_ value: Any?) -> [String: String]? {
        if let values = value as? [String: String] { return values }
        guard let values = value as? [String: Any] else { return nil }
        var decoded: [String: String] = [:]
        for (key, item) in values {
            guard let text = item as? String else { return nil }
            decoded[key] = text
        }
        return decoded
    }

    private static func storedStrings(_ key: String, defaults: UserDefaults) -> [String]? {
        guard let object = defaults.object(forKey: key) else { return nil }
        return stringArray(object)
    }

    private static func storedStringMap(_ key: String, defaults: UserDefaults) -> [String: String]? {
        guard let object = defaults.object(forKey: key) else { return nil }
        return stringMap(object)
    }
}
