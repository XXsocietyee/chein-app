import Foundation

/// Card kinds rendered by `subpackageB/pages/im/chat`. A missing `cardType` on a
/// type-3 message is `generic`. Route and signup cards both carry `topicId`.
public enum IMCardKind: String, Equatable {
    case generic, route, signup, location
}

public struct IMRenderedCard: Equatable {
    public let kind: IMCardKind
    public let title: String?
    public let sub: String?
    public let topicID: String?
    public let name: String?
    public let buttons: [IMCardButton]

    public init(kind: IMCardKind, title: String? = nil, sub: String? = nil, topicID: String? = nil, name: String? = nil, buttons: [IMCardButton] = []) {
        self.kind = kind
        self.title = title
        self.sub = sub
        self.topicID = topicID
        self.name = name
        self.buttons = buttons
    }
}

public struct IMCardButton: Equatable {
    public let text: String?
    public let type: String?
    public let action: String?
    public init(text: String?, type: String?, action: String?) {
        self.text = text
        self.type = type
        self.action = action
    }
}

/// `system-card-target.js`. Dataset URLs are not authority. Only the shapes below open a page.
/// The coupon wallet is recognized and refused: L5 does not open a money surface.
public enum IMSystemCardTarget {
    public static let unavailableRoute = "路线已不可用"
    public static let routePrefix = "[路线]"

    public enum Open: Equatable {
        case activity(Int)
        case topic(Int)
        case squarePost(Int)
        case blockedCouponWallet
    }

    public struct Action: Equatable {
        public let open: Open?
        public let bcID: Int?
        public init(open: Open?, bcID: Int?) {
            self.open = open
            self.bcID = bcID
        }
    }

    public static func positiveID(_ raw: String?) -> Int? {
        guard let raw, let first = raw.utf8.first, first != 48, raw.utf8.allSatisfy({ (48...57).contains($0) }),
              raw.count <= 16, let value = Int(raw), value > 0, value <= 9_007_199_254_740_991,
              String(value) == raw else { return nil }
        return value
    }

    public static func activityNoticeOpen(senderID: String, messageType: String, extraJSON: String?) -> Open? {
        guard senderID == "0", messageType == "1", let extraJSON, let extra = jsonObject(extraJSON) else { return nil }
        if extra.keys.contains("action") || extra.keys.contains("url") || extra.keys.contains("path") { return nil }
        guard let type = extra["type"] as? String, ["CLUB_CAMPAIGN", "ACTIVITY_CANCELLED"].contains(type),
              let activity = positiveID(string(extra["activityId"])) else { return nil }
        if type == "CLUB_CAMPAIGN" {
            guard positiveID(string(extra["campaignId"])) != nil, positiveID(string(extra["clubId"])) != nil else { return nil }
        }
        return .activity(activity)
    }

    /// `genericActionInfo`. `buttonIndex == nil` reads the card action. A button index reads that button only.
    public static func genericAction(senderID: String, messageType: String, card: [String: Any], buttonIndex: Int? = nil, activityNotice: Open? = nil) -> Action? {
        if buttonIndex == nil, let activityNotice { return Action(open: activityNotice, bcID: nil) }
        guard senderID == "0", messageType == "3", (card["cardType"] as? String) == "generic", !card.keys.contains("result") else { return nil }
        let actionValue: Any?
        if let buttonIndex {
            guard buttonIndex >= 0, let buttons = card["buttons"] as? [[String: Any]], buttonIndex < buttons.count else { return nil }
            actionValue = buttons[buttonIndex]["action"]
        } else {
            actionValue = card["action"]
        }
        let open = openURL(actionValue)
        let bcID = positiveID(string(card["bcId"]))
        if open == nil && !(buttonIndex == nil && bcID != nil) { return nil }
        if case .blockedCouponWallet = open { return Action(open: .blockedCouponWallet, bcID: bcID) }
        return Action(open: open, bcID: bcID)
    }

