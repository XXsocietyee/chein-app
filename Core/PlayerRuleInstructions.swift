import Foundation

/// Gap #15 / J-19 (store review, content leak). Port of the mini-program `utils/rule-steps.js` `stripOperatorNotes`:
/// official template seeds append notes meant for operators or merchants, "(运营提示:…)" / "（运营备注：…）", to the
/// rule text. The player surface never shows them. A note without a closing bracket runs to the end of its line.
public enum PlayerRuleText {
    /// Same pattern as the MP `OPERATOR_NOTE` regex (`/\s*[（(]\s*运营(?:提示|备注)\s*[:：](?:[^)）]*[)）]|[^\n]*)/g`).
    static let operatorNote: NSRegularExpression? = try? NSRegularExpression(
        pattern: "\\s*[（(]\\s*运营(?:提示|备注)\\s*[:：](?:[^)）]*[)）]|[^\\n]*)")

    /// The rule text with every operator note removed. Same output as the MP for the same input.
    public static func strippingOperatorNotes(_ text: String) -> String {
        guard let operatorNote else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return operatorNote.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    /// What a player may read. Nil when there is no rule, or when the rule was only an operator note.
    public static func playerVisible(_ text: String?) -> String? {
        guard let text else { return nil }
        let stripped = strippingOperatorNotes(text).trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? nil : stripped
    }
}

extension PlayNode {
    /// The node rule as players see it (operator notes removed). Every player-facing rule render uses this,
    /// never the raw `ruleInstructions`.
    public var playerRuleInstructions: String? { PlayerRuleText.playerVisible(ruleInstructions) }
}

extension PlayRandomDispatchedTask {
    /// The random-dispatch task rule as players see it (operator notes removed).
    public var playerRuleInstructions: String? { PlayerRuleText.playerVisible(ruleInstructions) }
}
