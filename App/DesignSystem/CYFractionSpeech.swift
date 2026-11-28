import SwiftUI

/// VoiceOver reading for a visible "a/b" or "a / b" count string: "a of b" / "a，共 b", never "slash" / "斜杠".
/// Anything that is not exactly two non-empty parts is read as shown.
enum CYFractionSpeech {
    static func label(_ visible: String) -> Text {
        let parts = visible.split(separator: "/", omittingEmptySubsequences: false).map { String($0).trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { return Text(verbatim: visible) }
        let done: String = parts[0]
        let total: String = parts[1]
        return Text("a11y.value.ofTotalText \(done) \(total)")
    }
}
