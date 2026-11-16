import SwiftUI
import UIKit

/// A native segmented control whose bounds start at 44pt and can grow with Dynamic Type.
@MainActor struct WalletEarningsAccessibleTabs: UIViewRepresentable {
    let tab: WalletEarningsTabHold.Tab
    let select: (WalletEarningsTabHold.Tab) -> Void
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var minimumHeight: CGFloat = 44

    func makeUIView(context: Context) -> WalletEarningsSegmentedControl {
        WalletEarningsSegmentedControl(items: ["", ""])
    }
    func updateUIView(_ control: WalletEarningsSegmentedControl, context: Context) {
        control.setTitle(String(localized: LocalizedStringResource("wallet.earnings.tab.income", table: "WalletEarningsOverview", locale: locale)), forSegmentAt: 0)
        control.setTitle(String(localized: LocalizedStringResource("wallet.earnings.tab.organizer", table: "WalletEarningsOverview", locale: locale)), forSegmentAt: 1)
        control.selectedSegmentIndex = tab == .income ? 0 : 1
        control.onSelect = { select($0 == 0 ? .income : .organizer) }
        control.refreshAccessibility()
    }
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WalletEarningsSegmentedControl, context: Context) -> CGSize? {
        let fitted = uiView.intrinsicContentSize
        return CGSize(width: proposal.width ?? fitted.width, height: max(minimumHeight, fitted.height))
    }
}

@MainActor final class WalletEarningsSegmentedControl: UISegmentedControl {
    var onSelect: ((Int) -> Void)?
    private var segments: [WalletEarningsSegmentAccessibility] = []
    override init(items: [Any]?) {
        super.init(items: items)
        isAccessibilityElement = false
        self.accessibilityIdentifier = "wallet.earnings.tabs"
        addTarget(self, action: #selector(changed), for: .valueChanged)
        segments = (0..<2).map { WalletEarningsSegmentAccessibility(control: self, index: $0) }
    }
    /// Once accessibility is active in the process (VoiceOver, Switch Control, XCUITest) UIKit's accessibility bundle
    /// replaces `UISegmentedControl.accessibilityElements` with its own per-segment elements, so a value assigned in
    /// `init` is dropped and the 44 pt elements and activation callback below disappear. Answer them from the subclass.
    override var accessibilityElements: [Any]? {
        get { segments }
        set {}
    }
    override func accessibilityElementCount() -> Int { segments.count }
    override func accessibilityElement(at index: Int) -> Any? { segments.indices.contains(index) ? segments[index] : nil }
    override func index(ofAccessibilityElement element: Any) -> Int {
        segments.firstIndex { $0 === element as AnyObject } ?? NSNotFound
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width, height: max(44, size.height))
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        refreshAccessibility()
    }
    @objc private func changed() {
        refreshAccessibility()
        onSelect?(selectedSegmentIndex)
    }
    func activateSegment(_ index: Int) -> Bool {
        guard isEnabled, isEnabledForSegment(at: index) else { return false }
        selectedSegmentIndex = index
        sendActions(for: .valueChanged)
        return true
    }
    func refreshAccessibility() {
        for (index, element) in segments.enumerated() {
            element.accessibilityLabel = titleForSegment(at: index)
            if index == 0 { element.accessibilityIdentifier = "wallet.earnings.tab.income" }
            else { element.accessibilityIdentifier = "wallet.earnings.tab.organizer" }
            element.accessibilityTraits = selectedSegmentIndex == index ? [.button, .selected] : [.button]
            if !isEnabled || !isEnabledForSegment(at: index) { element.accessibilityTraits.insert(.notEnabled) }
            let visualIndex = effectiveUserInterfaceLayoutDirection == .rightToLeft ? 1 - index : index
            element.accessibilityFrameInContainerSpace = CGRect(x: CGFloat(visualIndex) * bounds.width / 2, y: 0,
                                                                 width: bounds.width / 2, height: bounds.height)
        }
    }
}

@MainActor private final class WalletEarningsSegmentAccessibility: UIAccessibilityElement {
    private weak var control: WalletEarningsSegmentedControl?
    private let index: Int
    init(control: WalletEarningsSegmentedControl, index: Int) {
        self.control = control
        self.index = index
        super.init(accessibilityContainer: control)
    }
    override func accessibilityActivate() -> Bool { control?.activateSegment(index) ?? false }
}
