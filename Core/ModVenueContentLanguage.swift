import Foundation

/// Text for one authorized current venue node only. Never a source graph, evidence or command.
public struct ModVenueContentLanguageProjection: Equatable {
    public struct Text: Equatable { public let title: String; public let body: String }
    public struct Source: Codable, Equatable {
        public let sourceID: Int
        public let sourceInputHash, sourceManifestHash, sourceEnvelopeHash, artifactHash: String
        public let bindingHash, venueMappingHash, originalVenueBindingsHash, contentLocalesHash: String
        var valid: Bool {
            sourceID > 0 && [sourceInputHash, sourceManifestHash, sourceEnvelopeHash, artifactHash,
                bindingHash, venueMappingHash, originalVenueBindingsHash, contentLocalesHash].allSatisfy(QmodSourceSubmissionWire.hashValid)
        }
    }
    public let defaultLocale: String
    public let nodeID, sessionID, expectedEpoch, expectedVersion: Int
    public let runtimeDomain, run: String
    public let source: Source
    public let variants: [String: Text]
    public var locales: [String] { variants.keys.sorted() }

    init(_ raw: PlayWireValue, context: ModVenueRunContext, node: PlayWireValue) throws {
        guard let fields = raw.object,
              Set(fields.keys) == ["schema", "defaultLocale", "nodeId", "runtimeDomain", "sessionId", "run", "expectedEpoch", "expectedVersion",
                "sourceId", "sourceInputHash", "sourceManifestHash", "sourceEnvelopeHash", "artifactHash", "bindingHash",
                "venueMappingHash", "originalVenueBindingsHash", "contentLocalesHash", "variants"],
              raw["schema"].text == "qmod-current-venue-content-locales-v1",
              let locale = raw["defaultLocale"].text,
              let id = raw["nodeId"].integer, id == context.nodeId, id == node["nodeId"].tolerantInteger,
              let session = raw["sessionId"].integer, session == context.sessionId,
              let epoch = raw["expectedEpoch"].integer, epoch == context.expectedEpoch,
              let version = raw["expectedVersion"].integer, version == context.expectedVersion,
              raw["runtimeDomain"].text == context.runtimeDomain, raw["run"].text == context.run,
              let sourceID = raw["sourceId"].integer,
              let inputHash = raw["sourceInputHash"].text, let manifestHash = raw["sourceManifestHash"].text,
              let envelopeHash = raw["sourceEnvelopeHash"].text, let artifactHash = raw["artifactHash"].text,
              let bindingHash = raw["bindingHash"].text, let mappingHash = raw["venueMappingHash"].text,
              let originalBindingsHash = raw["originalVenueBindingsHash"].text, let localesHash = raw["contentLocalesHash"].text,
              let rawVariants = raw["variants"].object, Set(rawVariants.keys) == ["en", "zh-Hans"],
              rawVariants[locale] != nil else { throw PlayExperienceError.malformed }
        let source = Source(sourceID: sourceID, sourceInputHash: inputHash, sourceManifestHash: manifestHash,
            sourceEnvelopeHash: envelopeHash, artifactHash: artifactHash, bindingHash: bindingHash,
            venueMappingHash: mappingHash, originalVenueBindingsHash: originalBindingsHash, contentLocalesHash: localesHash)
        guard source.valid else { throw PlayExperienceError.malformed }
        var texts: [String: Text] = [:]
        for (code, value) in rawVariants {
            guard let fields = value.object, Set(fields.keys) == ["title", "body"],
                  let title = value["title"].text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  title.utf16.count <= 80, let body = value["body"].text, body.utf16.count <= 1000,
                  !title.contains("{{"), !body.contains("{{") else { throw PlayExperienceError.malformed }
            texts[code] = .init(title: title, body: body)
        }
        guard let original = texts[locale], original.title == node["name"].text,
              original.body == (node["storyText"].text ?? node["description"].text) else { throw PlayExperienceError.malformed }
        defaultLocale = locale; nodeID = id; sessionID = session; expectedEpoch = epoch; expectedVersion = version
        runtimeDomain = context.runtimeDomain; run = context.run; self.source = source; variants = texts
    }

    func matches(_ context: ModVenueRunContext) -> Bool {
        nodeID == context.nodeId && sessionID == context.sessionId && expectedEpoch == context.expectedEpoch &&
            expectedVersion == context.expectedVersion && runtimeDomain == context.runtimeDomain && run == context.run
    }
}

/// Preference identity only: no token, translated text, code, command, receipt or authority snapshot.
public struct ModVenueContentLanguageScope: Codable, Equatable {
    public let owner: PlayRecoveryOwner
    public let realm, runtimeDomain, run: String
    public let sessionID, topicID, nodeID, authorityEpoch, consentID: Int
    public let consentVersion, ruleVersion: String
    public let source: ModVenueContentLanguageProjection.Source
    init(owner: PlayRecoveryOwner, realm: String, context: ModVenueRunContext, projection: ModVenueContentLanguageProjection) {
        self.owner = owner; self.realm = realm; runtimeDomain = context.runtimeDomain; run = context.run
        sessionID = context.sessionId; topicID = context.topicId; nodeID = context.nodeId; authorityEpoch = context.expectedEpoch
        consentID = context.consentId; consentVersion = context.consentVersion; ruleVersion = context.ruleVersion; source = projection.source
    }
    var valid: Bool {
        owner.accountID > 0 && !owner.namespace.isEmpty && !owner.role.isEmpty && !realm.isEmpty && realm.utf8.count <= 4096 &&
            ["TOPIC_ROUTE", "GAME_SESSION"].contains(runtimeDomain) && !run.isEmpty && run.utf8.count <= 160 &&
            sessionID > 0 && topicID > 0 && nodeID > 0 && authorityEpoch > 0 && consentID > 0 &&
            QmodSourceSubmissionWire.hashValid(consentVersion) && QmodSourceSubmissionWire.hashValid(ruleVersion) && source.valid
    }
}
public struct ModVenueContentLanguagePreference: Codable, Equatable {
    public let schema: Int
    public let scope: ModVenueContentLanguageScope
    public let locale: String
    init(scope: ModVenueContentLanguageScope, locale: String) throws {
        guard scope.valid, ["en", "zh-Hans"].contains(locale) else { throw PlayExperienceError.persistenceUnavailable }
        schema = 1; self.scope = scope; self.locale = locale
    }
    var valid: Bool { schema == 1 && scope.valid && ["en", "zh-Hans"].contains(locale) }
}
