import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Separate read-purpose approval; never a public-profile, media or write permission.
@MainActor @Observable public final class ProfileGuideReadAccess {
    public let context: RuntimeDependencyContext
    public let endpoints: OperationEndpointApproval
    public let revision = UUID()
    public private(set) var isRevoked = false
    public init(context: RuntimeDependencyContext, approval: OperationEndpointApproval) throws {
        try ProfileFavoritesRequestContract.validate(context, approval, paths: ProfileGuideReadRoute.paths)
        self.context = context; endpoints = approval
    }
    public func revoke() { isRevoked = true }
    public func matches(_ current: RuntimeDependencyContext) -> Bool {
        !isRevoked && ContentDraftContextFence.matches(context, current)
    }
}
public enum ProfileGuideReadRoute: Equatable {
    case list
    case detail(Int)
    public static let listPath = "api/common/infomation_list"
    public static let detailPath = "api/common/infomation_detail"
    public static let paths: Set<String> = [listPath, detailPath]
    public var path: String { switch self { case .list: return Self.listPath; case .detail: return Self.detailPath } }
    public init?(request: URLRequest, baseURL: URL) {
        if request.url?.absoluteString.utf8.elementsEqual(baseURL.appendingPathComponent(Self.listPath).absoluteString.utf8) == true,
           request.httpMethod == "POST", request.httpBody == nil, request.httpBodyStream == nil,
           request.value(forHTTPHeaderField: "Content-Type") == nil,
           request.value(forHTTPHeaderField: "Accept") == "application/json" { self = .list; return }
        guard let (_, fields) = ProfileFavoritesRequestContract.fields(request, baseURL: baseURL, paths: [Self.detailPath]),
              Set(fields.keys) == ["id"], let id = ProfileFavoritesRequestContract.positive(fields["id"]) else { return nil }
        self = .detail(id)
    }
    public func validateResponse(_ response: (Data, Int)) throws {
        guard try ProfileFavoritesRequestContract.isSuccess(response) else { return }
        do {
            switch self {
            case .list:
                struct Envelope: Decodable { let data: [SocialInformation] }
                let rows = try JSONDecoder().decode(Envelope.self, from: response.0).data
                guard rows.allSatisfy({ $0.id > 0 }), Set(rows.map(\.id)).count == rows.count else { throw APIError.malformedResponse }
            case .detail(let expected):
                struct Envelope: Decodable {
                    let data: SocialValue
                    enum CodingKeys: String, CodingKey { case data }
                    init(from decoder: Decoder) throws {
                        let c = try decoder.container(keyedBy: CodingKeys.self)
                        // c6 AjaxResult success(null) omits data for an absent detail row.
                        data = c.contains(.data) ? try c.decode(SocialValue.self, forKey: .data) : .null
                    }
                }
                let data = try JSONDecoder().decode(Envelope.self, from: response.0).data
                if data.isNull || data.object?.isEmpty == true { return }
                struct Member: Decodable { let id: Int }
                struct Strict: Decodable { let data: Member }
                guard try JSONDecoder().decode(Strict.self, from: response.0).data.id == expected else { throw APIError.malformedResponse }
            }
        } catch { throw APIError.malformedResponse }
    }
}

/// Captured public source row plus current list receipt. This cannot grant a route by itself.
@MainActor @Observable public final class ProfileGuideArticleSelection {
    public let id = UUID()
    public let row: SocialInformation
    public let context: RuntimeDependencyContext
    public let viewerRevision: UInt64
    private let current: () -> Bool
    public private(set) var isRetired = false
    init(row: SocialInformation, context: RuntimeDependencyContext, viewerRevision: UInt64, current: @escaping () -> Bool) {
        self.row = row; self.context = context; self.viewerRevision = viewerRevision; self.current = current
    }
    public var isCurrent: Bool {
        guard !isRetired else { return false }
        guard current() else { isRetired = true; return false }
        return true
    }
    public func retire() { isRetired = true }
}

/// Document total for the play-guide list. A missing, null, boolean, fractional,
/// negative, or non-numeric total is unknown. Unknown is an em dash, never 0,
/// and never the number of decoded rows.
public enum PlayGuideDocumentCount: Equatable {
    case unknown
    case value(Int)

