import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// fix/city-gaps-r3 §4: the cityTerritory IM system card (被抢 / 守住了 / 收租 / 租金入账), drawn in the
// system-notice style of the message list (`MessagingBubble.noticeCard`: 36 pt icon disc, bold title, time,
// one body sentence, `bgElevated` 60 % on a `CYRadius.md` card). A tap opens the place's property sheet on the
// 漫游 root (the City map), through `CityDeepLinks` and the root tab switch. No new screen.

/// The pending City deep link. The 漫游 root consumes it once its board is loaded.
@MainActor final class CityDeepLinks: ObservableObject {
    static let shared = CityDeepLinks()
    /// The territory whose property sheet should open on the map.
    @Published private(set) var pendingProperty: String?

    func openProperty(_ territoryId: String) { pendingProperty = territoryId }

    /// Hands the pending territory to the root once and clears it.
    func consume() -> String? {
        let id = pendingProperty
        pendingProperty = nil
        return id
    }
}

struct CityTerritoryNoticeCard: View {
    let notice: CityTerritoryNotice
    /// The message time as the list prints it ("—" when unknown).
    var stamp: String? = nil
    /// Overrides the default action (switch to 漫游 and open the property). Tests and fixtures only.
    var onOpen: ((String) -> Void)? = nil

    @Environment(\.locale) private var locale
    @Environment(\.rootTabSwitch) private var rootTabSwitch

    private var copy: CityCopy { CityCopy(locale: locale) }

    var body: some View {
        if let territoryId = notice.territoryId {
            Button { open(territoryId) } label: { card(chevron: true) }
                .buttonStyle(QuestifyCardButtonStyle())
                .accessibilityHint(Text(verbatim: copy("打开这块地的地契", "Opens the place's deed")))
                .accessibilityIdentifier("city.notice.\(notice.kind.rawValue.lowercased())")
        } else {
            card(chevron: false)
                .accessibilityIdentifier("city.notice.\(notice.kind.rawValue.lowercased())")
        }
    }

    private func card(chevron: Bool) -> some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            Image(systemName: symbol).font(CYTypography.body).foregroundStyle(CYColor.textSecondary)
                .frame(width: 36, height: 36).background(Circle().fill(CYColor.bgElevated)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: headline).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    Spacer(minLength: 4)
                    if let stamp { Text(verbatim: stamp).cyText(.caption).foregroundStyle(CYColor.textTertiary) }
                }
                Text(verbatim: sentence(for: notice)).cyText(.body).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let points = pointsLine {
                    Text(verbatim: points).cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textSecondary)
                }
            }
            if chevron {
                Image(systemName: "chevron.right").font(CYTypography.caption.weight(.semibold)).foregroundStyle(CYColor.textTertiary)
                    .frame(maxHeight: .infinity).accessibilityHidden(true)
            }
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgElevated.opacity(0.6), in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch notice.kind {
        case .defended: return "shield.lefthalf.filled"
        case .placeLost: return "flag.slash"
        case .rent, .rentSettled: return "building.columns"
        }
    }

    private var headline: String {
        switch notice.kind {
        case .defended: return copy("守住了", "You held it")
        case .placeLost: return copy("被拿走了", "Place taken")
        case .rent: return copy("收到租金", "Rent earned")
        case .rentSettled: return copy("租金已入账", "Rent settled")
        }
    }

    private func sentence(for notice: CityTerritoryNotice) -> String {
        let place = notice.title
        switch notice.kind {
        case .defended: return copy("有人挑战「\(place)」失败了，这块地还是你的。", "A challenge for \(place) failed. It is still yours.")
        case .placeLost: return copy("「\(place)」被挑战者拿走了。24 小时内反击，挑战费减半。", "\(place) was taken. Strike back within 24 h at half the fee.")
        case .rent: return copy("今天第一位访客来到「\(place)」，03:00 核对后入账。", "Today's first visitor came to \(place). Settled after 03:00.")
        case .rentSettled: return notice.sentence ?? copy("今天的租金已核对入账。", "Today's rent has been settled.")
        }
    }

    /// 积分 only. A missing number hides the line; 0 hides it too (a failed on-site task pays no compensation).
    private var pointsLine: String? {
        guard let points = notice.points, points > 0 else { return nil }
        switch notice.kind {
        case .defended, .placeLost: return copy("守方补偿 +\(points) 积分", "Holder compensation +\(points) pts")
        case .rent, .rentSettled: return "+" + copy.points(points)
        }
    }

    private func open(_ territoryId: String) {
        if let onOpen { onOpen(territoryId); return }
        CityDeepLinks.shared.openProperty(territoryId)
        if rootTabSwitch.isAvailable { rootTabSwitch(.roam) }
    }
}

