import SwiftUI

/// Mini-program stamp-album count headline (`{{total}} 枚`), shown only after a page was read.
/// `text` is `StampAlbumIndexPageState.totalText`: a literal count, or the em dash when the total is unknown.
struct StampAlbumTotalHeader: View {
    let text: String
    init(total: Int) { text = String(total) }
    init(text: String) { self.text = text }
    private var label: Text {
        if let total = Int(text) { return Text("stampAlbum.total \(total)") }
        return Text(verbatim: StampAlbumIndexPageState.unknownText)
    }
    var body: some View {
        label.font(.system(.title, design: .rounded).weight(.heavy)).monospacedDigit()
            .contentTransition(.numericText())
            .accessibilityLabel(Int(text) == nil ? Text("stampAlbum.unknownDetail") : label)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .padding(CYSpacing.lg)
            .background { CYCoverArt(seed: "stamp-album", symbol: "seal.fill", cornerRadius: CYRadius.lg) }
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
