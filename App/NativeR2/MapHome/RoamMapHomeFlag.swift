import Foundation

extension NativeR2Flags {
    /// 漫游 tab root: the Apple-Maps-style map home (`RoamMapHomeView`).
    /// `false` (`-nativeR2.mapHome NO`) restores the City board root (`SessionCityRoamRoot`).
    static var mapHome: Bool { isEnabled("nativeR2.mapHome") }
}
