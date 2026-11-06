import Foundation

/// Exact server projections only. Protected original text has its own independently approved route;
/// arbitrary source payloads, client authority fields and unknown executable fields are not accepted.
enum ModInstallationWire {
    static func validate(_ bytes: Data, route: String) throws {
        guard let root = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw ModInstallationIssue.malformed }
        try object(root, required: ["code", "data"], optional: ["msg"])
        guard let value = root["data"] else { throw ModInstallationIssue.malformed }
        if route.contains("/venue") {
            let row = try dictionary(value)
            if route.hasSuffix("/venue") {
                try object(row, required: ["schema","installationRequestId","installationId","topicId","bindingHash","bindings","policyRef","ruleVersion","purpose","legalPermissionIssued","nodes"], optional: ["consentId","event","version","document"])
                try array(row["bindings"], limit: 32).forEach(binding)
                try array(row["nodes"], limit: 256).forEach { try object(dictionary($0), required: ["nodeId","title","slotId"]) }
                if let doc = row["document"] { try venueDocument(doc) }
            } else if route.hasSuffix("/code") { try object(row, required: ["nodeId","ttlMs","code"], optional: ["nodeName","qrcodeUrl"]) }
            else { try object(row, required: ["requestId","event","installationId","status","executionPermit"], optional: ["consentId","version","reason"]) }
        } else if route.hasSuffix("/installed-text") {
            try object(dictionary(value), required: ["schema", "scope", "requestId", "licenseId", "moduleId", "releaseId", "contentHash", "termsHash",
                "draftId", "editKind", "bindingHash", "createdAt", "checkedAt", "sourceTextJson", "sourceTextHash", "installedTextJson", "installedTextHash",
                "termsVersion", "useDuration", "updatePolicy", "redistribution", "commercialUse", "allowedRegions", "installationLimit", "published", "executable"])
        } else if route.hasSuffix("/compatibility") {
            try object(dictionary(value), required: ["schema", "licenseId", "moduleId", "releaseId", "contentHash", "termsHash", "clientVersion", "runtimeVersion", "minimumClientVersion", "compatible", "reasonCode", "scope"])
        } else if route.contains("/template-editor") {
            let row = try dictionary(value)
            if route.hasSuffix("/template-editor"), row["schema"] as? String == "mod-installation-template-editor-v1" {
                try object(row, required: ["schema", "installationRequestId", "licenseId", "templateId", "bindingHash", "draftContentHash", "fields", "snapshotJson", "editable", "factsConfirmed"], optional: ["validationMethod", "advancedConfigJson", "draftStatus", "status", "publishStatus", "checkStatus", "auditTaskId", "auditStatus"])
            } else {
                try object(row, required: ["schema", "installationRequestId", "editRequestId", "action", "templateId", "previousDraftHash", "resultDraftHash", "snapshotJson"], optional: ["auditTaskId"])
            }
        } else if route.contains("/qa-editor") {
            let row = try dictionary(value)
            if route.hasSuffix("/qa-editor"), row["schema"] as? String == "mod-installation-qa-editor-v1" {
                try object(row, required: ["schema", "installationRequestId", "licenseId", "topicId", "bindingHash", "draftContentHash", "locale", "nodes"])
                try array(row["nodes"], limit: 49).forEach { try object(dictionary($0), required: ["sourceNodeId", "nodeId", "templateId", "title", "advancedConfigJson"]) }
            } else {
                try object(row, required: ["schema", "installationRequestId", "editRequestId", "sourceNodeId", "topicId", "templateId", "previousDraftHash", "resultDraftHash", "advancedConfigJson"])
            }
        } else if route.hasSuffix("/options-page") {
            let row = try dictionary(value)
            try object(row, required: ["schema", "licenseId", "moduleId", "releaseId", "contentHash", "termsHash", "title", "requiredBindings", "kind", "items"], optional: ["merchantId", "afterId", "nextAfterId"])
            try array(row["requiredBindings"], limit: 32).forEach { try object(dictionary($0), required: ["key", "kind"]) }
            try array(row["items"], limit: 50).forEach(resource)
        } else if route.hasSuffix("/history-page") {
            let row = try dictionary(value)
            try object(row, required: ["schema", "licenseId", "moduleId", "releaseId", "contentHash", "termsHash", "items"], optional: ["beforeRequestId", "nextBeforeRequestId"])
            try array(row["items"], limit: 50).forEach(receipt)
        } else if route.hasSuffix("/options") {
            let row = try dictionary(value)
            try object(row, required: ["schema", "licenseId", "moduleId", "releaseId", "contentHash", "termsHash", "title", "requiredBindings", "merchants", "resources"])
            try array(row["requiredBindings"], limit: 32).forEach { try object(dictionary($0), required: ["key", "kind"]) }
            try array(row["merchants"], limit: 100).forEach(resource)
            try array(row["resources"], limit: 1000).forEach(resource)
        } else if route.hasSuffix("/history") {
            try array(value, limit: 100).forEach(receipt)
        } else if route.hasSuffix("/preview") {
            let row = try dictionary(value)
            try object(row, required: ["schema", "requestId", "licenseId", "bindingHash", "fields"])
            _ = try dictionary(row["fields"] as Any)
        } else if route.hasSuffix("/facts") {
            let row = try dictionary(value)
            try object(row, required: ["schema", "requestId", "licenseId", "draftId", "merchantId", "bindingHash", "draftContentHash", "title", "rules", "confirmed", "bindings"], optional: ["advancedConfigJson"])
            try array(row["bindings"], limit: 32).forEach(binding)
        } else { try receipt(value) }
    }
    private static func venueDocument(_ value: Any) throws {
        let row = try dictionary(value); try object(row, required: ["schema","installationRequestId","bindingHash","purpose","ruleVersion","proofValidityMillis","places"])
        for value in try array(row["places"], limit: 32) {
            let place = try dictionary(value); try object(place, required: ["slotId","poiId","fingerprint","consentEvidenceRef","safetyReviewRef","operatingWindows"])
            try array(place["operatingWindows"], limit: 366).forEach { try object(dictionary($0), required: ["from","until"]) }
        }
    }
    private static func receipt(_ value: Any) throws {
        let row = try dictionary(value)
        try object(row, required: ["schema", "requestId", "licenseId", "moduleId", "releaseId", "contentHash", "termsHash", "state", "merchantId", "anchorPoiId", "region", "bindingHash", "editKind", "createdAt", "published", "executable", "requiredGates", "bindings"], optional: ["draftId", "errorCode", "composition"])
        try array(row["bindings"], limit: 32).forEach(binding)
        if let value = row["composition"], !(value is NSNull) {
            let c = try dictionary(value);try object(c, required: ["schema","lockHash","compilerVersion","compiledHash","parts"])
            try array(c["parts"], limit: 64).forEach {try object(dictionary($0),required: ["packageId","packageVersion","compilerVersion","compiledHash","grantHash","licenseId","requestId","moduleId","releaseId","contentHash","termsHash"])}
        }
        _ = try array(row["requiredGates"], limit: 3)
    }
    private static func binding(_ value: Any) throws {
        try object(dictionary(value), required: ["key", "kind", "resourceId", "label", "fingerprint"])
    }
    private static func resource(_ value: Any) throws {
        try object(dictionary(value), required: ["kind", "id", "merchantId", "label", "fingerprint"], optional: ["region"])
    }
    private static func dictionary(_ value: Any) throws -> [String: Any] {
        guard let result = value as? [String: Any] else { throw ModInstallationIssue.malformed }; return result
    }
    private static func array(_ value: Any?, limit: Int) throws -> [Any] {
        guard let result = value as? [Any], result.count <= limit else { throw ModInstallationIssue.malformed }; return result
    }
    private static func object(_ value: [String: Any], required: Set<String>, optional: Set<String> = []) throws {
        let actual = Set(value.keys)
        guard required.isSubset(of: actual), actual.isSubset(of: required.union(optional)) else { throw ModInstallationIssue.malformed }
    }
}
