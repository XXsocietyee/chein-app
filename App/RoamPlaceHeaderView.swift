import SwiftUI

/// design-r2-roam (P15 place facts in one line, actions as a pill row): the place / checkpoint header in the roam
/// item sheet. Reads name → category · area → live status in colour, then a horizontal row of capsule actions.
/// Content follows the MP node card (`scene-roam-poi-detail` `poi-section` address line, `poi-node__actions`
/// 收藏 · 导航 · 投一张; favourite and directions keep their own reviewed rows below, the row holds the rest).
enum RoamPlaceLiveStatus: Equatable {
    case unpublished, completed, open

    var key: LocalizedStringKey {
        switch self {
        case .unpublished: return "roam.notPublished"
        case .completed: return "roam.completed"
        case .open: return "design.roam.place.status.open"
        }
    }
    var symbol: String {
        switch self {
        case .unpublished: return "eye.slash"
        case .completed: return "checkmark.seal.fill"
        case .open: return "flag.checkered"
        }
    }
    var tint: Color {
        switch self {
        case .unpublished: return .orange
        case .completed: return .green
        case .open: return .accentColor
        }
    }
}

struct RoamPlaceHeaderView<Actions: View>: View {
    let name: String
    let kind: LocalizedStringKey
    let symbol: String
    let area: String?
    let status: RoamPlaceLiveStatus
    let actions: Actions

    init(name: String, kind: LocalizedStringKey, symbol: String, area: String?, status: RoamPlaceLiveStatus,
         @ViewBuilder actions: () -> Actions) {
        self.name = name; self.kind = kind; self.symbol = symbol; self.area = area; self.status = status
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: name).cyText(.sheetTitle).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                factsLine.cyText(.bodyCompact).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label(status.key, systemImage: status.symbol)
                    .cyText(.bodyMedium).foregroundStyle(status.tint)
                    .accessibilityIdentifier("roam.place.status")
            }
            .accessibilityElement(children: .combine)
            // P12: English labels are longer; the row scrolls instead of squeezing or wrapping capsules.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CYSpacing.sm) { actions }
                    .controlSize(.regular)
                    .padding(.vertical, 2)
            }
            .accessibilityIdentifier("roam.place.actions")
        }
        .padding(.vertical, CYSpacing.xs)
    }

    /// category · area (area hidden when the place has no address).
    private var factsLine: Text {
        let base = Text(Image(systemName: symbol)) + Text(verbatim: " ") + Text(kind)
        guard let area, !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return base }
        return base + Text(verbatim: " · " + area)
    }
}
