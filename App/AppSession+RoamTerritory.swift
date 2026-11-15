import Foundation

extension AppSession {
    func makeRoamTerritoryPhotoContext() -> RetainedImageSelectionContext? {
        guard let scope = roamMediaScope, let configuration = regionalConfiguration?.apiConfiguration,
              let credentials = currentRetainedImageCredentials,
              let wire = compositionTransport.makeRoamLiveWriteTransport() else { return nil }
        let current: () -> RetainedImageScope? = { [weak self] in
            guard let self, self.currentRetainedImageCredentials == credentials else { return nil }; return self.roamMediaScope
        }
        let token: () -> String? = { [weak self] in self?.currentRetainedImageCredentials == credentials ? credentials.token : nil }
        let origins = RetainedImageOrigin.configured(apiBase: configuration.baseURL,
            extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String)
        let uploader = RetainedImageHTTPUploader(configuration: configuration, transport: wire,
            enabled: true, approvedOrigins: origins, currentScope: current, token: token)
        return RetainedImageSelectionContext(scope: scope, currentScope: current,
            picker: retainedImagePickerHost.makePicker(),
            uploads: RetainedImageUploadCoordinator(uploader: uploader, journal: imageUploadJournal))
    }
}
