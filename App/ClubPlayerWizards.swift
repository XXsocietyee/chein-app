import Foundation

/// Launch-argument gate. Player create uses the four-step wizard.
/// `--uitesting-club-operations` keeps the flat form the existing UI tests open directly.
enum ClubPlayerSurface {
    static var flatCreateForm: Bool {
        ProcessInfo.processInfo.arguments.contains("--uitesting-club-operations")
    }
}
