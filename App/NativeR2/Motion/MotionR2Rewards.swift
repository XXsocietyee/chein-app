import SwiftUI
import UIKit

// R1 stamp press, R2 spin-to-reveal holo card, R6 gift box with stickers.

// MARK: - R1 Stamp press + outline draw

/// A closed outline in a unit square (0…1). With no real boundary the outline is a seeded contour (stable per place
/// name), drawn like a postmark under the stamp; a real district boundary can be passed as normalized points.
struct MotionR2ContourShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        func map(_ point: CGPoint) -> CGPoint {
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }
        path.move(to: map(first))
        for point in points.dropFirst() { path.addLine(to: map(point)) }
        path.closeSubpath()
        return path
    }

    /// A wobbly closed contour, the same for the same `seed`.
    static func seeded(_ seed: String, count: Int = 32) -> [CGPoint] {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in seed.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        var points: [CGPoint] = []
        for index in 0..<count {
            let angle = Double(index) / Double(count) * 2 * Double.pi
            hash = hash &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let jitter = Double((hash >> 40) & 0xFF) / 255.0
            let radius = 0.36 + jitter * 0.12
            points.append(CGPoint(x: 0.5 + radius * cos(angle), y: 0.5 + radius * sin(angle)))
        }
        return points
    }
}

/// R1: the captured stamp presses onto the album page (ink press spring + heavy impact) and the place outline draws
/// itself under it. Reduce Motion / flag off: the stamp and the outline are shown at once. VoiceOver: one image
/// element "已盖章" (+ place) and an announcement when the press lands.
struct MotionR2StampPress: View {
    var imageData: Data? = nil
    var placeName: String? = nil
    var outline: [CGPoint]? = nil
    @State private var pressed = false
    @State private var drawn: CGFloat = 0
    @State private var thump = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var contour: [CGPoint] { outline ?? MotionR2ContourShape.seeded(placeName ?? "chengyin") }

    var body: some View {
        ZStack {
            MotionR2ContourShape(points: contour)
                .trim(from: 0, to: drawn)
                .stroke(Color.secondary, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
                .frame(width: 220, height: 180)
                .accessibilityHidden(true)
            stamp
                .scaleEffect(pressed ? 1 : 1.6)
                .rotationEffect(.degrees(pressed ? -4 : -14))
                .opacity(pressed ? 1 : 0)
                .shadow(color: .black.opacity(pressed ? 0.15 : 0.35), radius: pressed ? 2 : 12, y: pressed ? 1 : 8)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .sensoryFeedback(.impact(weight: .heavy), trigger: thump)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("motion2.stamp.press")
        .task { await run() }
    }

    private var label: Text {
        if let placeName, !placeName.isEmpty {
            return Text("motion2.stamp.pressed") + Text(verbatim: " · " + placeName)
        }
        return Text("motion2.stamp.pressed")
    }

    @ViewBuilder private var stamp: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image).resizable().scaledToFill().accessibilityHidden(true)
            } else {
                Image(systemName: "seal.fill").resizable().scaledToFit().padding(24).foregroundStyle(.tint).accessibilityHidden(true)
            }
        }
        .frame(width: 104, height: 130)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .padding(6)
        .background(.background, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
        }
    }

    private func run() async {
        guard !pressed else { return }
        guard MotionR2.live(reduceMotion: reduceMotion) else {
            pressed = true; drawn = 1
            MotionR2.announce("motion2.stamp.pressed")
            return
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(MotionR2.press) { pressed = true }
        try? await Task.sleep(for: .milliseconds(220))
        thump += 1
        MotionR2.announce("motion2.stamp.pressed")
        withAnimation(.easeInOut(duration: 1.2)) { drawn = 1 }
    }
}

// MARK: - R2 Spin to reveal

/// R2: a blob the player spins (drag sideways or tap 转一转); past half a turn it flips into a holographic reward card
/// that tilts with the phone. Reduce Motion / flag off: the card is shown at once, static. VoiceOver: the blob is a
/// button "翻开奖励"; the reveal announces "获得 <title>".
struct MotionR2RewardReveal: View {
    let title: String
    var subtitle: String? = nil
    var systemImage: String = "rosette"
    var tint: Color = .accentColor
    var onRevealed: (() -> Void)? = nil
    @State private var spin: Double = 0
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private var live: Bool { MotionR2.live(reduceMotion: reduceMotion) }

