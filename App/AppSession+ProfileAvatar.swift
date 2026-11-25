import Foundation

extension AppSession {
    /// A3-01 MP-first (owner 2026-11-25; MP gerenziliao.js:781-812 avatar, :354 探索作品, :383 联系二维码 → app.js:654-668
    /// `api/common/uploadOSS`): the image upload the MP sends, composed from the player write grant's avatar approval.
    /// Upload is idempotent (owner decision #4); the server's checks decide. Nil without that grant.
    var profileAvatarDependencies: ProfileAvatarDependencies? {
        guard let context = currentRuntimeDependencyContext, let configuration = regionalConfiguration?.apiConfiguration,
              let approval = composition.playerWriteGrant(context)?.avatar else { return nil }
        let wire = runtimeHTTPTransport, namespace = context.session.namespace, coordinator = profileEditCoordinator
        let source = ProfileAvatarUploadClient(configuration: configuration, approval: approval,
            transport: ReviewedProfileAvatarDispatch { try await wire.send($0) },
            credentials: { [weak self] in
                guard let token = self?.token, let identity = coordinator.identity, let revision = coordinator.viewerRevision,
                      let session = try? ProfileEditSession(accountID: identity.accountID, epoch: identity.epoch, token: token, viewerRevision: revision)
                else { return nil }
                return try? ProfileAvatarCredentials(session: session, namespace: namespace, token: token)
            },
            currentApproval: { [weak self] in
                guard let self, let context = self.currentRuntimeDependencyContext else { return nil }
                return self.composition.playerWriteGrant(context)?.avatar
            })
        // The journal persists only attempt metadata in the keychain-backed image-upload storage; a new wrapper reads the same entries.
        let storage = ImageUploadSecureStorage(scope: storageScope)
        let journal = StoredProfileAvatarJournal(read: { try storage.read($0) }, write: { try storage.write($0, key: $1) })
        return ProfileAvatarDependencies(source: source, journal: journal, pickerHost: retainedImagePickerHost)
    }
}
