import SwiftUI

// Map chrome for the immersive player screens (play / roam / search map). Presentation only:
// glass controls, the white GO circle, a persistent detent sheet and a static placeholder map
// used by debug fixtures and empty states. Real screens keep MapKit underneath.

/// Round 44pt (scaled) glass control floating over a map. Max three per screen (owner rule).
struct CYGlassButton: View {
    private let systemImage: String
    private let label: LocalizedStringKey
    private let action: () -> Void
    @ScaledMetric(relativeTo: .body) private var size: CGFloat = 48

    init(systemImage: String, label: LocalizedStringKey, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.label = label
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(.body).weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// Glass capsule container (search field, title pill, stat strip).
struct CYGlassCapsule<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(.horizontal, CYSpacing.lg)
            .frame(minHeight: 48)
            .background(.ultraThinMaterial, in: Capsule(style: .continuous))
            .overlay(Capsule(style: .continuous).strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
    }
}

/// The mini-program's white GO circle: the single primary action of a map screen.
struct CYGoButton: View {
    private let title: LocalizedStringKey
    private let action: () -> Void
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 96

    init(_ title: LocalizedStringKey = "GO", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.title, design: .default).weight(.heavy).italic())
                .minimumScaleFactor(0.6).lineLimit(1)
                .foregroundStyle(.black)
                .frame(width: size, height: size)
                .background(Color.white, in: Circle())
                .shadow(color: .black.opacity(0.35), radius: 16, y: 6)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Dark static stand-in for a map (roads, water, a fog vignette). Debug fixtures and offline state only.
struct CYMapPlaceholder: View {
    var fog = true
    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.075, blue: 0.085)
            Canvas { ctx, size in
                var water = Path()
                water.move(to: CGPoint(x: -20, y: size.height * 0.62))
                water.addCurve(to: CGPoint(x: size.width + 20, y: size.height * 0.30),
                               control1: CGPoint(x: size.width * 0.35, y: size.height * 0.78),
                               control2: CGPoint(x: size.width * 0.62, y: size.height * 0.20))
                ctx.stroke(water, with: .color(Color(red: 0.10, green: 0.18, blue: 0.26)), lineWidth: 34)
                let road = Color.white.opacity(0.10)
                for i in 0..<9 {
                    var p = Path()
                    let y = size.height * (0.06 + CGFloat(i) * 0.115)
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y + size.height * 0.05 * (i.isMultiple(of: 2) ? 1 : -1)))
                    ctx.stroke(p, with: .color(road), lineWidth: i.isMultiple(of: 3) ? 5 : 2)
                }
                for i in 0..<6 {
                    var p = Path()
                    let x = size.width * (0.08 + CGFloat(i) * 0.18)
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + size.width * 0.12, y: size.height))
                    ctx.stroke(p, with: .color(road), lineWidth: i.isMultiple(of: 2) ? 4 : 2)
                }
            }
            if fog {
                RadialGradient(colors: [.clear, .black.opacity(0.72)], center: .center, startRadius: 120, endRadius: 520)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Pin used by placeholder maps: white label callout like the mini-program search map.
struct CYMapCallout: View {
    let text: String
    var selected = false
    var body: some View {
        VStack(spacing: 0) {
            Text(verbatim: text)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.xs, style: .continuous).strokeBorder(Color.black.opacity(selected ? 0.9 : 0), lineWidth: 2))
            Image(systemName: "arrowtriangle.down.fill").font(.system(size: 9)).foregroundStyle(.white).offset(y: -1)
        }
    }
}

extension View {
    /// Persistent bottom sheet over a full-bleed map: detents, map stays interactive behind, never dismissed.
    /// Use for node / task / result information; the screen's primary action lives inside it.
    func cyMapSheet<Sheet: View>(
        isPresented: Binding<Bool>,
        detents: Set<PresentationDetent> = [.height(236), .medium, .large],
        @ViewBuilder content: @escaping () -> Sheet
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents(detents)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationCornerRadius(28)
                .presentationBackground(Color(red: 0.11, green: 0.11, blue: 0.118))
                .interactiveDismissDisabled()
        }
    }
}
