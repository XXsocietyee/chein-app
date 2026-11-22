import Foundation

/// Parity customer-detail P1: named tag colours instead of a hex text field. Values match the server rule
/// `^#[0-9A-F]{6}$`; the first entry family includes the existing batch-tag default.
public enum MerchantTagColorPalette {
    public struct Entry: Equatable { public let hex: String; public let titleKey: String }
    public static let entries: [Entry] = [
        .init(hex: "#E5484D", titleKey: "merchant.tagColor.red"), .init(hex: "#F76B15", titleKey: "merchant.tagColor.orange"),
        .init(hex: "#FFC53D", titleKey: "merchant.tagColor.yellow"), .init(hex: "#30A46C", titleKey: "merchant.tagColor.green"),
        .init(hex: "#0090FF", titleKey: "merchant.tagColor.blue"), .init(hex: MerchantCustomerBatchTag.defaultColor, titleKey: "merchant.tagColor.teal"),
        .init(hex: "#8B8D98", titleKey: "merchant.tagColor.gray")]
}
