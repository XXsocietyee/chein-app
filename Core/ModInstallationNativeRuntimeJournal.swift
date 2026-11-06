import Foundation
import CryptoKit

/// Optional server proof, not an installation/payment claim supplied by the player.
/// A server session fixes the play instance and config. Editing a draft cannot rebind this proof.
public struct ModInstallationNativeRuntimeProof: Codable, Equatable {
    public let schema, status, kind, sourceHash, runHash: String
    public let sessionId, activityId, topicId, nodeId: Int
    init(state: PlayAdvancedState) throws {
        self = try state.modInstallationRuntime.decoded()
        guard schema == "mod-installation-native-runtime-v1", status == "SUPPORTED",
              ["QA_PICK", "CHOICE"].contains(kind), state.ownerType == 1, !state.isMultiplayer,
              sessionId == state.sessionID, activityId == state.activityID, topicId == state.topicID, nodeId == state.nodeID,
              sessionId > 0, activityId >= 0, topicId > 0, nodeId > 0,
              Self.hash(sourceHash), Self.hash(runHash) else { throw PlayExperienceError.malformed }
    }
    private static func hash(_ text: String) -> Bool { text.count == 64 && text.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
    func validate(_ command: PlayAdvancedPending) throws {
        guard schema == "mod-installation-native-runtime-v1", status == "SUPPORTED", ["QA_PICK", "CHOICE"].contains(kind),
              Self.hash(sourceHash), Self.hash(runHash), sessionId > 0, activityId >= 0, topicId > 0, nodeId > 0,
              command.sessionID == sessionId, command.version >= 0, UUID(uuidString: command.key) != nil,
              (kind == "QA_PICK" ? command.action == "SUBMIT_QA" : command.action == "CHOOSE") else { throw PlayExperienceError.malformed }
        let keys = Set(command.payload.keys)
        let ids: [String]
        if keys == ["optionId"], let id = command.payload["optionId"]?.text { ids = [id] }
        else if kind == "QA_PICK", keys == ["optionIds"], let raw = command.payload["optionIds"]?.array {
            ids = raw.compactMap(\.text)
            guard ids.count == raw.count else { throw PlayExperienceError.malformed }
        } else { throw PlayExperienceError.malformed }
        guard !ids.isEmpty, ids.count <= 4, Set(ids).count == ids.count,
              ids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 128 }) else { throw PlayExperienceError.malformed }
    }
}

/// One outstanding command per installed node, not a second server action ledger.
/// The acknowledged original response remains distinct from a later authoritative state.
public struct ModInstallationNativeRuntimeRecord: Codable, Equatable {
    let version: Int
    let owner: PlayRecoveryOwner
    let realm: String
    let gameplayMode: PlayGameplayMode?
    let proof: ModInstallationNativeRuntimeProof
    let command: PlayAdvancedPending
    var receipt: PlayWireValue?
    var settled: Bool
    init(owner: PlayExperienceSession, realm: String, gameplayMode: PlayGameplayMode? = nil, proof: ModInstallationNativeRuntimeProof, command: PlayAdvancedPending) throws {
        try proof.validate(command)
        version = 1; self.owner = .init(session: owner); self.realm = realm; self.gameplayMode = gameplayMode; self.proof = proof; self.command = command; settled = false
    }
    func validate(owner: PlayExperienceSession, realm: String, activity: Int, topic: Int, node: Int, gameplayMode: PlayGameplayMode?) throws {
        guard self.gameplayMode == gameplayMode, version == 1, self.owner.matches(owner), self.realm.utf8.elementsEqual(realm.utf8),
              proof.activityId == activity, proof.topicId == topic, proof.nodeId == node,
              !settled || receipt != nil else { throw PlayExperienceError.persistenceUnavailable }
        try proof.validate(command)
        if let receipt { try validateResult(PlayAdvancedState(receipt)) }
    }
    func validateResult(_ state: PlayAdvancedState) throws {
        guard try ModInstallationNativeRuntimeProof(state: state) == proof,
              state.version > command.version else { throw PlayExperienceError.malformed }
    }
}

