import SwiftUI

// MARK: - Passport stamp seal and its grid → detail continuity (Kubai087 recipe 4)

/// The Passport stamp seal: earned = foil disc in this stamp's colour, locked = dashed ghost. The grid cell and the detail hero
/// draw the SAME seal (the detail at `scale` 2.2), so the zoom reads as the cell growing rather than a different picture.
struct CYStampSeal: View {
    let index: Int
    let earned: Bool
    /// Stroke widths and glyph grow with the seal; the grid uses 1, the detail hero 2.2.
    var scale: CGFloat = 1
    @Environment(\.cyPalette) private var palette

    /// One foil colour pair per stamp (by index), so a collection reads as distinct seals.
    static let foils: [(Color, Color)] = [
        (Color(red: 1.00, green: 0.84, blue: 0.40), Color(red: 0.86, green: 0.55, blue: 0.16)),
        (Color(red: 0.62, green: 0.84, blue: 1.00), Color(red: 0.28, green: 0.52, blue: 0.92)),
        (Color(red: 0.62, green: 0.95, blue: 0.78), Color(red: 0.18, green: 0.64, blue: 0.48)),
        (Color(red: 1.00, green: 0.70, blue: 0.78), Color(red: 0.84, green: 0.30, blue: 0.48)),
        (Color(red: 0.88, green: 0.90, blue: 0.94), Color(red: 0.50, green: 0.55, blue: 0.64)),
        (Color(red: 1.00, green: 0.78, blue: 0.60), Color(red: 0.88, green: 0.42, blue: 0.24)),
    ]
    static func foil(_ index: Int) -> (Color, Color) { foils[((index % foils.count) + foils.count) % foils.count] }

    var body: some View {
        let foil = Self.foil(index)
        ZStack {
            if earned {
                Circle().fill(LinearGradient(colors: [foil.0, foil.1], startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().strokeBorder(LinearGradient(colors: [.white.opacity(0.85), foil.1.opacity(0.6)], startPoint: .top, endPoint: .bottom), lineWidth: 2 * scale)
                Circle().strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: scale, dash: [2 * scale, 3 * scale])).padding(6 * scale)
                Image(systemName: "seal.fill")
                    .accessibilityHidden(true).font(.title3.weight(.semibold))
                    .scaleEffect(scale)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 2 * scale, y: scale)
            } else {
                Circle().strokeBorder(palette.textTertiary, style: StrokeStyle(lineWidth: 1.5 * scale, dash: [4 * scale, 4 * scale]))
                Image(systemName: "seal").accessibilityHidden(true).font(.title3).scaleEffect(scale).foregroundStyle(palette.textTertiary)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The stamp the Passport grid hands to its detail. `earned` is read from the count at tap time, never guessed later.
struct CYPassportStampSelection: Hashable, Identifiable {
    let index: Int
    let earned: Bool
    var id: Int { index }
}

private struct CYOpenPassportStampKey: EnvironmentKey { static let defaultValue: ((CYPassportStampSelection) -> Void)? = nil }

extension EnvironmentValues {
    /// Set by `cyPassportStampHost()`. nil (previews, hosts without a stack) leaves the grid cells as plain pictures.
    var cyOpenPassportStamp: ((CYPassportStampSelection) -> Void)? {
        get { self[CYOpenPassportStampKey.self] }
        set { self[CYOpenPassportStampKey.self] = newValue }
    }
}

extension View {
    /// Apply inside a NavigationStack, outside any lazy container (List/Form/ScrollView content): owns the hero namespace, the
    /// selected stamp and the pushed `CYPassportStampDetailView`. Grid cells below zoom into it.
    func cyPassportStampHost() -> some View { modifier(CYPassportStampHost()) }
}

private struct CYPassportStampHost: ViewModifier {
    @Namespace private var hero
    @State private var selection: CYPassportStampSelection?
    func body(content: Content) -> some View {
        content
            .cyHeroNamespace(hero)
            .environment(\.cyOpenPassportStamp, { selection = $0 })
            .navigationDestination(item: $selection) { stamp in
                CYPassportStampDetailView(stamp: stamp)
                    .cyHeroDestinationWithFallback(stamp.index, in: hero)
            }
    }
}

/// Stamp detail: the seal at 2.2x under a large title, then what the stamp means. A locked slot says how to earn it.
struct CYPassportStampDetailView: View {
    let stamp: CYPassportStampSelection
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.xl) {
                CYStampSeal(index: stamp.index, earned: stamp.earned, scale: 3.2)
                    .frame(width: typeSize.isAccessibilitySize ? 160 : 64 * 2.2, height: typeSize.isAccessibilitySize ? 160 : 64 * 2.2)
                    .shadow(color: stamp.earned ? CYStampSeal.foil(stamp.index).1.opacity(0.45) : .clear, radius: 18, y: 8)
                    .accessibilityHidden(true)
                VStack(spacing: CYSpacing.sm) {
                    Text("passport.stamp.detail.title \(stamp.index + 1)")
                        .cyText(.sectionTitle)
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("passport.stamp.detail.title")
                        .cyHeroTitleRise()
                    Text(stamp.earned ? LocalizedStringKey("passport.stamp.detail.earned") : LocalizedStringKey("passport.stamp.detail.locked"))
                        .cyText(.body)
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("passport.stamp.detail.body")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.xxl)
        }
        .cyHeroZoomPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("passport.stamp.detail")
    }
}
