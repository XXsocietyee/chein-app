import SwiftUI

/// `RSTAMP-3`: Citystamp slip tear (`DragGesture`) + `Canvas` scratch-off mask (60% reveal gate)
/// matching `subpackageRoam/citystamp/index.wxml:93-136`.
/// Note: stamp create & exchange writes remain owner-gated (`mediaUploadEnabled`/`stampExchangeEnabled`).
public struct CityStampTearScratchCardView: View {
    public let slip: CityStampSlipData
    public let exchangeEnabled: Bool
    public var onSaveToAlbum: () -> Void = {}
    public var onComplete: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffsetY: CGFloat = 0
    @State private var isTorn = false
    @State private var scratchPoints: [CGPoint] = []
    @State private var isRevealed = false

    private let revealThreshold = 24

    public init(
        slip: CityStampSlipData,
        exchangeEnabled: Bool = false,
        onSaveToAlbum: @escaping () -> Void = {},
        onComplete: @escaping () -> Void = {}
    ) {
        self.slip = slip
        self.exchangeEnabled = exchangeEnabled
        self.onSaveToAlbum = onSaveToAlbum
        self.onComplete = onComplete
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: CYSpacing.lg) {
                slipCard
                    .offset(y: dragOffsetY)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                guard !isTorn else { return }
                                dragOffsetY = max(0, min(60, value.translation.height))
                            }
                            .onEnded { value in
                                if value.translation.height > 40 {
                                    withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
                                        isTorn = true
                                        dragOffsetY = 0
                                    }
                                } else {
                                    withAnimation(reduceMotion ? nil : .spring(duration: 0.2)) {
                                        dragOffsetY = 0
                                    }
                                }
                            }
                    )

                VStack(spacing: CYSpacing.sm) {
                    Button("citystamp.saveToAlbum", action: onSaveToAlbum)
                        .buttonStyle(.bordered)
                        .disabled(!isRevealed)

                    Button("citystamp.acceptAndGo", action: onComplete)
                        .buttonStyle(.borderedProminent)
                        .disabled(!isRevealed)
                }

                if !exchangeEnabled {
                    Text("citystamp.exchangeGated")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
            }
            .padding(CYSpacing.md)
        }
        .background(CYColor.bgPage)
    }

    private var slipCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text("citystamp.depart")
                        .cyText(.caption)
                        .foregroundStyle(CYColor.textSecondary)
                    Text(slip.place)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    Text(slip.timeLabel)
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: CYSpacing.xs) {
                    Text("citystamp.serial")
                        .cyText(.caption)
                        .foregroundStyle(CYColor.textSecondary)
                    Text(slip.serial)
                        .cyText(.sectionTitle, monospacedDigit: true)
                        .foregroundStyle(CYColor.textPrimary)
                }
            }

            Divider()

            HStack {
                LabeledContent("citystamp.sender", value: "这一站的某个人")
                Spacer()
                LabeledContent("citystamp.sentAt", value: slip.senderTime)
            }
            .cyText(.meta)

            if let urlStr = slip.photoURL, let url = URL(string: urlStr) {
                CYCachedAsyncImage(url: url, role: .cover)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }

            Divider()

            Text("citystamp.messageTitle")
                .cyText(.caption)
                .foregroundStyle(CYColor.textSecondary)

            ZStack {
                Text(slip.caption ?? "（这一位没留字，只留了一张照片）")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
                    .padding(CYSpacing.sm)

                if !isRevealed {
                    scratchOverlay
                }
            }
            .background(CYColor.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        }
        .padding(CYSpacing.md)
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
    }

    @ViewBuilder
    private var scratchOverlay: some View {
        if reduceMotion {
            Button("citystamp.tapToReveal") {
                isRevealed = true
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CYColor.bgSurfaceStrong)
        } else {
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(CYColor.bgSurfaceStrong))
                context.blendMode = .clear
                for pt in scratchPoints {
                    let rect = CGRect(x: pt.x - 16, y: pt.y - 16, width: 32, height: 32)
                    context.fill(Path(ellipseIn: rect), with: .color(.black))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        scratchPoints.append(value.location)
                        if scratchPoints.count >= revealThreshold {
                            isRevealed = true
                        }
                    }
            )
            .accessibilityLabel(Text("citystamp.scratchToReveal"))
            .accessibilityAction {
                isRevealed = true
            }
        }
    }
}