    var body: some View {
        Group {
            if revealed || !live {
                card
                    .transition(.asymmetric(insertion: .scale(scale: 0.6).combined(with: .opacity), removal: .opacity))
            } else {
                blob
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .sensoryFeedback(.success, trigger: revealed) { old, new in !old && new }
        .onAppear { if !live, !revealed { revealed = true; announce() } }
    }

    private var blob: some View {
        Button(action: reveal) {
            VStack(spacing: 12) {
                Circle()
                    .fill(AngularGradient(colors: [tint, .pink, .cyan, tint], center: .center, angle: .degrees(spin)))
                    .frame(width: 140, height: 140)
                    .blur(radius: 6)
                    .overlay { Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.white) }
                    .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
                Label("motion2.reward.spin", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(spinGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("motion2.reward.reveal"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { reveal() }
        .accessibilityIdentifier("motion2.reward.blob")
    }

    private var spinGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in spin = Double(value.translation.width) * 1.2 }
            .onEnded { _ in
                if abs(spin) > 180 { reveal() } else { withAnimation(MotionR2.spring) { spin = 0 } }
            }
    }

    private var card: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.largeTitle).imageScale(.large)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(verbatim: title).font(.title2.bold()).multilineTextAlignment(.center)
            if let subtitle, !subtitle.isEmpty {
                Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .frame(width: 240, height: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CYRadius.hero, style: .continuous)
                .strokeBorder(LinearGradient(colors: [tint, .cyan, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                              lineWidth: 2)
        }
        .motionR2HoloSheen(cornerRadius: CYRadius.hero)
        .motionR2Tilt()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("motion2.reward.card")
    }

    private func reveal() {
        guard !revealed else { return }
        if live {
            withAnimation(.smooth(duration: 0.45)) { spin = spin >= 0 ? 360 : -360 }
            withAnimation(MotionR2.spring.delay(0.3)) { revealed = true }
        } else {
            revealed = true
        }
        announce()
        onRevealed?()
    }

    private func announce() {
        MotionR2.announce(verbatim: appLocalized("motion2.reward.got", locale: locale) + " " + title)
    }
}

// MARK: - R6 Gift box with stickers

/// R6: a gift box that wiggles, then stickers pop onto it one by one. Reduce Motion / flag off: the box with its
/// stickers, static. VoiceOver: one element with `label` (e.g. 收到一份礼物).
struct MotionR2GiftBox: View {
    var label: LocalizedStringKey = "motion2.gift.received"
    var stickers: [String] = ["star.fill", "heart.fill", "seal.fill"]
    var tint: Color = .pink
    @State private var wiggle = 0
    @State private var shown = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var live: Bool { MotionR2.live(reduceMotion: reduceMotion) }
    private let offsets: [CGSize] = [CGSize(width: -34, height: -26), CGSize(width: 30, height: -8), CGSize(width: -8, height: 30),
                                     CGSize(width: 36, height: 30)]

    var body: some View {
        ZStack {
            box
            ForEach(Array(stickers.prefix(offsets.count).enumerated()), id: \.offset) { index, symbol in
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.yellow, tint)
                    .padding(6)
                    .background(Circle().fill(.background))
                    .offset(offsets[index])
                    .scaleEffect(index < shown ? 1 : 0.1)
                    .opacity(index < shown ? 1 : 0)
                    .rotationEffect(.degrees(Double(index * 17 % 30) - 15))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(.isImage)
        .accessibilityIdentifier("motion2.gift.box")
        .task { await run() }
    }

    @ViewBuilder private var box: some View {
        let image = Image(systemName: "gift.fill").font(.largeTitle).imageScale(.large).foregroundStyle(tint).accessibilityHidden(true)
        if #available(iOS 18, *), live {
            image.symbolEffect(.wiggle, value: wiggle)
        } else if live {
            image.keyframeAnimator(initialValue: 0.0, trigger: wiggle) { content, angle in
                content.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                KeyframeTrack {
                    SpringKeyframe(-8, duration: 0.12)
                    SpringKeyframe(8, duration: 0.12)
                    SpringKeyframe(-5, duration: 0.12)
                    SpringKeyframe(0, duration: 0.2)
                }
            }
        } else {
            image
        }
    }

    private func run() async {
        guard live else { shown = stickers.count; return }
        try? await Task.sleep(for: .milliseconds(200))
        wiggle += 1
        try? await Task.sleep(for: .milliseconds(500))
        for _ in stickers.prefix(offsets.count) {
            withAnimation(MotionR2.press) { shown += 1 }
            try? await Task.sleep(for: .milliseconds(180))
        }
    }
}

#Preview("Motion r2 rewards") {
    ScrollView {
        MotionR2StampPress(placeName: "黄浦区")
        MotionR2RewardReveal(title: "城市漫游家", subtitle: "完成 10 次自由探索")
        MotionR2GiftBox()
    }
}
