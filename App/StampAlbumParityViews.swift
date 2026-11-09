import SwiftUI

/// Mini-program stamp-album count headline (`{{total}} 枚`), shown only after a page was read.
struct StampAlbumTotalHeader: View {
    let total: Int
    var body: some View {
        Text("stampAlbum.total \(total)").font(.system(.title, design: .rounded).weight(.heavy)).monospacedDigit()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(CYSpacing.lg)
            .background { CYCoverArt(seed: "stamp-album", symbol: "seal.fill") }
            .accessibilityIdentifier("roam.experience.album.total")
    }
}

/// 403 is 当前账号无法查看: the album is not empty and a retry would not help.
struct StampAlbumDeniedNotice: View {
    var body: some View {
        Label("stampAlbum.denied", systemImage: "lock")
            .accessibilityIdentifier("roam.experience.album.denied")
    }
}
