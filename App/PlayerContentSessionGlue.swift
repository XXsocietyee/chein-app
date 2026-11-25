import Foundation

/// Search and official-event session glue. Kept out of `AppSession.swift` (size ratchet).
/// City, merchant, and nearby reads stay on the previous `SearchMapSessionReader`.
/// A city filter and every other official read stay on the previous `OfficialSessionReader`.
extension AppSession {
    /// Global search and the type-1 category directory.
    /// `categories` calls `categoryList`. `search` calls `searchTopicList`, `searchActivityList`, `searchClubList`, and `searchMerchantList`.
    func playerContentSearchMapReader(_ inner: SearchMapSessionReader, area: ManualMapAreaSelection) -> any SearchMapReading {
        PlayerContentSearchMapReader(
            inner: inner,
            baseURL: { [weak self] in self?.regionalConfiguration?.apiConfiguration?.baseURL },
            transport: compositionTransport.scopedForManualMap(area),
            token: { [weak self] in self?.token },
            stamp: { [weak self] in self?.gate.currentStamp ?? 0 },
            onUnauthorized: { [weak self] credential, stamp in
                guard let self else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: stamp, credential: credential)
            })
    }

    /// Public list, mine, and can-publish.
    /// Those three call `officialEvents`, `officialMyEvents`, and `officialCanPublish`.
    /// A city filter still uses the previous reader.
    func playerContentOfficialEventReader(_ inner: OfficialSessionReader) -> any OfficialEventReading {
        PlayerContentOfficialReader(
            inner: inner,
            baseURL: { [weak self] in self?.regionalConfiguration?.apiConfiguration?.baseURL },
            transport: compositionTransport,
            token: { [weak self] in self?.token },
            onUnauthorized: { [weak self] credential in
                guard let self, self.token == credential else { return }
                self.expireIfMatching(error: APIError.unauthorized, stamp: self.gate.currentStamp, credential: credential)
            })
    }

    /// Self-play create still goes through `PlayerContentSelfPlayClient` and does not send.
    func playerContentSelfPlayClient(_ inner: TopicSelfPlayHTTPClient, baseURL: URL) -> PlayerContentSelfPlayClient {
        PlayerContentSelfPlayClient(inner: inner, baseURL: baseURL)
    }
}
