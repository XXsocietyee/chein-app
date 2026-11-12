import Foundation

/// Mini-program `utils/im-send-recovery.js` at hengyin `1c80c5aea`.
/// The ledger stores only the client message id for an in-flight send.
/// It does not store text, images, coordinates, or a reason to send again.
public struct IMSendRecoveryLedger: Equatable {
    public struct Receipt: Equatable {
        public let owner: String
        public let conversation: String
        public let id: String
        public let generation: Int
        public init(owner: String, conversation: String, id: String, generation: Int) {
            self.owner = owner
            self.conversation = conversation
            self.id = id
            self.generation = generation
        }
    }

    private var generation = 0
    private var rows: [String: [String]] = [:]

    public init() {}

    /// Source `epoch`.
    public var epoch: Int { generation }

    public func storedIDs(owner: String, conversation: String) -> [String] {
        rows[storageKey(owner: owner, conversation: conversation)] ?? []
    }

    /// Source `begin`. A failed read-back returns nil and the caller must not send.
    public mutating func begin(owner: String, conversation: String, id: String) -> Receipt? {
        let key = storageKey(owner: owner, conversation: conversation)
        var list = storedIDs(owner: owner, conversation: conversation)
        if !list.contains(id) { list.append(id) }
        rows[key] = list
        guard storedIDs(owner: owner, conversation: conversation).contains(id) else { return nil }
        return Receipt(owner: owner, conversation: conversation, id: id, generation: generation)
    }

    /// Source `current`: same generation and the id is still stored.
    public func current(_ receipt: Receipt) -> Bool {
        receipt.generation == generation && storedIDs(owner: receipt.owner, conversation: receipt.conversation).contains(receipt.id)
    }

    /// Source `complete`. Removes the id only while the receipt is still current.
    public mutating func complete(_ receipt: Receipt) -> Bool {
        guard current(receipt) else { return false }
        let key = storageKey(owner: receipt.owner, conversation: receipt.conversation)
        rows[key] = storedIDs(owner: receipt.owner, conversation: receipt.conversation).filter { $0 != receipt.id }
        return !current(receipt)
    }

    /// Source `pending`. Handles use the generation that is current now.
    public func pending(owner: String, conversation: String) -> [Receipt] {
        storedIDs(owner: owner, conversation: conversation).map {
            Receipt(owner: owner, conversation: conversation, id: $0, generation: generation)
        }
    }

    /// Source `abandon`: drop this conversation and retire every outstanding handle.
    public mutating func abandon(owner: String, conversation: String) -> Bool {
        generation += 1
        rows[storageKey(owner: owner, conversation: conversation)] = nil
        return true
    }

    /// Source `invalidate`. Old handles go stale. Stored ids remain for a later `pending` scan.
    public mutating func invalidate() { generation += 1 }

    private func storageKey(owner: String, conversation: String) -> String {
        "im_send_receipts_v1:\(owner):\(conversation)"
    }
}
