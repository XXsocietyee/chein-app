import UIKit
import UniformTypeIdentifiers

/// The write half of `UIPasteboard`, so tests can observe the options a copy uses.
protocol PasteboardWriting {
    func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any])
}
extension UIPasteboard: PasteboardWriting {}

/// Single route for app copy actions. Copied text stays on this device (no Universal Clipboard sync)
/// and is removed from the pasteboard after a short lifetime.
enum LocalPasteboard {
    static let defaultLifetime: TimeInterval = 120

    static func copy(_ text: String, lifetime: TimeInterval = defaultLifetime, now: Date = Date(),
                     to board: any PasteboardWriting = UIPasteboard.general) {
        board.setItems([[UTType.utf8PlainText.identifier: text]],
                       options: [.localOnly: true, .expirationDate: now.addingTimeInterval(lifetime)])
    }
}
