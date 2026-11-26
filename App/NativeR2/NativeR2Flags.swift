import Foundation

/// Native r2 switches (owner brief 2026-11-26: Apple components only).
/// One static per lane. A lane that needs a new switch adds it here, in this one file,
/// so the type is declared once across the merged branches.
enum NativeR2Flags {
    /// Story flow on Apple components: route page, reader with the mini audio player,
    /// and the in-place stage result sheet. Off restores the r1 views unchanged.
    static let storyFlow = true
}
