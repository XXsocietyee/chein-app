import Foundation

/// D35 §9 original theme-role aliases. These are not editable initial values, platform XP or TEAM balances.
public enum OriginalRpgGrowthFacts {
    public static let keys = ["sys.xp", "sys.level", "sys.skill_points"]
    public static func reserved(_ key: String) -> Bool { keys.contains(key) }
    public static func threshold(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && value.rounded() == value && value >= Double(Int32.min) && value <= Double(Int32.max)
    }
    public static func valid(_ value: PlayWireValue, in receipt: PlayWireValue) -> Bool {
        guard value["source"].text == "ORIGINAL_THEME_ROLE", value["status"].text == "KNOWN",
              ["FIRST_ROLL", "PASSIVE_CHECK", "RETRY_AUTHORIZATION"].contains(value["phase"].text ?? ""),
              let values = value["values"].object, Set(values.keys) == Set(keys),
              keys.allSatisfy({ key in
                  guard let n = value["values"][key].integer else { return false }
                  return n >= (key == "sys.level" ? 1 : 0) && n <= Int(Int32.max)
              }), let actor = value["binding"]["actorKey"].text,
              actor.range(of: "^MEMBER:[1-9][0-9]{0,18}$", options: .regularExpression) != nil,
              let topic = value["binding"]["topicId"].integer, topic > 0,
              let definition = value["binding"]["definitionVersion"].integer, definition > 0,
              let version = value["binding"]["characterVersion"].integer, version >= 0 else { return false }
        let binding = value["binding"]
        if let outer = receipt["topicId"].integer, outer != topic { return false }
        if let outer = receipt["definitionVersion"].integer, outer != definition { return false }
        if binding["runtimeDomain"].text == "GAME_SESSION" {
            guard let game = binding["gameSessionId"].integer, game > 0,
                  let team = binding["teamId"].integer, team > 0,
                  receipt["runtimeDomain"].text == "GAME_SESSION", receipt["gameSessionId"].integer == game,
                  receipt["teamId"].integer == team, let member = receipt["memberId"].integer,
                  actor == "MEMBER:\(member)" else { return false }
        } else {
            let passive = value["phase"].text == "PASSIVE_CHECK" && receipt["runtimeDomain"].text == "PERSONAL_TOPIC_ROUTE"
            let originalRun = passive ? receipt["sessionId"].integer : receipt["runId"].integer
            guard let run = binding["runId"].integer, run > 0, originalRun == run else { return false }
            if passive {
                guard let member = receipt["memberId"].integer, member > 0, actor == "MEMBER:\(member)",
                      let source = receipt["sourceReceiptId"].text, !source.isEmpty else { return false }
            }
        }
        // A later phase can have a newer role version. Never replace the original frozen version with that value.
        return true
    }
}
