import Foundation

extension NativeR2Flags {
    /// In-app Island (top pop-up) and the Dynamic Island / Live Activity regions it adds.
    /// `-nativeR2.island NO` restores the bottom toast, the silent foreground push and the old Live Activity layout.
    static var island: Bool { isEnabled("nativeR2.island") }
}
