import Foundation

/// Client-side form rules for the invoice title editor, mirroring the mini-program
/// (subpackageMember/invoice-title-edit/index.js `canSubmit` and utils/user-invoice.js `titlePayload`):
/// name is trimmed and 1...100 characters; a COMPANY tax number is trimmed, upper-cased and must be
/// 15...20 characters of 0-9/A-Z; a PERSONAL title never carries a tax number.
/// The server stays the final validator; these rules only decide whether Save is offered and what is sent.
public enum InvoiceLaunchTitleRules {
    public static let maxNameLength = 100
    public static let taxLengths = 15...20
    public static func normalizedName(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines) }
    public static func normalizedTax(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    public static func isValidTax(_ raw: String) -> Bool {
        let tax = normalizedTax(raw)
        guard taxLengths.contains(tax.count) else { return false }
        return tax.unicodeScalars.allSatisfy { ($0.value >= 48 && $0.value <= 57) || ($0.value >= 65 && $0.value <= 90) }
    }
    public static func canSubmit(type: String, name: String, tax: String) -> Bool {
        let title = normalizedName(name)
        guard !title.isEmpty, title.count <= maxNameLength else { return false }
        switch type {
        case "PERSONAL": return true
        case "COMPANY": return isValidTax(tax)
        default: return false
        }
    }
    /// Builds the exact draft that is sent. Throws `.invalid` when the form must not be submitted.
    public static func draft(id: Int64?, type: String, name: String, tax: String, isDefault: Bool) throws -> InvoiceLaunchTitleDraft {
        guard canSubmit(type: type, name: name, tax: tax) else { throw InvoiceLaunchIssue.invalid }
        return try InvoiceLaunchTitleDraft(id: id, titleType: type, titleName: normalizedName(name),
            taxNo: type == "COMPANY" ? normalizedTax(tax) : nil, isDefault: isDefault)
    }
}
