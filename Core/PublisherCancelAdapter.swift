import Foundation

/// ADAPT-6: literal topic/activity cancel routes (replaces `"api/\(kind.rawValue)/cancel"` interpolation).
/// Backend: `ApiTopicController` `/cancel`, `/cancel_preview`; `ApiActivityController` `/cancel`, `/cancel_preview`.
/// Both are POST, multipart/form-data accepted (plain Spring parameter binding), token auth.
/// Template is refused before any request is built.
enum PublisherCancelRoute: Equatable {
    case topic, activity
    init(_ kind: PublishedResource.Kind) throws {
        switch kind {
        case .topic: self = .topic
        case .activity: self = .activity
        case .template: throw PublisherLifecycleError.forbidden
        }
    }
    var cancelPath: String {
        switch self { case .topic: return "api/topic/cancel"; case .activity: return "api/activity/cancel" }
    }
    var previewPath: String {
        switch self { case .topic: return "api/topic/cancel_preview"; case .activity: return "api/activity/cancel_preview" }
    }
}

/// Decoded `data` of `cancel_preview`. Topic returns `{paidPlayers, cancellationEpoch}`; activity returns `{paidPlayers}` only.
struct PublisherCancelPreviewData: Equatable {
    let paidPlayers: Int
    let cancellationEpoch: Int?
    init(route: PublisherCancelRoute, data: ProjectEditJSON) throws {
        guard let paid = PublisherValue.integer(data.object?["paidPlayers"]), paid >= 0 else { throw PublisherLifecycleError.incomplete }
        paidPlayers = paid
        switch route {
        case .topic:
            guard let epoch = PublisherValue.integer(data.object?["cancellationEpoch"]), epoch >= 0 else { throw PublisherLifecycleError.incomplete }
            cancellationEpoch = epoch
        case .activity:
            cancellationEpoch = nil
        }
    }
}

enum PublisherCancelFields {
    /// Form fields for `/cancel`. `cancellationEpoch` is sent for topic only and must be the value the preview returned
    /// (backend: retries must keep the original value; absent means legacy epoch).
    static func cancel(route: PublisherCancelRoute, id: Int, reason: String, scope: String?, epoch: Int?) throws -> [String: ProjectEditJSON] {
        guard id > 0 else { throw PublisherLifecycleError.incomplete }
        var fields: [String: ProjectEditJSON] = ["id": .string(String(id)), "reason": .string(reason)]
        if route == .topic {
            if let scope, !scope.isEmpty { fields["scope"] = .string(scope) }
            if let epoch { guard epoch >= 0 else { throw PublisherLifecycleError.incomplete }; fields["cancellationEpoch"] = .string(String(epoch)) }
        }
        return fields
    }
}

extension PublisherLifecycleHTTP {
    /// Read-grant-gated preview returning both the count and (topic) the cancellation epoch. Not wired into the coordinator.
    func cancelPreviewData(_ resource: PublishedResource, scope: String? = nil) async throws -> PublisherCancelPreviewData {
        let route = try PublisherCancelRoute(resource.kind)
        var fields: [String: ProjectEditJSON] = ["id": .string(String(resource.value))]
        if let scope, !scope.isEmpty { fields["scope"] = .string(scope) }
        return try PublisherCancelPreviewData(route: route, data: await read(route.previewPath, fields: fields))
    }
}
