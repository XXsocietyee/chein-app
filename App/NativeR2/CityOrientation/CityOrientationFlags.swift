import Foundation

extension NativeR2Flags {
    /// 同城定向 native flow: event detail, team lobby, live run map, punch sheet and finish summary.
    /// Default on. A debug or QA build can turn it off with the `nativeR2.cityOrientation` user default.
    static var cityOrientation: Bool {
        UserDefaults.standard.object(forKey: "nativeR2.cityOrientation") as? Bool ?? true
    }
}
