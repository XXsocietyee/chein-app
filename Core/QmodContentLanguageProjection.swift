import Foundation

/// Approved text for exactly the original authority's visible branch step.
/// No next-step IDs, outcomes, correct answers, routes or executable configuration are admitted.
public struct QmodContentLanguageProjection: Equatable {
    public let defaultLocale: String
    public let stepID: String
    public let variants: [String: PlayWireValue]
    public var locales: [String] { variants.keys.sorted() }

    init(_ projection: PlayWireValue, branch: PlayWireValue, playKitBranch: PlayWireValue) throws {
        guard let root = projection.object,
              Set(root.keys) == ["schema", "defaultLocale", "stepId", "variants"],
              root["schema"]?.text == "qmod-current-content-locales-v1",
              let defaultLocale = root["defaultLocale"]?.text,
              let step = root["stepId"]?.text, !step.isEmpty, step.utf8.count <= 128,
              let variants = root["variants"]?.object, Set(variants.keys) == ["en", "zh-Hans"],
              variants[defaultLocale] != nil else { throw PlayExperienceError.malformed }
        for variant in variants.values { try Self.validate(variant, stepID: step) }
        self.defaultLocale = defaultLocale; stepID = step; self.variants = variants
        try validateVisible(branch)
        // The existing inline/screen selector prefers playKit.branch when supplied.
        // Both representations must identify exactly the same current content.
        if playKitBranch != .null { try validateVisible(playKitBranch) }
    }

    private static func validate(_ step: PlayWireValue, stepID: String) throws {
        guard let fields = step.object, Set(fields.keys) == ["id", "title", "body", "options"],
              step["id"].text == stepID,
              let title = step["title"].text, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, title.utf16.count <= 80,
              let body = step["body"].text, body.utf16.count <= 1000,
              !title.contains("{{"), !body.contains("{{"),
              let options = step["options"].array, options.count <= 8 else { throw PlayExperienceError.malformed }
        var seen = Set<String>()
        for option in options {
            guard let value = option.object, Set(value.keys) == ["id", "label"],
                  let id = option["id"].text, !id.isEmpty, id.utf8.count <= 128, seen.insert(id).inserted,
                  let label = option["label"].text, !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  label.utf16.count <= 80, !label.contains("{{") else { throw PlayExperienceError.malformed }
        }
    }

    private func validateVisible(_ segment: PlayWireValue) throws {
        let step = segment["currentStep"]
        guard step["id"].text == stepID, segment["currentStepId"] == .null || segment["currentStepId"].text == stepID,
              step["terminal"].bool != nil, let options = step["options"].array,
              let original = variants[defaultLocale],
              step["title"] == original["title"], step["body"] == original["body"],
              options == original["options"].array else { throw PlayExperienceError.malformed }
        let ids = options.map { $0["id"] }
        guard variants.values.allSatisfy({ $0["options"].array?.map { $0["id"] } == ids }) else { throw PlayExperienceError.malformed }
    }

    /// Replaces text only. All original visibility, terminal and writable state stays untouched.
    public func display(segment: PlayWireValue, locale: String) throws -> PlayWireValue {
        try validateVisible(segment)
        guard let variant = variants[locale], var result = segment.object,
              var current = segment["currentStep"].object else { throw PlayExperienceError.malformed }
        current["title"] = variant["title"]; current["body"] = variant["body"]; current["options"] = variant["options"]
        result["currentStep"] = .object(current)
        return .object(result)
    }
}
