import Foundation

/// One read of the original install receipt. requestID is the caller's receipt or recover id.
/// purchasedVersionId is WorkshopInstallIdentity.releaseId. Missing deploy approval blocks only ModInstallationComposition.make.
public struct H5OriginalInstallReader: WorkshopOriginalInstallReading, @unchecked Sendable {
    private let service: ModInstallationService

    public init(service: ModInstallationService) {
        self.service = service
    }

    public func request(_ requestID: String, identity: WorkshopInstallIdentity) async throws -> WorkshopOriginalInstallFact {
        guard WorkshopOriginalInstallConsumer.canonicalRequestID(requestID) != nil else {
            throw WorkshopOriginalInstallError.invalidRequest
        }
        let reference = ModInstallationIdentity(
            licenseId: identity.licenseId,
            moduleId: identity.moduleId,
            releaseId: identity.releaseId,
            contentHash: identity.contentHash,
            termsHash: identity.termsHash)
        let receipt = try await service.request(requestID, identity: reference)
        guard receipt.requestId == requestID,
              receipt.licenseId == identity.licenseId,
              receipt.moduleId == identity.moduleId,
              receipt.releaseId == identity.releaseId,
              receipt.contentHash == identity.contentHash,
              receipt.termsHash == identity.termsHash,
              let fact = WorkshopOriginalInstallFact(requestID: receipt.requestId, state: receipt.state.rawValue) else {
            throw WorkshopOriginalInstallError.unknown
        }
        return fact
    }
}