    public static let unknownMark = "\u{2014}"

    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }

    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownMark
        case .value(let number): return String(number)
        }
    }

    static func parse(json: Any?) -> PlayGuideDocumentCount {
        guard let number = json as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
              number.doubleValue.isFinite, number.doubleValue == Double(number.intValue),
              number.intValue >= 0 else { return .unknown }
        return .value(number.intValue)
    }
}

/// Projection of the existing bodyless list read (`ProfileGuideReadRoute.listPath`).
/// A closed guide grant stays hidden. This type does not send a request or promote the route.
public struct PlayGuideInformationListPage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error
        case unknown
        case ready([SocialInformation])
    }

    public static let listPath = ProfileGuideReadRoute.listPath
    public static let routeMarkedLive = false
    public static let unknownMark = PlayGuideDocumentCount.unknownMark

    public let capabilityPresent: Bool
    public let phase: Phase?
    public let documentCount: PlayGuideDocumentCount

    public var isHidden: Bool { phase == nil }
    public var documentCountText: String { documentCount.displayText }

    public static var hidden: PlayGuideInformationListPage {
        .init(capabilityPresent: false, phase: nil, documentCount: .unknown)
    }

    public static var loading: PlayGuideInformationListPage {
        .init(capabilityPresent: true, phase: .loading, documentCount: .unknown)
    }

    public static func project(capabilityPresent: Bool, body: Data?, status: Int?) -> PlayGuideInformationListPage {
        guard capabilityPresent else { return .hidden }
        guard let body, let status else { return PlayGuideInformationListPage.loading }
        guard (200..<300).contains(status),
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              PlayGuideDocumentCount.parse(json: object["code"]).literal == 200 else {
            return .init(capabilityPresent: true, phase: .error, documentCount: .unknown)
        }
        guard let data = object["data"] else {
            return .init(capabilityPresent: true, phase: .unknown, documentCount: .unknown)
        }
        if data is NSNull { return .init(capabilityPresent: true, phase: .unknown, documentCount: .unknown) }
        if (data as? String) == "UNKNOWN" {
            return .init(capabilityPresent: true, phase: .unknown, documentCount: .unknown)
        }
        guard let rawRows = data as? [Any] else {
            return .init(capabilityPresent: true, phase: .error, documentCount: .unknown)
        }
        let rows: [SocialInformation]
        do {
            rows = try JSONDecoder().decode([SocialInformation].self, from: JSONSerialization.data(withJSONObject: rawRows))
        } catch {
            return .init(capabilityPresent: true, phase: .error, documentCount: .unknown)
        }
        let usable = rows.filter(\.isUsable)
        guard Set(usable.map(\.id)).count == usable.count else {
            return .init(capabilityPresent: true, phase: .error, documentCount: .unknown)
        }
        let count = PlayGuideDocumentCount.parse(json: object["total"])
        if usable.isEmpty {
            return .init(capabilityPresent: true, phase: .empty, documentCount: count)
        }
        return .init(capabilityPresent: true, phase: .ready(usable), documentCount: count)
    }
}

/// Applies an already-produced list receipt. Detail and unknown routes are not adopted.
public struct PlayGuideInformationListCoordinator: Equatable {
    public let capabilityPresent: Bool
    public private(set) var page: PlayGuideInformationListPage

    public init(capabilityPresent: Bool) {
        self.capabilityPresent = capabilityPresent
        page = capabilityPresent ? PlayGuideInformationListPage.loading : PlayGuideInformationListPage.hidden
    }

    public mutating func apply(route: ProfileGuideReadRoute?, body: Data?, status: Int?) {
        guard capabilityPresent else { page = .hidden; return }
        guard route == .list else { return }
        page = .project(capabilityPresent: true, body: body, status: status)
    }

    public static func == (lhs: PlayGuideInformationListCoordinator, rhs: PlayGuideInformationListCoordinator) -> Bool {
        lhs.capabilityPresent == rhs.capabilityPresent && lhs.page == rhs.page
    }
}
