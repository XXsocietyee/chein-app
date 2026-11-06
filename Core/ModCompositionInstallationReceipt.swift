import Foundation

/// Original installer-owned dependent requests, each charged by its original commerce license writer.
public struct ModCompositionInstallationReceipt: Codable, Equatable {
    public struct Part: Codable, Equatable, Identifiable {
        public var id: String { packageId }
        public let packageId, packageVersion, compilerVersion, compiledHash, grantHash, licenseId, requestId, moduleId, releaseId, contentHash, termsHash: String
    }
    public let schema, lockHash, compilerVersion, compiledHash: String
    public let parts: [Part]
    public func validate(parentRequestId: String, parentLicenseId: String) throws {
        guard schema == "mod-composition-original-receipt-v1", ["first-party-h5-retry-topic-1","first-party-h5-policy-topic-2",ModCompositionModuleGraph.adapter].contains(compilerVersion),
              [lockHash, compiledHash].allSatisfy(QmodSourceSubmissionWire.hashValid), !parts.isEmpty, parts.count <= 64,
              Set(parts.map(\.id)).count == parts.count, Set(parts.map(\.requestId)).count == parts.count,
              Set(parts.map(\.licenseId)).count == parts.count else { throw ModInstallationIssue.malformed }
        for p in parts {
            guard p.packageId.range(of: #"\A[a-z][a-z0-9._-]{0,63}\z"#, options: .regularExpression) != nil,
                  p.requestId != parentRequestId, p.licenseId != parentLicenseId, QmodSourceSubmissionWire.uuid(p.requestId),
                  !p.compilerVersion.isEmpty, p.compilerVersion.utf8.count <= 128, ModCompositionDependency(packageId: p.packageId,packageVersion: p.packageVersion,contentHash: p.contentHash).valid,
                  [p.contentHash, p.termsHash, p.compiledHash, p.grantHash].allSatisfy(QmodSourceSubmissionWire.hashValid) else { throw ModInstallationIssue.malformed }
            for key in [p.licenseId, p.moduleId, p.releaseId] { try ModInstallationValidation.key(key) }
        }
    }
}