    /// MP `originalUrl` (查看当前原单, chat index.wxml:133): a system review-result card whose `result.bizType`
    /// names a page with that same `bizId` opens it. Only COMMUNITY_POST and TOPIC; a card `action` must match.
    public static func reviewOriginal(senderID: String, messageType: String, card: [String: Any]) -> Open? {
        guard senderID == "0", messageType == "3" else { return nil }
        if let kind = card["cardType"] as? String, !kind.isEmpty, kind != "generic" { return nil }
        guard let result = card["result"] as? [String: Any], let bizType = result["bizType"] as? String else { return nil }
        if let flag = result["bizId"] as? NSNumber, CFGetTypeID(flag) == CFBooleanGetTypeID() { return nil }
        guard let id = positiveID(string(result["bizId"])) else { return nil }
        let path: String
        switch bizType {
        case "COMMUNITY_POST": path = "/pages/square/detail/index"
        case "TOPIC": path = "/pages/topic/index/index"
        default: return nil
        }
        if card.keys.contains("action"), (card["action"] as? String) != path + "?id=" + String(id) { return nil }
        return bizType == "TOPIC" ? .topic(id) : .squarePost(id)
    }

    public static func openURL(_ action: Any?) -> Open? {
        guard let action = action as? String else { return nil }
        if action == "/subpackageMember/coupon-wallet/index" { return .blockedCouponWallet }
        guard let range = action.range(of: #"^/(pages/activity/detail/index|pages/topic/index/index|pages/square/detail/index)\?id=([1-9]\d*)$"#, options: .regularExpression),
              range == action.startIndex..<action.endIndex else { return nil }
        let idText = String(action.split(separator: "=").last ?? "")
        guard let id = positiveID(idText) else { return nil }
        if action.hasPrefix("/pages/activity/") { return .activity(id) }
        if action.hasPrefix("/pages/topic/") { return .topic(id) }
        return .squarePost(id)
    }

    /// Route-card cache. A route whose content is not the `[路线]` projection is unavailable and is not fetched.
    /// Signup fetches only while its cache slot is still unknown (`nil`). A stored value is terminal.
    public enum RouteCache: Equatable {
        case unknown
        case unavailable
        case named(String, imageURL: String, mileage: Int, locations: Int)
        case fetched
    }

    public static func routeCache(kind: IMCardKind, content: String?, topicID: String?, imageURL: String = "", mileage: Int = 0, locations: Int = 0, cached: RouteCache? = nil) -> (value: RouteCache, fetch: Bool)? {
        guard kind == .route || kind == .signup, let topicID, !topicID.isEmpty else { return nil }
        if kind == .route {
            if content == unavailableRoute { return (.unavailable, false) }
            if let content, content.hasPrefix(routePrefix) {
                var name = String(content.dropFirst(routePrefix.count))
                while let first = name.first, " \t\n\r\u{000b}\u{000c}".contains(first) { name.removeFirst() }
                return (.named(name, imageURL: imageURL, mileage: mileage, locations: locations), false)
            }
            return (.unavailable, false)
        }
        if cached == nil { return (.unknown, true) }
        return nil
    }

    private static func jsonObject(_ raw: String) -> [String: Any]? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object
    }

