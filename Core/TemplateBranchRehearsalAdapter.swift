import Foundation

/// Shared admission into the existing local branch interpreter. No defaults are
/// merged, no fields are stripped, and no runtime/evidence callback is introduced.
public enum TemplateBranchRehearsalAdapter {
    public static func exactDraft(json: String) throws -> TemplateAdvancedDraft {
        _ = try ModInstallationNativeGraph(json: json)
        let value = try JSONDecoder().decode([String: TemplateAuthoringJSON].self, from: Data(json.utf8))
        var exact = TemplateAdvancedDraft(); exact.value = value
        guard exact.creatorIssues(.branch).isEmpty else { throw ModInstallationIssue.malformed }
        return exact
    }
}
