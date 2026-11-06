import Foundation

/// D36 §10.2/10.3 original quest journal and chapter clock: condition references only, never author initial values.
public enum OriginalRpgProgressConditions {
    public static func reserved(_ key: String) -> Bool { key == "sys.day" || key.hasPrefix("sys.quest.") }
    public static func readable(_ key: String) -> Bool {
        key == "sys.day" || key.range(of: "^sys\\.quest\\.[a-z][a-z0-9_]{0,31}$", options: .regularExpression) != nil
    }
    public static func threshold(_ value: Double?) -> Bool {
        guard let value else { return false }
        return value.isFinite && value.rounded() == value && value >= Double(Int32.min) && value <= Double(Int32.max)
    }
}
