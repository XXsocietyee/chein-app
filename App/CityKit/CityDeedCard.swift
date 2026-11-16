import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// `City/Deed Card` (Figma 381:1401, skill-r2 SR2-42): the game's one signature object.
// Every field is real: name, district, level, rent per visit, holder and photo come from the
// server. The serial "地契 · No. N" is shown only when the server issues one (Q10); today it
// does not, so the band carries the district alone.

enum CityDeedSize { case full, sheet, row, mini }

extension CityPlace {
    /// The same place after a change of hands (moments show the new holder before the reload lands).
    func handedOver(to ownership: CityPlace.Ownership, level: Int? = nil, holder: String? = nil, protectedUntil: Date? = nil) -> CityPlace {
        CityPlace(id: id, title: title, coordinate: coordinate, territoryId: territoryId, poiId: poiId, boardId: boardId, pointId: pointId,
                  districtId: districtId, districtIndex: districtIndex, tier: tier, level: level ?? self.level, ownership: ownership,
                  holderName: holder, protectedUntil: protectedUntil, decay: ownership == .mine ? nil : decay, photoURL: photoURL,
                  radiusM: radiusM, distanceM: distanceM, invested: invested)
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
                .font(CYTypography.caption)
                .foregroundStyle(palette.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: unknown ? "—" : CityCopy(locale: locale).level(level)))
    }
}

/// The deed photo: the claim photo when the server has one, else the designed default (map glyph).
struct CityDeedPhoto: View {
    let url: String?
    var corner: CGFloat = 0
    @Environment(\.cyPalette) private var palette

    var body: some View {
        ZStack {
            palette.bgRaised
            Image(systemName: "map").font(.title2).foregroundStyle(palette.textTertiary)
            if let url, let parsed = URL(string: url), parsed.scheme == "https" {
                AsyncImage(url: parsed) { phase in
                    if case .success(let image) = phase { image.resizable().scaledToFill() }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .accessibilityHidden(true)
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

    private var copy: CityCopy { CityCopy(locale: locale) }
    private var unlit: Bool { place.ownership == .fogged }
    private var bandColor: Color { CityTokens.district(unlit ? 0 : place.districtIndex) }
    private var outlined: Bool { place.ownership == .open || unlit }

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
            CityDeedPhoto(url: place.photoURL).frame(height: 168).clipped()
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text(verbatim: copy.title(place)).font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                CityLevelPips(level: place.level, unknown: unlit || place.ownership == .open)
                rentLine
                Spacer(minLength: CYSpacing.sm)
                holderLine
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
            CityDeedPhoto(url: place.photoURL).frame(height: 88).clipped()
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: copy.title(place)).font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary).lineLimit(1)
                        Spacer(minLength: CYSpacing.sm)
                        holderOrPips
                    }
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: copy.title(place)).font(CYTypography.sectionTitle).foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                        holderOrPips
                    }
                }
                rentLine
            }
            .padding(CYSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.bgRaised.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(outline(corner: 16))
    }

    private var row: some View {
        HStack(spacing: CYSpacing.md) {
            CityDeedPhoto(url: place.photoURL, corner: 10).frame(width: 52, height: 52)
                .overlay(alignment: .top) { Rectangle().fill(bandColor).frame(height: 4).clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10)) }
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: copy.title(place)).font(CYTypography.cardTitle).foregroundStyle(palette.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                HStack(spacing: 6) {
                    Circle().fill(bandColor).frame(width: 7, height: 7).accessibilityHidden(true)
                    Text(verbatim: [copy.district(place), unlit ? nil : copy.level(place.level)].compactMap { $0 }.joined(separator: " "))
                        .font(CYTypography.caption).foregroundStyle(palette.textSecondary).lineLimit(1)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            trailingView
        }
        .padding(CYSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(outline(corner: 16))
    }

    private var mini: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(verbatim: copy.district(place) ?? copy("城市", "City"))
                .font(CYTypography.micro.weight(.semibold)).foregroundStyle(CityTokens.bandInk).lineLimit(1)
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background(bandColor)
            CityDeedPhoto(url: place.photoURL).frame(height: 58).clipped()
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: copy.title(place)).font(CYTypography.label.weight(.semibold)).foregroundStyle(palette.textPrimary).lineLimit(1)
                HStack(spacing: 4) {
                    CityCoin()
                    Text(verbatim: place.rentPerVisit.map { "+\($0) / " + copy("次", "visit") } ?? "—")
                        .font(CYTypography.caption.monospacedDigit()).foregroundStyle(palette.textSecondary).lineLimit(1)
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
            if let tier = copy.tier(place.tier), !unlit { Text(verbatim: tier) }
        }
        .font(CYTypography.caption.weight(.semibold))
        .foregroundStyle(unlit ? palette.textSecondary : CityTokens.bandInk)
        .padding(.horizontal, CYSpacing.md)
        .frame(maxWidth: .infinity, minHeight: bandHeight)
        .background(bandColor)
    }

    private var rentLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            CityCoin().alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
            Text(verbatim: unlit ? "—" : (place.rentPerVisit.map { "+\($0)" } ?? "—"))
                .font(CYTypography.dataXL.monospacedDigit()).foregroundStyle(palette.textPrimary)
            Text(verbatim: copy("每次到访", "per visit")).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
        }
    }

    @ViewBuilder private var holderOrPips: some View {
        if place.ownership == .open {
            Text(verbatim: copy("无人持有", "Unheld")).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
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
        .font(CYTypography.caption)
        .foregroundStyle(palette.textSecondary)
    }

    private func avatar(_ letter: String, mine: Bool) -> some View {
        Text(verbatim: letter).font(CYTypography.micro.weight(.bold))
            .foregroundStyle(mine ? CityTokens.bandInk : palette.textPrimary)
            .frame(width: 22, height: 22)
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
                HStack(spacing: 4) { CityCoin(); Text(verbatim: "+\(value)").font(CYTypography.cardTitle.monospacedDigit()) }
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: copy("今天 · 每次 +\(place.rentPerVisit ?? 0)", "today · +\(place.rentPerVisit ?? 0)/visit"))
                    .font(CYTypography.caption).foregroundStyle(palette.textSecondary)
            }
        case .status:
            if let tag = statusTag { tag } else { rentTrailing }
        case .price:
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) { CityCoin(); Text(verbatim: place.claimPrice.map(String.init) ?? "—").font(CYTypography.cardTitle.monospacedDigit()) }
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: copy("占领价", "Claim")).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
            }
        case .rent:
            rentTrailing
        }
    }

    private var rentTrailing: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: 4) { CityCoin(); Text(verbatim: place.rentPerVisit.map { "+\($0)" } ?? "—").font(CYTypography.cardTitle.monospacedDigit()) }
                .foregroundStyle(palette.textPrimary)
            Text(verbatim: copy("每次到访", "per visit")).font(CYTypography.caption).foregroundStyle(palette.textSecondary)
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
