import Foundation

// MARK: Refund quote presentation (IWP-3; read-only, wires nothing)
// Maps the server's refund-quote `route` to a localization key and passes every server value through verbatim.
// There is no refund, ratio or money arithmetic in this file: the server decides, the client displays.
// The screen is a quote only. Applying a refund is a later work package.

public enum BundleRefundRoute: Equatable {
    case originalMethod
    case platformBalance
    case notRefundable
    /// Any route string this build does not know. Rendered as a neutral "see support" message.
    case unknown(String)

    public init(serverValue: String) {
        switch serverValue {
        case "ORIGINAL_METHOD": self = .originalMethod
        case "PLATFORM_BALANCE": self = .platformBalance
        case "NOT_REFUNDABLE": self = .notRefundable
        default: self = .unknown(serverValue)
        }
    }
}

public struct BundleRefundQuotePresentation: Equatable {
    /// Localization table used by `App/BundleRefundQuoteView.swift`.
    public static let tableName = "BundleRefundQuote"

    public let route: BundleRefundRoute
    /// Localization key for the route headline.
    public let routeTitleKey: String
    /// Localization key for the route explanation.
    public let routeBodyKey: String
    /// Server `amount`, exactly as returned.
    public let amountText: String
    /// Server `remainingRatio`, exactly as returned (no percent conversion).
    public let remainingRatioText: String
    /// Server `remainingValue`, exactly as returned.
    public let remainingValueText: String
    /// Server `totalValue`, exactly as returned.
    public let totalValueText: String
    /// Server `reason`, exactly as returned (Chinese backend text), or nil when blank.
    public let serverReason: String?
    public let policyVersion: String
    /// True when the server flags a merchant breach: the user is pointed to after-sales support.
    public let showsAfterSalesPointer: Bool
    /// Key of the after-sales pointer text, nil when the flag is false.
    public let afterSalesPointerKey: String?
    /// Always the same quote-only disclaimer key.
    public let quoteOnlyNoticeKey: String

    /// All localization keys this presentation can emit (for the strings document and tests).
    public static let allKeys: [String] = [
        "routeOriginalTitle", "routeOriginalBody",
        "routePlatformTitle", "routePlatformBody",
        "routeNotRefundableTitle", "routeNotRefundableBody",
        "routeUnknownTitle", "routeUnknownBody",
        "afterSalesPointer", "quoteOnlyNotice"
    ]

    public init(quote: FreeExploreLaunchRefundQuote) {
        route = BundleRefundRoute(serverValue: quote.route)
        switch route {
        case .originalMethod:
            routeTitleKey = "routeOriginalTitle"; routeBodyKey = "routeOriginalBody"
        case .platformBalance:
            routeTitleKey = "routePlatformTitle"; routeBodyKey = "routePlatformBody"
        case .notRefundable:
            routeTitleKey = "routeNotRefundableTitle"; routeBodyKey = "routeNotRefundableBody"
        case .unknown:
            routeTitleKey = "routeUnknownTitle"; routeBodyKey = "routeUnknownBody"
        }
        amountText = quote.amount.text
        remainingRatioText = quote.remainingRatio.text
        remainingValueText = quote.remainingValue.text
        totalValueText = quote.totalValue.text
        let trimmed = quote.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        serverReason = trimmed.isEmpty ? nil : quote.reason
        policyVersion = quote.policyVersion
        showsAfterSalesPointer = quote.afterSalesForMerchantBreach
        afterSalesPointerKey = quote.afterSalesForMerchantBreach ? "afterSalesPointer" : nil
        quoteOnlyNoticeKey = "quoteOnlyNotice"
    }
}
