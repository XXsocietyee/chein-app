import SwiftUI

/// Night-city board for the W20 resident CITY business game: ring of property tiles, turn HUD,
/// dice, held-property tokens and a closing verdict. Pure presentation over `CityGameSnapshot`
/// facts. It never rolls, scores or decides anything locally: the die only shows a face the
/// server gave it (`face`), and unknown renders as an em dash. Other teams' tokens and
/// locations are never drawn (W20.17). Spec: specs/design-wave3.md (lantern = what you hold).

// MARK: - Turn HUD

/// Round number, action pips and the die in one night-glass strip.
struct CYCityTurnHUD: View {
    let roundSeq: Int64?
    let actionsRemaining: Int?
    let actionsPerRound: Int?
    /// Server-provided face (1...6) of the last roll; nil shows an unknown face.
    let face: Int?
    let rolling: Bool
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        HStack(spacing: CYSpacing.lg) {
            CYCityDie(face: face, rolling: rolling)
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text("cityGame.hud.round", tableName: "CityGame").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                Text(verbatim: roundSeq.map { String($0) } ?? "—")
                    .cyText(.dataXL).monospacedDigit()
                    .foregroundStyle(CYColor.textPrimary).contentTransition(.numericText())
                pips
            }
            Spacer(minLength: 0)
        }
        .padding(CYSpacing.lg)
        .background(nightGlass)
        .cyAnimation(CYMotion.standard, value: actionsRemaining)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cityGame.hud")
    }

    @ViewBuilder private var pips: some View {
        if let remaining = actionsRemaining, let total = actionsPerRound, total > 0, total <= 12 {
            HStack(spacing: 5) {
                ForEach(0..<total, id: \.self) { index in
                    Circle().fill(index < remaining ? CYNight.lantern : CYNight.ink2)
                        .frame(width: 9, height: 9)
                        .shadow(color: index < remaining ? CYNight.lantern.opacity(0.6) : .clear, radius: 4)
                }
            }.accessibilityHidden(true)
        } else {
            Text(verbatim: "—").cyText(.caption).foregroundStyle(CYColor.textTertiary)
        }
    }

    private var nightGlass: some View {
        RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.ink1)
            .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.glassFill))
            .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
                .strokeBorder(LinearGradient(colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom], startPoint: .top, endPoint: .bottom), lineWidth: 1))
    }
}

// MARK: - Die

/// One die. Tumbles while `rolling`, settles on `face`. Reduce Motion replaces the tumble with a
/// cross-fade; a nil face is an unknown value (em dash), never a default pip count.
struct CYCityDie: View {
    let face: Int?
    let rolling: Bool
    @QuestifyReduceMotion private var reduceMotion
    @State private var spin = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(CYNight.ink2)
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
            if let face, (1...6).contains(face) {
                pipGrid(face).transition(.opacity)
            } else if let face {
                Text(verbatim: String(face)).cyText(.dataXL).lineLimit(1).minimumScaleFactor(0.4).foregroundStyle(CYColor.textPrimary)
            } else {
                Text(verbatim: "—").cyText(.dataXL).lineLimit(1).minimumScaleFactor(0.4).foregroundStyle(CYColor.textTertiary)
            }
        }
        .frame(width: 56, height: 56)
        .rotation3DEffect(.degrees(rolling && !reduceMotion ? (spin ? 360 : 0) : 0), axis: (x: 1, y: 1, z: 0))
        .rotationEffect(.degrees(rolling && !reduceMotion ? (spin ? 20 : -20) : 0))
        .opacity(rolling && reduceMotion ? 0.55 : 1)
        .animation(rolling && !reduceMotion ? .linear(duration: 0.7).repeatForever(autoreverses: false) : CYMotion.resolve(CYMotion.release, reduceMotion: reduceMotion), value: spin)
        .animation(CYMotion.resolve(CYMotion.entrance, reduceMotion: reduceMotion), value: face)
        .onChange(of: rolling) { _, isRolling in spin = isRolling }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("cityGame.dice.label", tableName: "CityGame"))
        .accessibilityValue(face.map { Text(verbatim: String($0)) } ?? Text("cityGame.value.unavailable", tableName: "CityGame"))
        .accessibilityIdentifier("cityGame.dice")
    }

    private func pipGrid(_ value: Int) -> some View {
        let on: Set<Int> = {
            switch value {
            case 1: return [4]
            case 2: return [0, 8]
            case 3: return [0, 4, 8]
            case 4: return [0, 2, 6, 8]
            case 5: return [0, 2, 4, 6, 8]
            default: return [0, 2, 3, 5, 6, 8]
            }
        }()
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                GridRow {
                    ForEach(0..<3, id: \.self) { column in
                        Circle().fill(on.contains(row * 3 + column) ? CYNight.lanternHot : .clear).frame(width: 8, height: 8)
                    }
                }
            }
        }
    }
}

// MARK: - Ring board

/// Properties laid out around a rounded-rectangle track in server order. Selection is one ring that
/// slides between tiles (matched geometry); a lit lantern token marks what your team holds.
struct CYCityBoardRing: View {
    let properties: [CityPropertyState]
    let title: (CityPropertyState) -> String
    @Binding var selection: String?
    @Namespace private var ring
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let tile = tileSize(count: properties.count, in: size)
            let points = Self.track(count: properties.count, in: size, inset: tile / 2 + 2)
            ZStack {
                RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous)
                    .strokeBorder(CYNight.indigo, style: StrokeStyle(lineWidth: 1, dash: [3, 6]))
                    .padding(tile / 2 + 2).accessibilityHidden(true)
                ForEach(Array(properties.enumerated()), id: \.element.id) { index, property in
                    tileView(property, size: tile, selected: selection == property.id)
                        .position(points[index])
                }
                if let selection, let index = properties.firstIndex(where: { $0.id == selection }) {
                    RoundedRectangle(cornerRadius: tile * 0.3, style: .continuous)
                        .strokeBorder(CYNight.lantern, lineWidth: 2)
                        .frame(width: tile + 8, height: tile + 8)
                        .matchedGeometryEffect(id: "selection", in: ring)
                        .position(points[index]).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
            .frame(width: size.width, height: size.height)
            .animation(CYMotion.resolve(CYMotion.entrance, reduceMotion: reduceMotion), value: selection)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cityGame.board")
    }

