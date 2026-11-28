import XCTest
@testable import Questify

@MainActor final class RemotePushRegistrationClientTests: XCTestCase {
    @MainActor final class Recorder: RemotePushRegistering {
        var calls = 0
        func registerForRemoteNotifications() { calls += 1 }
    }

    func testRefusedUploadDoesNotRegister() {
        let recorder = Recorder()
        RemotePushRegistrationClient.consider(authorization: .authorized, application: recorder, uploadAdmitted: false)
        RemotePushRegistrationClient.consider(authorization: .provisional, application: recorder, uploadAdmitted: false)
        RemotePushRegistrationClient.consider(authorization: .ephemeral, application: recorder, uploadAdmitted: false)
        XCTAssertEqual(recorder.calls, 0)
        XCTAssertFalse(DevicePushTokenUpload.compositionAdmitsUpload())
    }

    func testProductionDefaultIsTheRefusedComposition() {
        let recorder = Recorder()
        RemotePushRegistrationClient.consider(authorization: .authorized, application: recorder)
        XCTAssertEqual(recorder.calls, 0)
    }

    func testAllowedUploadRegistersOnlyAfterLocalPermission() {
        let recorder = Recorder()
        RemotePushRegistrationClient.consider(authorization: nil, application: recorder, uploadAdmitted: true)
        RemotePushRegistrationClient.consider(authorization: .notDetermined, application: recorder, uploadAdmitted: true)
        RemotePushRegistrationClient.consider(authorization: .denied, application: recorder, uploadAdmitted: true)
        RemotePushRegistrationClient.consider(authorization: .unknown(0), application: recorder, uploadAdmitted: true)
        XCTAssertEqual(recorder.calls, 0)
        RemotePushRegistrationClient.consider(authorization: .authorized, application: recorder, uploadAdmitted: true)
        RemotePushRegistrationClient.consider(authorization: .provisional, application: recorder, uploadAdmitted: true)
        RemotePushRegistrationClient.consider(authorization: .ephemeral, application: recorder, uploadAdmitted: true)
        XCTAssertEqual(recorder.calls, 3)
    }
}