    private static func string(_ value: Any?) -> String? {
        switch value {
        case let text as String: return text
        case let number as Int: return String(number)
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }
}

/// `decorate`: type 3 JSON becomes a card; a missing card type is generic.
public enum IMCardDecode {
    public static func card(messageType: Int, content: String?, extraJSON: String?, activityNotice: Bool) -> IMRenderedCard? {
        if activityNotice {
            let lines = CommunityDisplayText.decode(content ?? "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            let title = lines.first.flatMap { $0.isEmpty ? nil : $0 } ?? "活动通知"
            return IMRenderedCard(kind: .generic, title: title, sub: lines.dropFirst().joined(separator: "\n"))
        }
        guard messageType == 3 else { return nil }
        let object = (extraJSON.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) } as? [String: Any]) ?? [:]
        let kind = IMCardKind(rawValue: object["cardType"] as? String ?? "") ?? .generic
        var title = object["title"] as? String
        if kind == .generic, title == nil || title?.isEmpty == true {
            let decoded = CommunityDisplayText.decode(content ?? "")
            title = decoded.isEmpty ? "通知" : decoded
        }
        let buttons = (object["buttons"] as? [[String: Any]] ?? []).map {
            IMCardButton(text: $0["text"] as? String, type: $0["type"] as? String, action: $0["action"] as? String)
        }
        return IMRenderedCard(
            kind: kind,
            title: title,
            sub: object["sub"] as? String,
            topicID: IMSystemCardTarget.stringish(object["topicId"]),
            name: object["name"] as? String,
            buttons: buttons
        )
    }
}

extension IMSystemCardTarget {
    static func stringish(_ value: Any?) -> String? {
        switch value {
        case let text as String: return text
        case let number as Int: return String(number)
        case let number as NSNumber: return number.stringValue
        default: return nil
        }
    }
}

/// List `loadConversations`. The floating pill is only a silent refresh of a list that is already loaded
/// for the same reader. The first load does not show it. A failed silent refresh keeps the rows.
public enum IMRefreshPill {
    public static let text = "正在刷新消息"
    public static let retainedFailure = "没刷新成功，显示的是之前的消息"

    public enum Phase: Equatable {
        case firstLoad
        case pill
        case ready
        case retainedFailure
        case fullFailure(message: String, loginRequired: Bool)
        case deniedCleared(message: String, loginRequired: Bool)
    }

    public static func begin(silent: Bool, loaded: Bool, identityChanged: Bool) -> Phase {
        silent && loaded && !identityChanged ? .pill : .firstLoad
    }

    public static func succeed() -> Phase { .ready }

    public static func fail(preserveConfirmed: Bool, denied: Bool, message: String, loginRequired: Bool) -> Phase {
        if denied { return .deniedCleared(message: message, loginRequired: loginRequired) }
        if preserveConfirmed { return .retainedFailure }
        return .fullFailure(message: message, loginRequired: loginRequired)
    }

    public static func showsPill(_ phase: Phase) -> Bool {
        if case .pill = phase { return true }
        return false
    }
}

/// `subpackageB/pages/im/list/report-notices.js`.
/// `GET /api/v1/community/notifications`, keep the newest `REPORT_*` row per report.
public struct IMReportNotice: Equatable {
    public let key: String
    public let notificationID: String
    public let reportID: String
    public let title: String
    public let createTime: String
    public let unread: Bool

    public init(key: String, notificationID: String, reportID: String, title: String, createTime: String, unread: Bool) {
        self.key = key
        self.notificationID = notificationID
        self.reportID = reportID
        self.title = title
        self.createTime = createTime
        self.unread = unread
    }
}

public enum IMReportNotices {
    public static let fallbackTitle = "举报进度有更新"
    public static let readPathPrefix = "api/v1/community/notifications/"