@MainActor public final class ModInstallationNativeRuntimeJournal {
    private let storage: any TemplateAuthoringStorage
    public init(storage: any TemplateAuthoringStorage) { self.storage = storage }
    private func key(_ owner: PlayExperienceSession, _ realm: String, _ activity: Int, _ topic: Int, _ node: Int) -> String {
        // Epoch and credentials are intentionally absent, so the same account can recover after login/restart.
        // Role is verified in the envelope, not used to create another slot around an old lock.
        let identity = "\(owner.namespace.utf8.count):\(owner.namespace):\(owner.accountID):\(realm.utf8.count):\(realm):\(activity):\(topic):\(node)"
        return "mod-installed-native-runtime.v1." + SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    func load(owner: PlayExperienceSession, realm: String, activity: Int, topic: Int, node: Int, gameplayMode: PlayGameplayMode? = nil) throws -> ModInstallationNativeRuntimeRecord? {
        guard let data = try storage.read(key(owner, realm, activity, topic, node)) else { return nil }
        guard data.count <= 524288 else { throw PlayExperienceError.persistenceUnavailable }
        let record = try JSONDecoder().decode(ModInstallationNativeRuntimeRecord.self, from: data)
        try record.validate(owner: owner, realm: realm, activity: activity, topic: topic, node: node, gameplayMode: gameplayMode)
        return record
    }
    func save(_ record: ModInstallationNativeRuntimeRecord, replacing expected: ModInstallationNativeRuntimeRecord?, owner: PlayExperienceSession) throws {
        let p = record.proof
        try record.validate(owner: owner, realm: record.realm, activity: p.activityId, topic: p.topicId, node: p.nodeId, gameplayMode: record.gameplayMode)
        guard try load(owner: owner, realm: record.realm, activity: p.activityId, topic: p.topicId, node: p.nodeId, gameplayMode: record.gameplayMode) == expected else { throw PlayExperienceError.persistenceUnavailable }
        let data = try JSONEncoder().encode(record)
        guard data.count <= 524288 else { throw PlayExperienceError.persistenceUnavailable }
        let slot = key(owner, record.realm, p.activityId, p.topicId, p.nodeId)
        try storage.write(data, key: slot)
        guard try storage.read(slot) == data else { throw PlayExperienceError.persistenceUnavailable }
    }
    /// Display preference only. This separate slot never changes the original command/receipt journal.
    private struct ContentLanguageSelection: Codable {
        let schema: Int
        let owner: PlayRecoveryOwner
        let realm: String
        let proof: ModInstallationNativeRuntimeProof
        let locale: String
    }
    private func contentLanguageKey(owner: PlayExperienceSession, realm: String, proof: ModInstallationNativeRuntimeProof) -> String {
        key(owner, realm, proof.activityId, proof.topicId, proof.nodeId) + ".content-language." + proof.sourceHash + "." + proof.runHash
    }
    func loadContentLanguage(owner: PlayExperienceSession, realm: String, proof: ModInstallationNativeRuntimeProof,
                             locales: Set<String>) throws -> String? {
        guard proof.kind == "CHOICE", locales == ["en", "zh-Hans"] else { throw PlayExperienceError.malformed }
        let slot = contentLanguageKey(owner: owner, realm: realm, proof: proof)
        guard let data = try storage.read(slot) else { return nil }
        guard data.count <= 8192 else { throw PlayExperienceError.persistenceUnavailable }
        let value = try JSONDecoder().decode(ContentLanguageSelection.self, from: data)
        guard value.schema == 1, value.owner.matches(owner), value.realm.utf8.elementsEqual(realm.utf8),
              value.proof == proof, locales.contains(value.locale) else { throw PlayExperienceError.persistenceUnavailable }
        return value.locale
    }
    func saveContentLanguage(_ locale: String, replacing expected: String?, owner: PlayExperienceSession, realm: String,
                             proof: ModInstallationNativeRuntimeProof, locales: Set<String>) throws {
        guard locales.contains(locale), try loadContentLanguage(owner: owner, realm: realm, proof: proof, locales: locales) == expected
        else { throw PlayExperienceError.persistenceUnavailable }
        let value = ContentLanguageSelection(schema: 1, owner: .init(session: owner), realm: realm, proof: proof, locale: locale)
        let data = try JSONEncoder().encode(value)
        guard data.count <= 8192 else { throw PlayExperienceError.persistenceUnavailable }
        try storage.write(data, key: contentLanguageKey(owner: owner, realm: realm, proof: proof))
        guard try loadContentLanguage(owner: owner, realm: realm, proof: proof, locales: locales) == locale
        else { throw PlayExperienceError.persistenceUnavailable }
    }

}
