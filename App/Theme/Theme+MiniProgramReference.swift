import SwiftUI

// UI-F10: additive reference constants for mini-program values that `Theme+Generated.swift` does not carry
// (they are literals in `components/tabBar/index.wxss`, not tokens). 375pt basis: 1rpx = 0.5pt.
// Nothing here replaces or renames an existing symbol.

extension Theme {
    /// Literal values from the mini-program shell chrome (`components/tabBar`, `style/tokens.wxss`).
    enum MiniProgramChrome {
        /// `--cy-ref-violet-500`: the only violet left, used for the selected tab icon (UI-03, 2026-09-18).
        static let tabSelectedHex: UInt32 = 0x7A5CFF
        /// `.tabbar__icon { opacity: .6 }` for unselected tab icons (V3-25).
        static let tabUnselectedOpacity: Double = 0.6
        /// `.tabbar { --tabbar-glass }`: fallback 0.82 dark glass (`rgba(28,28,30,.82)`).
        static let tabGlassAlpha: Double = 0.82
        /// Light-domain `.tabbar { --tabbar-glass }`: fallback 0.78 light glass (`rgba(255,255,255,.78)`).
        static let lightTabGlassAlpha: Double = 0.78
        /// `--cy-tabbar-h: 104rpx` (+ safe area): content height of the bar.
        static let tabBarContentHeight: CGFloat = 52
        /// `.tabbar__icon` 64rpx square.
        static let tabIconSize: CGFloat = 32
        /// Merchant bar gradient end alpha (`rgba(255,255,255,.96)`).
        static let merchantTabBarEndAlpha: Double = 0.96
        /// Minimum interactive size (`--cy-btn-h` 88rpx).
        static let minHit: CGFloat = 44
    }
}

extension ThemeDomain {
    /// Mini-program palette for this role domain (see `CYDomainPalette`).
    var palette: CYDomainPalette { CYDomainPalette(self) }
}
