import SwiftUI

/// Circular progress ring with centred content. `progress` is 0...1; pass nil to draw only the dim track (unknown, never a fake value).
struct CYProgressRing<Center: View>: View {
    let progress: Double?
    var lineWidth: CGFloat = 10
    var tint: Color = CYColor.textPrimary
    var track: Color = CYColor.bgRaised
    @ViewBuilder let center: () -> Center
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false
    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            if let progress {
                Circle().trim(from: 0, to: shown || reduceMotion ? min(max(progress, 0), 1) : 0)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            center()
        }
        .padding(lineWidth / 2)
        .onAppear { withAnimation(.spring(response: 0.9, dampingFraction: 0.85)) { shown = true } }
    }
}

/// Foil medal frame: metallic angular-gradient rim, soft glow and a dark face. Locked medals get a dashed dim rim and no glow.
struct CYFoilMedal<Face: View>: View {
    let unlocked: Bool
    var size: CGFloat = 200
    var tint: Color = Color(hue: 0.12, saturation: 0.7, brightness: 0.95)
    @ViewBuilder let face: () -> Face
    var body: some View {
        ZStack {
            if unlocked {
                Circle().fill(RadialGradient(colors: [tint.opacity(0.55), .clear], center: .center, startRadius: size * 0.25, endRadius: size * 0.85))
                    .frame(width: size * 1.7, height: size * 1.7)
            }
            Circle().fill(CYColor.bgElevated)
                .frame(width: size, height: size)
            face().frame(width: size * 0.88, height: size * 0.88).clipShape(Circle())
                .saturation(unlocked ? 1 : 0).opacity(unlocked ? 1 : 0.45)
            if unlocked {
                Circle().strokeBorder(AngularGradient(colors: [.white, tint, Color(hue: 0.08, saturation: 0.8, brightness: 0.6), .white, tint, .white],
                                                      center: .center), lineWidth: size * 0.07)
                    .frame(width: size, height: size)
            } else {
                Circle().strokeBorder(CYColor.borderStrong, style: StrokeStyle(lineWidth: 3, dash: [6, 6]))
                    .frame(width: size, height: size)
                Image(systemName: "lock.fill").font(.system(size: size * 0.2, weight: .semibold))
                    .foregroundStyle(CYColor.textSecondary)
                    .padding(10).background(.ultraThinMaterial, in: Circle())
                    .offset(x: size * 0.34, y: size * 0.34)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Art cover header for Form/List pages that have no photo: generated gradient + symbol, big title, optional subtitle and chips.
/// Drop it as the first element of a List/Form via `CYCoverHeaderSection`.
struct CYArtCoverHeader<Chips: View>: View {
    let title: Text
    var subtitle: Text? = nil
    let symbol: String
    var seed: String = ""
    @ViewBuilder let chips: () -> Chips
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Spacer(minLength: CYSpacing.xl)
            title.font(CYTypography.sectionTitle.weight(.bold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
            if let subtitle {
                subtitle.font(CYTypography.bodyCompact).foregroundStyle(.white.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            chips()
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .bottomLeading)
        .padding(CYSpacing.xl)
        .background {
            ZStack(alignment: .bottom) {
                CYCoverArt(seed: seed.isEmpty ? symbol : seed, symbol: symbol, cornerRadius: CYRadius.sheet)
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sheet, style: .continuous))
            }
        }
        .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
    }
}

/// First section of a List/Form: the art cover header with no row chrome.
struct CYCoverHeaderSection<Chips: View>: View {
    let title: Text
    var subtitle: Text? = nil
    let symbol: String
    var seed: String = ""
    @ViewBuilder let chips: () -> Chips
    var body: some View {
        Section {
            CYArtCoverHeader(title: title, subtitle: subtitle, symbol: symbol, seed: seed, chips: chips)
                .listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
        }
    }
}
extension CYCoverHeaderSection where Chips == EmptyView {
    init(_ title: Text, subtitle: Text? = nil, symbol: String, seed: String = "") {
        self.init(title: title, subtitle: subtitle, symbol: symbol, seed: seed) { EmptyView() }
    }
    init(_ title: LocalizedStringKey, subtitle: Text? = nil, symbol: String, seed: String = "") {
        self.init(title: Text(title), subtitle: subtitle, symbol: symbol, seed: seed) { EmptyView() }
    }
}