    @ViewBuilder private func tileView(_ property: CityPropertyState, size: CGFloat, selected: Bool) -> some View {
        let lit = property.heldByMyTeam
        Button { selection = property.id } label: {
            ZStack {
                if lit { Circle().fill(CYNight.glow(radius: size / 2)).frame(width: size * 2, height: size * 2).allowsHitTesting(false) }
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(fill(property))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous).strokeBorder(lit ? CYNight.lantern.opacity(0.8) : CYNight.glassEdgeTop, lineWidth: 1))
                Image(systemName: symbol(property)).font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(lit ? CYNight.ink0 : CYColor.textSecondary)
                if lit {
                    Circle().fill(CYNight.lanternHot).frame(width: size * 0.26, height: size * 0.26)
                        .overlay(Circle().strokeBorder(CYNight.ink0, lineWidth: 1.5))
                        .offset(x: size * 0.34, y: -size * 0.34)
                }
            }
            .frame(width: size, height: size)
            .scaleEffect(selected && !reduceMotion ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .opacity(property.status == .paused ? 0.55 : 1)
        .accessibilityLabel(Text(verbatim: title(property)))
        .accessibilityValue(statusKey(property))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("cityGame.tile.\(property.propertyId)")
    }

    private func fill(_ property: CityPropertyState) -> Color {
        if property.heldByMyTeam { return CYNight.lantern }
        switch property.status {
        case .safetyBlocked: return CYColor.dangerText.opacity(0.25)
        case .held, .protected: return CYNight.indigo
        case .paused, .available: return CYNight.ink2
        }
    }

    private func symbol(_ property: CityPropertyState) -> String {
        if property.role == .neutral { return "flag.fill" }
        switch property.status {
        case .available: return "building.2.fill"
        case .held: return property.heldByMyTeam ? "building.2.crop.circle.fill" : "building.2.fill"
        case .protected: return "shield.fill"
        case .paused: return "pause.fill"
        case .safetyBlocked: return "exclamationmark.triangle.fill"
        }
    }

    private func statusKey(_ property: CityPropertyState) -> Text {
        switch property.status {
        case .available: return Text("cityGame.status.available", tableName: "CityGame")
        case .held: return Text("cityGame.status.held", tableName: "CityGame")
        case .protected: return Text("cityGame.status.protected", tableName: "CityGame")
        case .paused: return Text("cityGame.status.paused", tableName: "CityGame")
        case .safetyBlocked: return Text("cityGame.status.safetyBlocked", tableName: "CityGame")
        }
    }

    private func tileSize(count: Int, in size: CGSize) -> CGFloat {
        guard count > 0 else { return 44 }
        let perimeter = 2 * (size.width + size.height)
        return max(34, min(52, perimeter / CGFloat(count) - 6))
    }

    /// Evenly spaced points walking the perimeter of the inset rectangle, clockwise from the top-left.
    static func track(count: Int, in size: CGSize, inset: CGFloat) -> [CGPoint] {
        guard count > 0 else { return [] }
        let width = max(size.width - 2 * inset, 1), height = max(size.height - 2 * inset, 1)
        let perimeter = 2 * (width + height)
        return (0..<count).map { index in
            var distance = perimeter * CGFloat(index) / CGFloat(count)
            if distance < width { return CGPoint(x: inset + distance, y: inset) }
            distance -= width
            if distance < height { return CGPoint(x: inset + width, y: inset + distance) }
            distance -= height
            if distance < width { return CGPoint(x: inset + width - distance, y: inset + height) }
            distance -= width
            return CGPoint(x: inset, y: inset + height - distance)
        }
    }
}

// MARK: - Verdict

/// Shown once the board is closed or archived: what the team ended with, as server facts only.
struct CYCityVerdict: View {
    let held: Int
    let holdingLimit: Int?
    let points: Int64?
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: CYSpacing.md) {
            Text("cityGame.verdict.title", tableName: "CityGame").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary)
            HStack(spacing: CYSpacing.xl) {
                figure(holdingLimit.map { "\(held) / \($0)" } ?? String(held), key: "cityGame.rules.holdings")
                figure(points.map { String($0) } ?? "—", key: "cityGame.points.balance")
            }
            Text("cityGame.verdict.detail", tableName: "CityGame").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity).padding(CYSpacing.lg)
        .background(ZStack {
            RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.ink1)
            Circle().fill(CYNight.glow(radius: 90)).frame(width: 220, height: 220).offset(y: -40).opacity(held > 0 ? 1 : 0)
        }.clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)))
        .scaleEffect(shown || reduceMotion ? 1 : 0.96).opacity(shown ? 1 : 0)
        .onAppear { withAnimation(CYMotion.resolve(CYMotion.entrance, reduceMotion: reduceMotion)) { shown = true } }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cityGame.verdict")
    }

    private func figure(_ value: String, key: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value).cyText(.dataXL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
            Text(key, tableName: "CityGame").cyText(.caption).foregroundStyle(CYColor.textTertiary)
        }
    }
}
