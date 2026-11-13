import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One recipient-preview template, bound to one viewer and one conversation.
/// A lease for conversation A does not authorize a message that belongs to conversation B.
public struct IMPreviewTemplateLease: Equatable {
    public let template: BusinessRuntimeRouteTemplate
    public let viewer: RuntimeDependencyContext
    public let conversationID: Int64
    public let expiresAt: Date

    public init?(template: BusinessRuntimeRouteTemplate, viewer: RuntimeDependencyContext,
                 conversationID: Int64, expiresAt: Date) {
        guard IMPreviewRouteTemplates.all.contains(template), conversationID > 0, viewer.session.accountID > 0 else { return nil }
        self.template = template
        self.viewer = viewer
        self.conversationID = conversationID
        self.expiresAt = expiresAt
    }

    /// A concrete route the exact transport matcher can carry, or nil.
    /// Refusal issues nothing: traversal, encoding, the wrong verb, another template,
    /// another viewer, another conversation, a mismatched message id, and expiry.
    public func issue(method: String, path requestPath: String, messageID: Int64,
                      messageConversationID: Int64, viewer: RuntimeDependencyContext, now: Date) -> BusinessRuntimeRoute? {
        guard now < expiresAt else { return nil }
        guard viewer == self.viewer else { return nil }
        guard messageConversationID == conversationID, messageID > 0 else { return nil }
        guard let identifier = template.match(method: method, path: requestPath), identifier == messageID else { return nil }
        guard let concrete = template.concretePath(for: identifier), concrete == requestPath else { return nil }
        guard let route = try? BusinessRuntimeRoute(method: template.method, path: concrete), template.feature.accepts(route) else { return nil }
        return route
    }
}
