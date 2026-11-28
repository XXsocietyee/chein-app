import Foundation
import UIKit

/// The object `registerForRemoteNotifications` is sent to. Production uses `UIApplication` only after the upload is admitted.
@MainActor protocol RemotePushRegistering: AnyObject {
    func registerForRemoteNotifications()
}

extension UIApplication: RemotePushRegistering {}

/// Settings 通知权限 asks this after the system notification permission is already allowed.
/// The call to `registerForRemoteNotifications` runs only when `uploadAdmitted` is true.
/// The production default is `DevicePushTokenUpload.compositionAdmitsUpload()`, which the composition still refuses,
/// so the call is not made and `UIApplication` is not touched.
@MainActor enum RemotePushRegistrationClient {
    static func consider(authorization: NativeNotificationPermissionAuthorization?,
                         application: RemotePushRegistering? = nil,
                         uploadAdmitted: Bool = DevicePushTokenUpload.compositionAdmitsUpload()) {
        guard let authorization, localPermissionAllowsRemote(authorization) else { return }
        guard uploadAdmitted else { return }
        let target = application ?? UIApplication.shared
        target.registerForRemoteNotifications()
    }

    static func localPermissionAllowsRemote(_ authorization: NativeNotificationPermissionAuthorization) -> Bool {
        switch authorization {
        case .authorized, .provisional, .ephemeral: return true
        case .notDetermined, .denied, .unknown: return false
        }
    }
}
