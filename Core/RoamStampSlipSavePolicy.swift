import Foundation

/// WIRE-2: decision for the city-stamp slip "保存到相册" action (`subpackageRoam/citystamp` `onSave`).
/// The mini-program checks the tear step first, then that the stamp has a picture. Pure value logic:
/// no network, no Photos access.
public enum RoamStampSlipSavePolicy {
    public enum Decision: Equatable {
        case needsTear
        case noPicture
        case ready(URL)
    }
    public static func decide(torn: Bool, pictureURL: String?) -> Decision {
        guard torn else { return .needsTear }
        guard let url = RoamStampSlipPhotoPort.displayURL(pictureURL) else { return .noPicture }
        return .ready(url)
    }
}
