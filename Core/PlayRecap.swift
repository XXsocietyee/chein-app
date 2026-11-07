import Foundation

// MARK: - Player Route Recap (Ported from pages/play/recap.js)

public struct PlayRecapNodeInput: Equatable, Sendable {
    public let nodeId: Int?
    public let done: Bool
    public let picUrl: String?
    public let imgUrl: String?

    public init(nodeId: Int?, done: Bool, picUrl: String? = nil, imgUrl: String? = nil) {
        self.nodeId = nodeId
        self.done = done
        self.picUrl = picUrl
        self.imgUrl = imgUrl
    }
}

public struct PlayRecapPhoto: Equatable, Identifiable, Sendable {
    public var id: String { "\(nodeId ?? 0):\(picUrl)" }
    public let nodeId: Int?
    public let picUrl: String

    public init(nodeId: Int?, picUrl: String) {
        self.nodeId = nodeId
        self.picUrl = picUrl
    }
}

public struct PlayRecapSummary: Equatable, Sendable {
    public let photos: [PlayRecapPhoto]
    public let canReplayJournal: Bool

    public init(photos: [PlayRecapPhoto], canReplayJournal: Bool) {
        self.photos = photos
        self.canReplayJournal = canReplayJournal
    }
}

public enum PlayRecapRules {
    /// Exact port of `buildPlayRecap(nodes)` in `pages/play/recap.js`.
    /// Only uses the player's own uploaded `picUrl` on `done == true` nodes (up to 12), never `imgUrl` cover images.
    public static func buildPlayRecap(_ nodes: [PlayRecapNodeInput]) -> PlayRecapSummary {
        let completed = nodes.filter(\.done)
        var photos: [PlayRecapPhoto] = []
        for node in completed {
            guard photos.count < 12 else { break }
            let picUrl = (node.picUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !picUrl.isEmpty {
                photos.append(PlayRecapPhoto(nodeId: node.nodeId, picUrl: picUrl))
            }
        }
        return PlayRecapSummary(photos: photos, canReplayJournal: !completed.isEmpty)
    }

    public static func buildPlayRecap(rawNodes: [PlayWireValue]) -> PlayRecapSummary {
        buildPlayRecap(rawNodes.map { node in
            PlayRecapNodeInput(
                nodeId: node["nodeId"].tolerantInteger ?? node["id"].tolerantInteger,
                done: node["done"].bool == true,
                picUrl: node["picUrl"].text,
                imgUrl: node["imgUrl"].text
            )
        })
    }

    public static func buildPlayRecap(playNodes: [PlayNode], picUrlsByNodeId: [Int: String] = [:]) -> PlayRecapSummary {
        buildPlayRecap(playNodes.map { node in
            PlayRecapNodeInput(
                nodeId: node.id,
                done: node.done == true,
                picUrl: picUrlsByNodeId[node.id],
                imgUrl: node.questionImage
            )
        })
    }
}
