import SwiftUI
import UIKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// `City/Deed Card` (Figma 381:1401, skill-r2 SR2-42): the game's one signature object.
// Every field is real: name, district, level, rent per visit, holder and photo come from the
// server. The serial "地契 · No. N" is shown only when the server issues one (Q10, `deedSerial`,
// fix/city-gaps-r3); without it the band carries the district and the tier.

enum CityDeedSize { case full, sheet, row, mini }

extension CityPlace {
    /// The same place after a change of hands (moments show the new holder before the reload lands).
    func handedOver(to ownership: CityPlace.Ownership, level: Int? = nil, holder: String? = nil, protectedUntil: Date? = nil) -> CityPlace {
        CityPlace(id: id, title: title, coordinate: coordinate, territoryId: territoryId, poiId: poiId, boardId: boardId, pointId: pointId,
                  districtId: districtId, districtIndex: districtIndex, tier: tier, level: level ?? self.level, ownership: ownership,
                  holderName: holder, protectedUntil: protectedUntil, decay: ownership == .mine ? nil : decay, photoURL: photoURL,
                  radiusM: radiusM, distanceM: distanceM, invested: invested, districtName: districtName, deedSerial: deedSerial)
    }

    /// The same place with the serial a claim / challenge command just returned (`property.deedSerial`), when the
    /// reloaded layer has none yet. A nil serial changes nothing.
    func withDeedSerial(_ serial: Int?) -> CityPlace {
        guard let serial, deedSerial == nil else { return self }
        return CityPlace(id: id, title: title, coordinate: coordinate, territoryId: territoryId, poiId: poiId, boardId: boardId, pointId: pointId,
                         districtId: districtId, districtIndex: districtIndex, tier: tier, level: level, ownership: ownership,
                         holderName: holderName, protectedUntil: protectedUntil, decay: decay, photoURL: photoURL,
                         radiusM: radiusM, distanceM: distanceM, invested: invested, districtName: districtName, deedSerial: serial)
    }
}

/// What the row's trailing slot shows (SR2-42 `Trailing`).
enum CityDeedTrailing: Equatable {
    case rent
    case today(Int64)
    case status
    case price
}

/// Level pips (`City/Level Pips`): one filled pip per level, the ladder name beside them.
struct CityLevelPips: View {
    let level: Int
    var unknown = false
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 3) {
                ForEach(0..<CityMonopolyLevel.maxLevel, id: \.self) { index in
                    Circle()
                        .fill(!unknown && index < level ? palette.textPrimary : palette.textPrimary.opacity(0.22))
                        .frame(width: 6, height: 6)
                }
            }
            Text(verbatim: unknown ? "—" : CityCopy(locale: locale).level(level))
                .cyText(.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: unknown ? "—" : CityCopy(locale: locale).level(level)))
    }
}

/// The deed photo: the claim photo when the server has one. Without one, the designed "no photo yet" cover
/// (xrefs-1 B.0, Figma `Media/Cover Place=No photo` `453:1395` / `453:1404`): the district colour at 24 % over
/// surface-2, a camera disc and the place name (拍下第一张照片 under it on the large cover). The map glyph on grey is
/// kept only for an unlit place.
struct CityDeedPhoto: View {
    enum Cover { case large, compact, thumb }

