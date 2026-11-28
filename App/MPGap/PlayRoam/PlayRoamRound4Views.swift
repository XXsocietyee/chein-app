import SwiftUI

/// Round-4 SwiftUI views for `play-roam` Gemini items:
/// `JSETTLE-r7-1` (完局优惠卡), `ROAM-13` (City strip header), `OCARDS-2` (Gatherable 40-item pile + grid fallback).

// MARK: - JSETTLE-r7-1: 完局优惠卡

public struct JourneyFinishOfferCardView: View {
    @Environment(\.locale) private var locale
    public let offer: JourneyFinishOffer
    public let purchaseGated: Bool
    public var onAppearTrack: () -> Void = {}
    public var onTapOffer: () -> Void = {}

    public init(
        offer: JourneyFinishOffer,
        purchaseGated: Bool = true,
        onAppearTrack: @escaping () -> Void = {},
        onTapOffer: @escaping () -> Void = {}
    ) {
        self.offer = offer
        self.purchaseGated = purchaseGated
        self.onAppearTrack = onAppearTrack
        self.onTapOffer = onTapOffer
    }

    public var body: some View {
        Button(action: onTapOffer) {
            HStack(spacing: CYSpacing.md) {
                // MP settle wxml:33 `cy-icon coupon` (40 rpx): the shipped coupon art (MP assets).
                MPAsset.FeatureIcon.coupon.resizable().scaledToFit().frame(width: 28, height: 28).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    Text(offer.kind == .pass ? "finishOffer.passBadge" : "finishOffer.productBadge")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.brand)
                    Text(offer.name)
                        .cyText(.cardTitle)
                        .foregroundStyle(CYColor.textPrimary)
                    if purchaseGated {
                        Text("finishOffer.gatedNote")
                            .cyText(.meta)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
                Spacer()
                Text(verbatim: LocaleDisplay.yuanAmounts(in: offer.priceText, locale: locale))
                    .cyText(.sectionTitle, monospacedDigit: true)
                    .foregroundStyle(CYColor.brand)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
            }
            .padding(CYSpacing.md)
            .frame(minHeight: 44)
            .background(CYColor.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        // MP aria-label="{{offer.name}} {{offer.price}}".
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: offer.name + " " + LocaleDisplay.yuanAmounts(in: offer.priceText, locale: locale)))
        .accessibilityAddTraits(.isButton)
        .onAppear(perform: onAppearTrack)
    }
}

// MARK: - ROAM-13: City Strip Header & Live Ticket Caption

public struct RoamCityStripTabView: View {
    public let strip: RoamCityStripSummary
    public var onSelectCityStrip: () -> Void = {}

    public init(strip: RoamCityStripSummary, onSelectCityStrip: @escaping () -> Void = {}) {
        self.strip = strip
        self.onSelectCityStrip = onSelectCityStrip
    }

    public var body: some View {
        Button(action: onSelectCityStrip) {
            HStack {
                Text("附近活动 · \(strip.cityName)")
                    .cyText(.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                if strip.liveTeamsCount > 0 {
                    Text("\(strip.liveTeamsCount) 支队伍在线")
                        .cyText(.meta, monospacedDigit: true)
                        .foregroundStyle(CYColor.brand)
                }
                Image(systemName: "chevron.right")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
            .padding(CYSpacing.md)
            .background(CYColor.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - OCARDS-2: Object Cards Pile (40 items) + Grid Fallback for A11y / Reduce Motion

public struct ObjectCardPileAndGridView: View {
    public let items: [ObjectCardPileItem]
    public var onSelectItem: (ObjectCardPileItem) -> Void = { _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var isGathered = false
    @State private var dragOffsets: [String: CGSize] = [:]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: CYSpacing.sm), count: 3)

    public init(items: [ObjectCardPileItem], onSelectItem: @escaping (ObjectCardPileItem) -> Void = { _ in }) {
        self.items = items
        self.onSelectItem = onSelectItem
    }

    public var body: some View {
        let latest = Array(items.prefix(40))
        if reduceMotion || voiceOverEnabled {
            gridLayout(latest)
        } else {
            pileLayout(latest)
        }
    }

    private func gridLayout(_ items: [ObjectCardPileItem]) -> some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: CYSpacing.sm) {
                ForEach(items) { item in
                    cardTile(item)
                }
            }
            .padding(CYSpacing.md)
        }
    }

    private func pileLayout(_ items: [ObjectCardPileItem]) -> some View {
        ZStack {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let offset = dragOffsets[item.id] ?? .zero
                let baseX = isGathered ? 0 : CGFloat((index % 5) - 2) * 26
                let baseY = isGathered ? 0 : CGFloat((index / 5) - 3) * 28
                let angle = isGathered ? 0 : Double((index % 7) - 3) * 4.0

                cardTile(item)
                    .frame(width: 96, height: 120)
                    .offset(x: baseX + offset.width, y: baseY + offset.height)
                    .rotationEffect(.degrees(angle))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffsets[item.id] = value.translation
                            }
                            .onEnded { value in
                                withAnimation(.spring(duration: 0.3)) {
                                    dragOffsets[item.id] = CGSize(
                                        width: offset.width + value.translation.width * 0.4,
                                        height: offset.height + value.translation.height * 0.4
                                    )
                                }
                            }
                    )
            }
        }
        .frame(maxWidth: .infinity, minHeight: 380)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring(duration: 0.35)) {
                        isGathered.toggle()
                        if isGathered { dragOffsets.removeAll() }
                    }
                } label: {
                    // TODO: MPAsset.FeatureIcon.all (subpackageP3/images/cat/all.png)
                    Image(systemName: isGathered ? "square.grid.2x2" : "sparkles")
                }
                .accessibilityLabel(Text("objects.pile.gather"))
            }
        }
    }

    private func cardTile(_ item: ObjectCardPileItem) -> some View {
        Button {
            onSelectItem(item)
        } label: {
            VStack(spacing: CYSpacing.xs) {
                CYCachedAsyncImage(item.thumbnailURL, role: .shelf)
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                Text(item.title)
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textPrimary)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
            }
            .padding(CYSpacing.xs)
            .background(CYColor.bgSurface)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
