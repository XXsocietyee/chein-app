import SwiftUI

// MARK: - Shared loading / offline / toast chrome (UI-10)
// Revolut pattern: calm skeletons, a quiet inline offline banner, a short bottom toast.
// Colours come only from CYColor; both light (merchant) and dark (player) schemes are supported.

// MARK: 1. Skeleton block

/// Placeholder block with a quiet shimmer. The shimmer is disabled under Reduce Motion.
public struct CYSkeletonBlock: View {
    private let cornerRadius: CGFloat
    private let height: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    public init(height: CGFloat = 16, cornerRadius: CGFloat = CYRadius.xs) {
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(CYColor.bgRaised)
            .frame(height: height)
            .opacity(isDimmed && !reduceMotion ? 0.55 : 1.0)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
            .accessibilityHidden(true)
    }
}

// MARK: 2. Loading state

/// Skeleton list shown while content loads. Announces one VoiceOver label instead of each block.
public struct CYLoadingStateView: View {
    private let rows: Int

    public init(rows: Int = 3) {
        self.rows = max(1, rows)
    }

    public var body: some View {
        VStack(spacing: CYSpacing.md) {
            ForEach(0..<rows, id: \.self) { _ in
                CYCard {
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        CYSkeletonBlock(height: 18)
                            .frame(maxWidth: 200)
                        CYSkeletonBlock(height: 12)
                        CYSkeletonBlock(height: 12)
                            .frame(maxWidth: 140)
                    }
                }
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("cy.state.loading"))
    }
}

// MARK: 3. Offline banner

/// Inline banner for "no connection". One optional retry action; text wraps at large Dynamic Type sizes.
public struct CYOfflineBanner: View {
    private let onRetry: (() -> Void)?

    public init(onRetry: (() -> Void)? = nil) {
        self.onRetry = onRetry
    }

    public var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            Image(systemName: "wifi.slash")
                .font(CYTypography.label)
                .foregroundStyle(CYColor.warningText)
                .accessibilityHidden(true)

            Text("cy.state.offline.title")
                .font(CYTypography.bodyCompact)
                .foregroundStyle(CYColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let onRetry {
                Button(action: onRetry) {
                    Text("cy.state.offline.retry")
                        .font(CYTypography.label)
                        .foregroundStyle(CYColor.accentText)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, CYSpacing.lg)
        .padding(.vertical, CYSpacing.xs)
        .background(CYColor.warningSoft)
        .accessibilityElement(children: .combine)
    }
}

// MARK: 4. Toast

private struct CYToastModifier: ViewModifier {
    @Binding var message: LocalizedStringKey?
    let duration: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .font(CYTypography.bodyCompact)
                    .foregroundStyle(CYColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, CYSpacing.lg)
                    .padding(.vertical, CYSpacing.md)
                    .background(
                        Capsule(style: .continuous).fill(CYColor.bgElevated)
                    )
                    .overlay(
                        Capsule(style: .continuous).strokeBorder(CYColor.borderStrong, lineWidth: 1)
                    )
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .padding(.bottom, CYSpacing.xxl)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
                    .task {
                        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                        guard !Task.isCancelled else { return }
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                            self.message = nil
                        }
                    }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: message != nil)
    }
}

public extension View {
    /// Shows a short bottom toast while `message` is non-nil, then clears it.
    func cyToast(message: Binding<LocalizedStringKey?>, duration: Double = 2.5) -> some View {
        modifier(CYToastModifier(message: message, duration: duration))
    }
}

// MARK: - Previews (synthetic, preview-only)

#Preview("Shared states - dark (player)") {
    VStack(spacing: CYSpacing.lg) {
        CYOfflineBanner(onRetry: {})
        CYLoadingStateView(rows: 2)
        Spacer()
    }
    .background(CYColor.bgPage)
    .preferredColorScheme(.dark)
}

#Preview("Shared states - light (merchant)") {
    VStack(spacing: CYSpacing.lg) {
        CYOfflineBanner(onRetry: {})
        CYLoadingStateView(rows: 2)
        Spacer()
    }
    .background(CYColor.bgPage)
    .preferredColorScheme(.light)
}