    /// Non-array input is an unusable payload (`nil`), not an empty list.
    public static func rows(_ items: [IMReportNoticeItem]?) -> [IMReportNotice]? {
        guard let items else { return nil }
        var seen = Set<String>()
        var result: [IMReportNotice] = []
        for item in items {
            guard item.notificationType.trimmingCharacters(in: .whitespacesAndNewlines) == "SYSTEM_GOVERNANCE" else { continue }
            guard let payload = item.payload, payload.action.range(of: #"^REPORT_"#, options: .regularExpression) != nil,
                  let report = IMSystemCardTarget.positiveID(payload.reportID), !seen.contains(String(report)) else { continue }
            seen.insert(String(report))
            let note = payload.publicNote.trimmingCharacters(in: .whitespacesAndNewlines)
            let notification = IMSystemCardTarget.positiveID(item.id).map(String.init) ?? ""
            result.append(IMReportNotice(
                key: item.id.isEmpty ? String(report) : item.id,
                notificationID: notification,
                reportID: String(report),
                title: note.isEmpty ? fallbackTitle : note,
                createTime: item.createTime,
                unread: item.readAt == nil || item.readAt?.isEmpty == true
            ))
        }
        return result
    }

    /// System-tab entry: a failed read still shows the entry. An empty success hides it.
    public static func entry(rows: [IMReportNotice]?, failed: Bool) -> (visible: Bool, unread: Int) {
        if failed || rows == nil { return (true, 0) }
        let unread = rows?.filter(\.unread).count ?? 0
        return (!(rows?.isEmpty ?? true), unread)
    }

    public static func readRequestID(notificationID: String, now: Int, random: String) -> String {
        let id = IMSystemCardTarget.positiveID(notificationID) ?? 0
        let stamp = now > 0 ? now : 0
        let noise = random.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = noise.isEmpty ? "0" : noise
        return String("ntr-\(id)-\(Self.base36(stamp))-\(suffix)".prefix(96))
    }

    public static func readPath(notificationID: String) -> String? {
        guard let id = IMSystemCardTarget.positiveID(notificationID) else { return nil }
        return "\(readPathPrefix)\(id)/read"
    }

    static func base36(_ value: Int) -> String {
        let digits = Array("0123456789abcdefghijklmnopqrstuvwxyz")
        if value <= 0 { return "0" }
        var n = value
        var out = ""
        while n > 0 {
            out.append(digits[n % 36])
            n /= 36
        }
        return String(out.reversed())
    }
}

public struct IMReportNoticeItem: Equatable {
    public struct Payload: Equatable {
        public let reportID: String
        public let action: String
        public let publicNote: String
        public init(reportID: String, action: String, publicNote: String) {
            self.reportID = reportID
            self.action = action
            self.publicNote = publicNote
        }
    }

    public let id: String
    public let notificationType: String
    public let payload: Payload?
    public let createTime: String
    public let readAt: String?

    public init(id: String, notificationType: String, payload: Payload?, createTime: String, readAt: String?) {
        self.id = id
        self.notificationType = notificationType
        self.payload = payload
        self.createTime = createTime
        self.readAt = readAt
    }
}

/// `utils/display-text.js`. Only the named entities and the five numeric code points.
public enum CommunityDisplayText {
    public static func decode(_ value: String) -> String {
        guard value.contains("&") else { return value }
        let pattern = #"&(?:(lt|gt|amp|quot|#39)|#0*(60|62|38|34|39)|#x0*(3c|3e|26|22|27));"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return value }
        let ns = value as NSString
        var result = ""
        var cursor = 0
        for match in regex.matches(in: value, range: NSRange(location: 0, length: ns.length)) {
            if match.range.location > cursor {
                result += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            }
            let name = match.range(at: 1).location == NSNotFound ? "" : ns.substring(with: match.range(at: 1))
            let dec = match.range(at: 2).location == NSNotFound ? "" : ns.substring(with: match.range(at: 2))
            let hex = match.range(at: 3).location == NSNotFound ? "" : ns.substring(with: match.range(at: 3))
            if !name.isEmpty {
                switch name.lowercased() {
                case "lt": result += "<"
                case "gt": result += ">"
                case "amp": result += "&"
                case "quot": result += "\""
                case "#39": result += "'"
                default: result += ns.substring(with: match.range)
                }
            } else if !dec.isEmpty {
                result += numeric(Int(dec))
            } else if !hex.isEmpty {
                result += numeric(Int(hex, radix: 16))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < ns.length { result += ns.substring(from: cursor) }
        return result
    }

    private static func numeric(_ value: Int?) -> String {
        switch value {
        case 60: return "<"
        case 62: return ">"
        case 38: return "&"
        case 34: return "\""
        case 39: return "'"
        default: return ""
        }
    }
}
