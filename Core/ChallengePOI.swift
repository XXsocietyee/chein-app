import Foundation
import Observation

// MARK: - POI Challenge State Machine & Rules (Ported from pages/play/poi-challenge/index.js)

public enum ChallengePOIState: String, Codable, Equatable, Sendable {
    case loading
    case photo
    case quiz
    case done
    case error
}

public struct ChallengePOIMedal: Codable, Equatable, Sendable {
    public let id: String?
    public let name: String
    public let description: String
    public let iconUrl: String

    public init(id: String? = nil, name: String, description: String = "", iconUrl: String = "") {
        self.id = id
        self.name = name
        self.description = description
        self.iconUrl = iconUrl
    }
}

public struct ChallengePOINode: Codable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let title: String
    public let description: String
    public let latitude: Double?
    public let longitude: Double?
    public let radiusM: Double
    public let photoRequired: Bool
    public let question: String
    public let options: [String]
    public let completed: Bool
    public let medal: ChallengePOIMedal?

    public init(
        id: Int,
        name: String,
        title: String = "",
        description: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        radiusM: Double = 100,
        photoRequired: Bool = false,
        question: String = "",
        options: [String] = [],
        completed: Bool = false,
        medal: ChallengePOIMedal? = nil
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.radiusM = radiusM > 0 ? radiusM : 100
        self.photoRequired = photoRequired
        self.question = question
        self.options = options
        self.completed = completed
        self.medal = medal
    }

    public static func decode(from raw: PlayWireValue, fallbackNodeId: Int) throws -> ChallengePOINode {
        guard raw.object != nil else { throw PlayExperienceError.malformed }
        let id = raw["id"].tolerantInteger ?? raw["nodeId"].tolerantInteger ?? fallbackNodeId
        guard id > 0 else { throw PlayExperienceError.malformed }
        let name = raw["name"].text ?? raw["title"].text ?? W8Text.t("地标 \(id)", "Landmark \(id)")
        let title = raw["title"].text ?? name
        let desc = raw["description"].text ?? raw["desc"].text ?? ""
        let lat = raw["latitude"].double ?? raw["lat"].double
        let lng = raw["longitude"].double ?? raw["lng"].double
        let radius = raw["radiusM"].double ?? raw["radius"].double ?? 100.0
        let photoReq = raw["photoRequired"].bool == true || raw["needPhoto"].bool == true
        let question = raw["question"].text ?? raw["quizQuestion"].text ?? ""
        let options: [String] = (raw["options"].array ?? raw["quizOptions"].array ?? []).compactMap { item in
            item.text ?? item["label"].text ?? item["text"].text
        }
        let completed = raw["completed"].bool == true || raw["done"].bool == true
        let medalRaw = raw["medal"]
        let medal: ChallengePOIMedal?
        if medalRaw.object != nil, let mName = medalRaw["name"].text ?? medalRaw["title"].text, !mName.isEmpty {
            medal = ChallengePOIMedal(
                id: medalRaw["id"].text ?? medalRaw["id"].tolerantInteger.map(String.init),
                name: mName,
                description: medalRaw["description"].text ?? medalRaw["desc"].text ?? "",
                iconUrl: medalRaw["iconUrl"].text ?? medalRaw["imgUrl"].text ?? ""
            )
        } else {
            medal = nil
        }
        return ChallengePOINode(
            id: id,
            name: name,
            title: title,
            description: desc,
            latitude: lat,
            longitude: lng,
            radiusM: radius,
            photoRequired: photoReq,
            question: question,
            options: options,
            completed: completed,
            medal: medal
        )
    }
}

public enum ChallengePOIRules {
    /// Pre-write rejection codes from `pages/play/poi-challenge/index.js` (`PREWRITE_REJECTIONS`).
    public static let prewriteRejectionCodes: Set<Int> = [1001, 1002, 1003, 1004, 1009, 1011, 1013]

    public static func isPrewriteRejection(_ code: Int) -> Bool {
        prewriteRejectionCodes.contains(code)
    }

    /// Haversine distance in meters matching `pages/play/poi-challenge/index.js`.
    public static func haversineDistanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
        let r = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0
        let a = sin(dLat / 2.0) * sin(dLat / 2.0)
            + cos(lat1 * .pi / 180.0) * cos(lat2 * .pi / 180.0) * sin(dLon / 2.0) * sin(dLon / 2.0)
        let c = 2.0 * atan2(a.squareRoot(), max(0.0, 1.0 - a).squareRoot())
        return r * c
    }

    /// Checks whether user location is within `radiusM + 30` meters tolerance.
    public static func checkArrival(
        node: ChallengePOINode,
        userLatitude: Double?,
        userLongitude: Double?
    ) -> (withinRange: Bool, distanceMeters: Int?) {
        guard let nLat = node.latitude, let nLon = node.longitude else {
            return (true, nil)
        }
        guard let uLat = userLatitude, let uLon = userLongitude else {
            return (false, nil)
        }
        let dist = haversineDistanceMeters(lat1: uLat, lon1: uLon, lat2: nLat, lon2: nLon)
        let rounded = Int(dist.rounded())
        let allowed = dist <= (node.radiusM + 30.0)
        return (allowed, rounded)
    }

    public static func initialStep(for node: ChallengePOINode) -> ChallengePOIState {
        if node.completed { return .done }
        if node.photoRequired { return .photo }
        return .quiz
    }
}

