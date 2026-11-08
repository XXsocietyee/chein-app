import Foundation

/// Port of the mini-program `subpackageRoam/citystamp` print slip photo (`sgslip__photo`).
/// The exchanged stamp's picture is shown on the slip only when it is a plain https URL with a
/// host and no embedded credentials — the same rule the album card applies to remote images.
/// Pure value logic: no network, no Photos access.
public enum RoamStampSlipPhotoPort {
    public static func displayURL(_ raw: String?) -> URL? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty,
              let url = URL(string: trimmed), url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
    /// The mini-program shows the photo block only for a successful exchange; an unusable URL
    /// keeps the slip text fields and shows the "image unavailable" line instead of a broken box.
    public static func shouldShowPhotoBlock(got: Bool) -> Bool { got }
}
