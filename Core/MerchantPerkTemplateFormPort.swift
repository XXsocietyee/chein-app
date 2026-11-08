import Foundation

/// Port-2: form-side rules of pages/merchant/decor/perks that the native sheet lacked.
/// Pure presentation logic over `MerchantPerkTemplateDraft`; it never submits anything.
public enum MerchantPerkTemplateFormPort {
    public enum Field: String, Equatable { case name, retailValue, unitCost, quota, validEnd }

    /// Mini-program `save()` guard order: name, retail price, cost (optional), quota, validity (>= tomorrow, China date).
    public static func firstInvalidField(_ draft: MerchantPerkTemplateDraft, validEnd: String, now: Date) -> Field? {
        if draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .name }
        if MerchantPerkTemplateDraft.amount(draft.retailValue, allowZero: false) == nil { return .retailValue }
        let cost = draft.unitCost.trimmingCharacters(in: .whitespaces)
        if !cost.isEmpty, MerchantPerkTemplateDraft.amount(cost, allowZero: true) == nil { return .unitCost }
        let quota = draft.quota.trimmingCharacters(in: .whitespaces)
        if quota.isEmpty || !quota.allSatisfy({ $0.isASCII && $0.isNumber }) || (Int(quota) ?? 0) <= 0 { return .quota }
        let end = validEnd.trimmingCharacters(in: .whitespaces)
        if !end.isEmpty, (try? MerchantPerkValidityDraft.validateForCreation(end, now: now)) == nil { return .validEnd }
        return nil
    }

    /// Mini-program compares the serialized form with the snapshot taken when the form opened.
    public static func isDirty(_ draft: MerchantPerkTemplateDraft, validEndEnabled: Bool) -> Bool {
        draft != MerchantPerkTemplateDraft() || validEndEnabled
    }
}