@available(macOS 14.0, *)
@MainActor @Observable public final class ChallengePOICoordinator {
    public let nodeId: Int
    public private(set) var state: ChallengePOIState = .loading
    public private(set) var node: ChallengePOINode?
    public private(set) var distanceMeters: Int?
    public private(set) var withinRange: Bool = true
    public var uploadedPhotoUrl: String = ""
    public var selectedOptionIndex: Int?
    public var textAnswer: String = ""
    public private(set) var medal: ChallengePOIMedal?
    public private(set) var alreadyClaimed: Bool = false
    public private(set) var errorMessage: String = ""
    public private(set) var submitting: Bool = false
    public private(set) var unknownSubmission: Bool = false

    public init(nodeId: Int) {
        self.nodeId = nodeId
    }

    public func applyLoadedNode(_ loaded: ChallengePOINode, userLat: Double? = nil, userLon: Double? = nil) {
        self.node = loaded
        self.medal = loaded.medal
        self.alreadyClaimed = loaded.completed
        let arrival = ChallengePOIRules.checkArrival(node: loaded, userLatitude: userLat, userLongitude: userLon)
        self.withinRange = arrival.withinRange
        self.distanceMeters = arrival.distanceMeters
        self.state = ChallengePOIRules.initialStep(for: loaded)
        self.errorMessage = ""
        self.unknownSubmission = false
    }

    public func applyLoadError(_ message: String) {
        self.state = .error
        self.errorMessage = message.isEmpty ? W8Text.t("加载挑战失败，请重试", "Could not load the challenge. Please retry.") : message
    }

    public func confirmPhotoUploaded(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = W8Text.t("请先上传现场照片", "Upload an on-site photo first")
            return
        }
        uploadedPhotoUrl = trimmed
        errorMessage = ""
        if let node, !node.question.isEmpty || !node.options.isEmpty {
            state = .quiz
        }
    }

    public func buildCompletionPayload(userLat: Double?, userLon: Double?) throws -> [String: PlayWireValue] {
        guard let node else {
            throw PlayExperienceError.invalidAction
        }
        guard !unknownSubmission else {
            throw NSError(domain: "ChallengePOI", code: 10, userInfo: [NSLocalizedDescriptionKey: W8Text.t("上次提交结果待核对，请先刷新节点状态", "The last submission is awaiting confirmation. Refresh the station status first.")])
        }
        if node.latitude != nil && node.longitude != nil {
            let arrival = ChallengePOIRules.checkArrival(node: node, userLatitude: userLat, userLongitude: userLon)
            withinRange = arrival.withinRange
            distanceMeters = arrival.distanceMeters
            guard arrival.withinRange else {
                let distStr = arrival.distanceMeters.map { W8Text.t("（当前距离约 \($0)m）", " (currently about \($0)m away)") } ?? ""
                throw NSError(domain: "ChallengePOI", code: 1, userInfo: [NSLocalizedDescriptionKey: W8Text.t("距离地标过远，请走近后再试\(distStr)", "You are too far from the landmark. Move closer and try again\(distStr)")])
            }
        }
        if node.photoRequired && uploadedPhotoUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw NSError(domain: "ChallengePOI", code: 2, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请先完成拍照打卡", "Complete the photo check-in first")])
        }
        var answer = textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        if !node.options.isEmpty {
            guard let idx = selectedOptionIndex, node.options.indices.contains(idx) else {
                throw NSError(domain: "ChallengePOI", code: 3, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请选择一个答案", "Choose an answer")])
            }
            answer = node.options[idx]
        } else if !node.question.isEmpty && answer.isEmpty {
            throw NSError(domain: "ChallengePOI", code: 4, userInfo: [NSLocalizedDescriptionKey: W8Text.t("请填写答案", "Enter an answer")])
        }

        var payload: [String: PlayWireValue] = [
            "nodeId": .int(node.id)
        ]
        if !uploadedPhotoUrl.isEmpty {
            payload["photoUrl"] = .string(uploadedPhotoUrl)
        }
        if !answer.isEmpty {
            payload["answer"] = .string(answer)
        }
        if let selectedOptionIndex {
            payload["optionIndex"] = .int(selectedOptionIndex)
        }
        if let userLat, let userLon {
            payload["latitude"] = .number(userLat)
            payload["longitude"] = .number(userLon)
        }
        return payload
    }

    public func applyCompletionResult(code: Int, data: PlayWireValue, message: String?) {
        if code == 200 {
            let medalRaw = data["medal"].object != nil ? data["medal"] : data
            if let mName = medalRaw["name"].text ?? medalRaw["medalName"].text, !mName.isEmpty {
                medal = ChallengePOIMedal(
                    id: medalRaw["id"].text ?? medalRaw["medalId"].tolerantInteger.map(String.init),
                    name: mName,
                    description: medalRaw["description"].text ?? medalRaw["desc"].text ?? "",
                    iconUrl: medalRaw["iconUrl"].text ?? medalRaw["imgUrl"].text ?? ""
                )
            }
            alreadyClaimed = data["alreadyClaimed"].bool == true
            unknownSubmission = false
            errorMessage = ""
            state = .done
            return
        }
        if ChallengePOIRules.isPrewriteRejection(code) {
            unknownSubmission = false
            errorMessage = message ?? W8Text.t("未通过挑战，请核对后重试", "Challenge not passed. Check and try again.")
            return
        }
        // Ambiguous or network error: lock against blind duplicate submission until node state is refreshed
        unknownSubmission = true
        errorMessage = message ?? W8Text.t("提交结果未确认，请刷新查看是否已完成", "Submission not confirmed. Refresh to see whether it completed.")
    }
}