    let url: String?
    var corner: CGFloat = 0
    /// The place this photo belongs to; nil draws the neutral cover.
    var place: CityPlace? = nil
    var cover: Cover = .large

    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.cityDeedPhotoSlot) private var slot

    private var https: URL? { url.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil } }

    var body: some View {
        ZStack {
            if let slot, let local = slot.local {
                palette.bgRaised
                Image(uiImage: local).resizable().scaledToFill().opacity(slot.hidesPhoto ? 0 : 1)
            } else {
                Group {
                    placeholder
                    if let https {
                        AsyncImage(url: https) { phase in
                            if case .success(let image) = phase { image.resizable().scaledToFill() }
                        }
                    }
                }
                .opacity(slot?.hidesPhoto == true ? 0 : 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .modifier(CityDeedPhotoSlotTarget(slot: cover == .thumb ? nil : slot))
        .accessibilityHidden(true)
    }

    @ViewBuilder private var placeholder: some View {
        if let place, place.ownership != .fogged {
            CityNoPhotoCover(place: place, cover: cover)
        } else {
            ZStack {
                palette.bgRaised
                Image(systemName: "map").accessibilityHidden(true).font(.title2).foregroundStyle(palette.textTertiary)
            }
        }
    }
}

/// Continuity hook for the 圈下了 moment: the deed's photo is the target of the photo → deed flight, and it can show the
/// photo just taken (a local image) before the server's URL exists.
struct CityDeedPhotoSlot {
    static let sourceID = "city.claim.photo.source"
    static let slotID = "city.deed.photo.slot"
    let namespace: Namespace.ID
    var local: UIImage?
    /// True while the flying copy is in the air (the slot stays empty under it).
    var hidesPhoto = false
}

private struct CityDeedPhotoSlotKey: EnvironmentKey { static let defaultValue: CityDeedPhotoSlot? = nil }

extension EnvironmentValues {
    var cityDeedPhotoSlot: CityDeedPhotoSlot? {
        get { self[CityDeedPhotoSlotKey.self] }
        set { self[CityDeedPhotoSlotKey.self] = newValue }
    }
}

private struct CityDeedPhotoSlotTarget: ViewModifier {
    let slot: CityDeedPhotoSlot?
    @ViewBuilder func body(content: Content) -> some View {
        if let slot {
            content.matchedGeometryEffect(id: CityDeedPhotoSlot.slotID, in: slot.namespace, isSource: true)
        } else {
            content
        }
    }
}

/// `Media/Cover Place=No photo`: district colour 24 % over surface-2, camera disc, place name.
struct CityNoPhotoCover: View {
    let place: CityPlace
    var cover: CityDeedPhoto.Cover = .large
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var disc: CGFloat = 36

    var body: some View {
        let copy = CityCopy(locale: locale)
        ZStack {
            palette.bgRaised
            CityTokens.district(place.districtIndex).opacity(place.districtIndex > 0 ? 0.24 : 0)
            switch cover {
            case .thumb:
                Image(systemName: "camera.fill").accessibilityHidden(true).font(.footnote).foregroundStyle(palette.textSecondary)
            case .compact, .large:
                VStack(spacing: cover == .large ? 6 : 4) {
                    Image(systemName: "camera.fill")
                        .accessibilityHidden(true).font(cover == .large ? .callout : .footnote)
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: cover == .large ? disc : disc * 0.78, height: cover == .large ? disc : disc * 0.78)
                        .background(palette.borderStrong, in: Circle())
                    Text(verbatim: copy.title(place))
                        .font(cover == .large ? Font.title3.weight(.bold) : CYTypography.label.weight(.semibold))
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    if cover == .large {
                        Text(verbatim: copy("拍下第一张照片", "Take the first photo"))
                            .cyText(.caption).foregroundStyle(palette.textSecondary).lineLimit(1)
                    }
                }
                .padding(.horizontal, CYSpacing.md)
            }
        }
    }
}

struct CityDeedCard: View {
    let place: CityPlace
    var size: CityDeedSize = .full
    var trailing: CityDeedTrailing = .rent
    /// Days held, when the screen knows the claim day (the server does not send it on the layer).
    var heldDays: Int? = nil
    var now = Date()

    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .caption) private var bandHeight: CGFloat = 32
    /// a11y-dt r3: the initial grows with Dynamic Type instead of clipping in a fixed 22 pt circle.
    @ScaledMetric(relativeTo: .caption) private var ownerAvatar: CGFloat = 22

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var unlit: Bool { place.ownership == .fogged }
    private var bandColor: Color { CityTokens.district(unlit ? 0 : place.districtIndex) }
    private var outlined: Bool { place.ownership == .open || unlit }
    /// Near-black ink on a district band (5.6–10.5:1); on the neutral band (no district or unlit) the secondary ink.
    private var bandText: Color { !unlit && place.districtIndex > 0 ? CityTokens.bandInk : palette.textSecondary }

    var body: some View {
        Group {
            switch size {
            case .full: full
            case .sheet: sheet
            case .row: row
            case .mini: mini
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: accessibilityText))
    }

    // MARK: Sizes

    private var full: some View {
        VStack(alignment: .leading, spacing: 0) {
            band
            CityDeedPhoto(url: place.photoURL, place: place).frame(height: 168).clipped()
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: copy.title(place)).cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                CityLevelPips(level: place.level, unknown: unlit || place.ownership == .open)
                rentLine
                // Full hugs its content (xrefs-1 B.1): the holder row sits directly under the rent line.
                holderLine.padding(.top, CYSpacing.xs)
            }
            .padding(CYSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(outline(corner: 20))
    }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            band
            CityDeedPhoto(url: place.photoURL, place: place, cover: .compact).frame(height: 88).clipped()
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: copy.title(place)).cyText(.sectionTitle).foregroundStyle(palette.textPrimary).lineLimit(1)
                        Spacer(minLength: CYSpacing.sm)
                        holderOrPips
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: copy.title(place)).cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        holderOrPips
                    }
                }
                rentLine
            }
            .padding(CYSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Inside a sheet the deed is a plain fill with no outline (xrefs-1 B.1, N08–N12): the sheet's edge is the box.
        .background(palette.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder private var row: some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                rowLead
                trailingView
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(outline(corner: 12))
        } else {
            HStack(spacing: CYSpacing.md) {
                rowLead
                Spacer(minLength: CYSpacing.sm)
                trailingView
            }
            .padding(CYSpacing.md)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(outline(corner: 12))
        }
    }

    private var rowLead: some View {
        HStack(spacing: CYSpacing.md) {
            CityDeedPhoto(url: place.photoURL, corner: 10, place: place, cover: .thumb).frame(width: 52, height: 52)
                .overlay(alignment: .top) { Rectangle().fill(bandColor).frame(height: 4).clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)) }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: copy.title(place)).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                HStack(spacing: 6) {
                    Circle().fill(bandColor).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(verbatim: [copy.district(place), unlit ? nil : copy.level(place.level)].compactMap { $0 }.joined(separator: " "))
                        .cyText(.caption).foregroundStyle(palette.textSecondary).lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                }
            }
        }
    }

    private var mini: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: copy.district(place) ?? copy("城市", "City"))
                .cyText(.caption, weight: .semibold).foregroundStyle(bandText).lineLimit(1)
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background(bandColor)
            CityDeedPhoto(url: place.photoURL, place: place, cover: .thumb).frame(height: 58).clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: copy.title(place)).cyText(.label, weight: .semibold).foregroundStyle(palette.textPrimary).lineLimit(1)
                HStack(spacing: 4) {
                    CityCoin()
                    Text(verbatim: place.rentPerVisit.map { "+\($0) / " + copy("次", "visit") } ?? "—")
                        .cyText(.caption, monospacedDigit: true).foregroundStyle(palette.textSecondary).lineLimit(1)
                }
            }
            .padding(8)
        }
        .frame(width: typeSize.isAccessibilitySize ? 160 : 112)
        .background(palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(outline(corner: 12))
    }

    // MARK: Parts

    private var band: some View {
        HStack {
            Text(verbatim: copy.district(place) ?? (unlit ? copy("未点亮", "Unlit") : copy("城市地产", "City place")))
            Spacer(minLength: CYSpacing.sm)
            // The serial appears only when the server issued one (Q10; `CityPlace.deedSerial`).
            if let serial = place.deedSerial, !unlit { Text(verbatim: copy("地契 · No. \(serial)", "Deed · No. \(serial)")).monospacedDigit() }
            else if let tier = copy.tier(place.tier), !unlit { Text(verbatim: tier) }
        }
        .cyText(.caption, weight: .semibold)
        .foregroundStyle(bandText)
        .padding(.horizontal, CYSpacing.md)
        .frame(maxWidth: .infinity, minHeight: bandHeight)
        .background(bandColor)
    }

    private var rentLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            CityCoin().alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            Text(verbatim: unlit ? "—" : (place.rentPerVisit.map { "+\($0)" } ?? "—"))
                .cyText(.dataXL).foregroundStyle(palette.textPrimary)
            Text(verbatim: copy("每次到访", "per visit")).cyText(.caption).foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder private var holderOrPips: some View {
        if place.ownership == .open {
            Text(verbatim: copy("无人持有", "Unheld")).cyText(.caption).foregroundStyle(palette.textSecondary)
        } else {
            CityLevelPips(level: place.level, unknown: unlit)
        }
    }

    @ViewBuilder private var holderLine: some View {
        HStack(spacing: CYSpacing.sm) {
            switch place.ownership {
            case .mine:
                avatar(copy("我", "Me"), mine: true)
                Text(verbatim: heldDays.map { copy("你持有 · 第 \($0) 天", "Yours · day \($0)") } ?? copy("你持有", "Yours"))
            case .other:
                avatar(String((place.holderName ?? "?").prefix(1)), mine: false)
                Text(verbatim: copy("\(place.holderName ?? "玩家") 持有", "Held by \(place.holderName ?? "a player")"))
            case .open:
                Text(verbatim: copy("可圈地", "Claimable"))
            case .fogged:
                Text(verbatim: copy("走过去点亮它", "Walk there to light it"))
            }
            Spacer(minLength: 0)
            if let tag = statusTag { tag }
        }
        .cyText(.caption)
        .foregroundStyle(palette.textSecondary)
    }

    private func avatar(_ letter: String, mine: Bool) -> some View {
        Text(verbatim: letter).cyText(.caption, weight: .bold)
            .foregroundStyle(mine ? CityTokens.bandInk : palette.textPrimary)
            .frame(width: ownerAvatar, height: ownerAvatar)
            .background(mine ? CityTokens.mine : palette.bgRaised, in: Circle())
            .accessibilityHidden(true)
    }

    private var statusTag: CityStatusTag? {
        if place.isWeathered { return CityStatusTag(text: copy("风化", "Weathered"), symbol: "exclamationmark.triangle", tone: .warning) }
        if let until = place.protectedUntil, until > now {
            return CityStatusTag(text: copy("保护到 ", "Protected to ") + copy.clock(until, now: now), symbol: "lock", tone: .neutral)
        }
        if place.ownership == .other { return CityStatusTag(text: copy("可挑战", "Challengeable"), symbol: "bolt", tone: .ok) }
        return nil
    }

    @ViewBuilder private var trailingView: some View {
        switch trailing {
        case .today(let value):
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) { CityCoin(); Text(verbatim: "+\(value)").cyText(.cardTitle, monospacedDigit: true) }
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: copy("今天 · 每次 +\(place.rentPerVisit ?? 0)", "today · +\(place.rentPerVisit ?? 0)/visit"))
                    .cyText(.caption).foregroundStyle(palette.textSecondary)
            }
        case .status:
            if let tag = statusTag { tag } else { rentTrailing }
        case .price:
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) { CityCoin(); Text(verbatim: place.claimPrice.map(String.init) ?? "—").cyText(.cardTitle, monospacedDigit: true) }
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: copy("占领价", "Claim")).cyText(.caption).foregroundStyle(palette.textSecondary)
            }
        case .rent:
            rentTrailing
        }
    }

    private var rentTrailing: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) { CityCoin(); Text(verbatim: place.rentPerVisit.map { "+\($0)" } ?? "—").cyText(.cardTitle, monospacedDigit: true) }
                .foregroundStyle(palette.textPrimary)
            Text(verbatim: copy("每次到访", "per visit")).cyText(.caption).foregroundStyle(palette.textSecondary)
        }
    }

    private func outline(corner: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .strokeBorder(outlined ? palette.borderStrong : Color.clear, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
    }

    private var accessibilityText: String {
        var parts = [copy.title(place)]
        if let district = copy.district(place) { parts.append(district) }
        if !unlit, place.ownership != .open { parts.append(copy.level(place.level)) }
        if let rent = place.rentPerVisit, !unlit { parts.append(copy("每次到访 \(rent) 积分", "\(rent) points per visit")) }
        switch place.ownership {
        case .mine: parts.append(copy("你持有", "yours"))
        case .other: parts.append(copy("\(place.holderName ?? "玩家") 持有", "held by \(place.holderName ?? "a player")"))
        case .open: parts.append(copy("可圈地", "claimable"))
        case .fogged: parts.append(copy("未点亮", "unlit"))
        }
        if let tag = statusTag { parts.append(tag.text) }
        return parts.joined(separator: copy("，", ", "))
    }
}
