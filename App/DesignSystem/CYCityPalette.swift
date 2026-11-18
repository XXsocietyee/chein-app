import SwiftUI

/// City Monopoly literal colours (Figma `District` collection 426:1237, `Moment/Art`, owner Q1/Q11).
/// The only place the City kit (`App/CityKit`) reads raw colour values; views use `CityTokens`.
enum CYCityPalette {
    /// `district/1…6` dark-mode band colours; index 0 is `surface-3` (no district / unlit).
    static func district(_ index: Int) -> Color {
        switch index {
        case 1: return Color(red: 0.310, green: 0.525, blue: 0.918)   // 武康路 blue: the only blue on the map (Q1)
        case 2: return Color(red: 0.180, green: 0.741, blue: 0.627)   // teal
        case 3: return Color(red: 0.941, green: 0.584, blue: 0.290)   // orange
        case 4: return Color(red: 0.902, green: 0.400, blue: 0.420)   // coral
        case 5: return Color(red: 0.820, green: 0.741, blue: 0.290)   // mustard
        case 6: return Color(red: 0.443, green: 0.722, blue: 0.341)   // green
        default: return Color(red: 0.235, green: 0.235, blue: 0.247)
        }
    }
    /// `ink-inv` on a district band (5.6–10.5:1 on bands 1–6).
    static let bandInk = Color(red: 0.039, green: 0.039, blue: 0.039)
    /// "You" on the map: the primary-button white (Q1).
    static let mine = Color(red: 0.961, green: 0.961, blue: 0.969)
    /// The 积分 coin and the gold of the die and seal (`Moment/Art`).
    static let coin = Color(red: 0.965, green: 0.773, blue: 0.267)
    static let gold = Color(red: 0.86, green: 0.55, blue: 0.10)
    /// The lost die (grey, sinks).
    static let lostTop = Color(white: 0.55)
    static let lostBottom = Color(white: 0.32)
}
