import SwiftUI

/// Exchanged stamp photo on the city-stamp print slip (mini-program `sgslip__photo`).
/// Reuses the album card's remote-image rule; strings are existing keys.
struct RoamStampSlipPhotoView: View {
    let pictureURL: String?
    var body: some View {
        Group {
            if let url = RoamStampSlipPhotoPort.displayURL(pictureURL) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else if phase.error != nil { Label("roam.experience.imageUnavailable", systemImage: "photo.badge.exclamationmark") }
                    else { ProgressView("roam.loading") }
                }
            } else {
                Label("roam.experience.imageUnavailable", systemImage: "photo")
            }
        }
        .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel(Text("roam.experience.stampImage"))
        .accessibilityIdentifier("roamSub.w208.stamp.photo")
    }
}
