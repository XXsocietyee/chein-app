import Foundation

/// mp-roam r3 (function audit P2-7, MP `pages/roam/index.js` `onPoiTap`): the one toast the MP shows for each
/// 点亮 outcome, so the live-map POI tap (compiled pass) only has to call `RoamCheckinFeedback` and show `messageKey`.
/// Order follows the MP: no live fix → 开启实时定位后才能点亮 (no request); tooFar → 离得有点远，走近点;
/// participating + poiId → open the `roam-poi-detail` scene (no toast); participating == false →
/// +xp 探索值 · 点亮<name> on the first visit, else 已点亮过; other code-200 → 这个地点暂时没有可记录的信息;
/// network → 网络异常，请重试; 401 / 403 → 登录后才能点亮; other HTTP / business failure → 服务暂不可用.
public enum RoamCheckinFeedback: Equatable, Sendable {
    case needsLiveFix
    case tooFar
    case openPlace(poiID: Int)
    case litFirstVisit(xp: Int, name: String)
    case alreadyLit
    case nothingToRecord
    case network
    case signIn
    case serviceUnavailable

    public init(disposition: RoamCheckinDisposition, placeName: String) {
        switch disposition {
        case .tooFar:
            self = .tooFar
        case .needsScan(let poiID):
            self = .openPlace(poiID: poiID)
        case .lit(let firstVisit, let awardedXP):
            self = firstVisit ? .litFirstVisit(xp: awardedXP, name: placeName) : .alreadyLit
        case .nothingToRecord:
            self = .nothingToRecord
        }
    }

    public init(error: Error) {
        if let api = error as? APIError {
            switch api {
            case .unauthorized:
                self = .signIn
            case .httpStatus(let status):
                self = (status == 401 || status == 403) ? .signIn : .serviceUnavailable
            default:
                self = .serviceUnavailable
            }
            return
        }
        self = (error is URLError) ? .network : .serviceUnavailable
    }

    /// Catalogue key of the MP toast; nil when the MP opens a page instead. `litFirstVisit` takes `%lld %@` (xp, name).
    public var messageKey: String? {
        switch self {
        case .needsLiveFix: return "roam.checkin.needsLiveFix"
        case .tooFar: return "roam.checkin.tooFar"
        case .openPlace: return nil
        case .litFirstVisit: return "roam.checkin.litFirstVisit %lld %@"
        case .alreadyLit: return "roam.checkin.alreadyLit"
        case .nothingToRecord: return "roam.checkin.nothingToRecord"
        case .network: return "roam.checkin.network"
        case .signIn: return "roam.checkin.signIn"
        case .serviceUnavailable: return "roam.checkin.serviceUnavailable"
        }
    }
}
