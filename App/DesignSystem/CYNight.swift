import SwiftUI

/// "Night-city light" (夜城之光): the player's ground is cold ink, light is rationed to discovery and reward.
/// Lantern gold appears only in fog edges, lit tiles, stamp seals, badge blooms, ticket foil and press ripples.
/// Never on chrome, navigation, list rows, form controls, or resting buttons. Spec: specs/design-wave3.md.
public enum CYNight {
    public static let ink0 = CYRGB(hex: 0x06060A).swiftUIColor      // page ground
    public static let ink1 = CYRGB(hex: 0x0E0E16).swiftUIColor      // card ground
    public static let ink2 = CYRGB(hex: 0x171726).swiftUIColor      // raised card / sheet
    public static let indigo = CYRGB(hex: 0x1B1E4A).swiftUIColor    // map ground, fog, hero backdrops
    public static let violet = CYRGB(hex: 0x7A5CFF).swiftUIColor    // selection only
    public static let lantern = CYRGB(hex: 0xFFB84D).swiftUIColor   // light: discovery + reward only
    public static let lanternHot = CYRGB(hex: 0xFFE3A6).swiftUIColor // light core
    public static let ember = CYRGB(hex: 0xFF7A3D).swiftUIColor     // gradient tail of lantern, never alone
    public static let verify = CYRGB(hex: 0x3DDC84).swiftUIColor    // success edge glow / morphed button only
    public static let foilA = CYRGB(hex: 0x7A5CFF).swiftUIColor
    public static let foilB = CYRGB(hex: 0xFFB84D).swiftUIColor
    public static let foilC = CYRGB(hex: 0x3DD6FF).swiftUIColor
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
    static var gyroAllowed: Bool { shadersAllowed }
    static var particlesAllowed: Bool { shadersAllowed }
}
