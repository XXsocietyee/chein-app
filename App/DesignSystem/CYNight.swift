import SwiftUI

/// "Night-city light" (夜城之光): the player's ground is cold ink, light is rationed to discovery and reward.
/// Lantern gold appears only in fog edges, lit tiles, stamp seals, badge blooms, ticket foil and press ripples.
/// Never on chrome, navigation, list rows, form controls, or resting buttons. Spec: specs/design-wave3.md.
public enum CYNight {
    public static let ink0 = CYRGB(hex: 0x06060A).swiftUIColor      // page ground
    public static let ink1 = CYRGB(hex: 0x0E0E16).swiftUIColor      // card ground
    public static let ink2 = CYRGB(hex: 0x171726).swiftUIColor      // raised card / sheet
    public static let indigo = CYRGB(hex: 0x1B1E4A).swiftUIColor    // map ground, fog, hero backdrops
    /// Reserved tab-selected tint reference (`CYColor.tabSelected`, `--cy-ref-violet-500` `#7A5CFF`).
    @available(*, deprecated, renamed: "CYColor.tabSelected")
    public static var violet: Color { CYColor.tabSelected }
    /// Selected mark for player controls (neutral `--cy-color-selection`; no violet).
    public static var selection: Color { CYColor.selection }
    // Muted group hues for Settings tiles (quiet chrome: no lantern, no violet).
    public static let tileBlue = CYRGB(hex: 0x3A4A8A).swiftUIColor
    public static let tileGreen = CYRGB(hex: 0x1E6B4A).swiftUIColor
    public static let tileOrange = CYRGB(hex: 0x8A5A32).swiftUIColor
    public static let tileRed = CYRGB(hex: 0x8A3A32).swiftUIColor
    public static let tilePink = CYRGB(hex: 0x8A4A58).swiftUIColor
    public static let tileTeal = CYRGB(hex: 0x1E5A68).swiftUIColor
    public static let lantern = CYRGB(hex: 0xFFB84D).swiftUIColor   // light: discovery + reward only
    public static let lanternHot = CYRGB(hex: 0xFFE3A6).swiftUIColor // light core
    public static let ember = CYRGB(hex: 0xFF7A3D).swiftUIColor     // gradient tail of lantern, never alone
    public static let verify = CYRGB(hex: 0x3DDC84).swiftUIColor    // success edge glow / morphed button only
    public static let foilA = CYRGB(hex: 0xF59F00).swiftUIColor
    public static let foilB = CYRGB(hex: 0xFFB84D).swiftUIColor
    public static let foilC = CYRGB(hex: 0x3DD6FF).swiftUIColor
    // Pass reveal gold wash (MP subpackagePass/reveal .ky__grad, owner 2026-11-19): deep copper → warm gold.
    public static let passGold0 = CYRGB(hex: 0x2A1E08).swiftUIColor
    public static let passGold1 = CYRGB(hex: 0x8A6414).swiftUIColor
    public static let passGold2 = CYRGB(hex: 0xD4A72C).swiftUIColor
    public static let passGold3 = CYRGB(hex: 0xF2CF63).swiftUIColor
    public static let glassFill = Color.white.opacity(0.06)
    public static let glassEdgeTop = Color.white.opacity(0.14)
    public static let glassEdgeBottom = Color.white.opacity(0.04)

    /// Glow = lantern radial behind an object (never an overlay on text), radius about 1.6x the object.
    public static func glow(radius: CGFloat) -> RadialGradient {
        RadialGradient(
            stops: [.init(color: lanternHot.opacity(0.55), location: 0), .init(color: lantern.opacity(0.25), location: 0.5), .init(color: .clear, location: 1)],
            center: .center, startRadius: 0, endRadius: radius * 1.6)
    }
}

/// Central switch for every shader, particle, and gyro effect (Reduce Motion is read per view by QuestifyReduceMotion).
enum CYLightBudget {
    static var shadersAllowed: Bool {
        let info = ProcessInfo.processInfo
        return !info.isLowPowerModeEnabled && info.thermalState.rawValue < ProcessInfo.ThermalState.serious.rawValue
    }
    /// Only the Metal `ShaderLibrary` effects (`cyWave`) also need the compiled metallib. The Metal Toolchain is an optional
    /// build dependency (`CY_ENABLE_METAL=1 tools/generate_project.py` defines `CY_METAL_SHADERS`); without it every
    /// shader modifier is compiled out and the non-shader fallback (scale dip, touch ripple, Canvas rings) plays.
    static var metalShadersAllowed: Bool {
        #if CY_METAL_SHADERS
        return shadersAllowed
        #else
        return false
        #endif
    }
    static var gyroAllowed: Bool { shadersAllowed }
    static var particlesAllowed: Bool { shadersAllowed }
}
