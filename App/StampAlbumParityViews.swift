import SwiftUI

/// Mini-program stamp-album count headline (`{{total}} 枚`), shown only after a page was read.
/// `text` is `StampAlbumIndexPageState.totalText`: a literal count, or the em dash when the total is unknown.
struct StampAlbumTotalHeader: View {
    @Environment(\.cyPalette) private var palette
    let text: String
    init(total: Int) { text = String(total) }
    init(text: String) { self.text = text }
    private var label: Text {
        if let total = Int(text) { return Text("stampAlbum.total \(total)") }
        return Text(verbatim: StampAlbumIndexPageState.unknownText)
    }
    var body: some View {
        // Mini-program `al-hd`: a large light count and a small 枚 beside it (B62); unknown stays the em dash.
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            Text(verbatim: text).cyText(.pageTitle, weight: .light).monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(palette.textPrimary)
            if Int(text) != nil {
                Text("u10.album.unit").cyText(.bodyCompact).foregroundStyle(palette.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Int(text) == nil ? Text("stampAlbum.unknownDetail") : label)
        .accessibilityIdentifier("roam.experience.album.total")
    }
}

/// 403 is 当前账号无法查看: the album is not empty and a retry would not help.
struct StampAlbumDeniedNotice: View {
    var body: some View {
        // mp-states r3 (MP stamp-album wxml:28 cy-empty 当前身份不能查看): the one state pattern.
        ContentUnavailableView("stampAlbum.denied", systemImage: "lock")
            .accessibilityIdentifier("roam.experience.album.denied")
    }
}
