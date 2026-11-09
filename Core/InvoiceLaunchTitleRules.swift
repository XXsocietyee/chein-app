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

/// subpackageMember/invoice-titles/index projection of the existing title list.
/// This type does not open a route and does not mark one live. A missing count,
/// a numeric string, or an unmasked tax echo is an em dash. A literal integer 0 stays "0".
public enum InvoiceLaunchTitlesPage {
    public static let unknownDisplay = "—"
    public static let routeMarkedLive = false

    public enum Phase: Equatable {
        case loading, empty, error, unknown, ready
    }

    public enum Copy {
        public static let loading = "loading"
        public static let empty = "noTitles"
        public static let error = "loadFailed"
        public static let unknown = "unknown"
        public static let unavailable = "unavailable"
        public static let titles = "titles"
        public static let readOnly = "titlesReadOnly"
        public static let checkResult = "checkResult"
        public static let retry = "retry"
        public static let add = "addTitle"
        public static let edit = "edit"
        public static let delete = "delete"
        public static let deleteConfirm = "deleteConfirm"
        public static let keep = "keep"
        public static let defaultTitle = "defaultTitle"
        public static let personal = "PERSONAL"
        public static let company = "COMPANY"
        public static let signInAction = "auth.wechat.signIn"
        public static let signIn = "invoice.titles.signIn"
        public static let pendingHold = "invoice.titles.pendingHold"
        public static let saveNotFound = "invoice.titles.saveNotFound"
        public static let deleteUnknown = "invoice.titles.deleteUnknown"
        public static let deleteFailed = "invoice.titles.deleteFailed"
        public static let deleteTitle = "invoice.titles.deleteTitle"
    }

    public struct Row: Equatable {
        public let id: Int64
        public let titleName: String
        public let typeKey: String
        public let taxText: String?
        public let showsDefault: Bool
        public let canEdit: Bool
        public let canDelete: Bool
    }

    public struct Facts: Equatable {
        public let phase: Phase
        public let countText: String
        public let rows: [Row]
        public let copyKey: String
        public let showsPendingSave: Bool
        public let pendingHoldKey: String?
        public let canQuerySave: Bool
        public let showsAdd: Bool
        public let canAdd: Bool
        public let readOnly: Bool
        public let readOnlyKey: String?
        public let readOnlyIdentifier: String?
        public let accessibilityIdentifier: String
    }

    public struct Input: Equatable {
        public var signedIn: Bool
        public var unavailable: Bool
        public var loading: Bool
        public var failed: Bool
        public var pendingSave: Bool
        public var pendingRequestKnown: Bool
        public var writing: Bool
        public var deletingID: Int64?
        public var allowsSave: Bool
        public var allowsDelete: Bool
        public var titles: [InvoiceLaunchTitle]?
        public init(signedIn: Bool = false, unavailable: Bool = false, loading: Bool = false,
                    failed: Bool = false, pendingSave: Bool = false, pendingRequestKnown: Bool = false,
                    writing: Bool = false, deletingID: Int64? = nil, allowsSave: Bool = false,
                    allowsDelete: Bool = false, titles: [InvoiceLaunchTitle]? = nil) {
            self.signedIn = signedIn
            self.unavailable = unavailable
            self.loading = loading
            self.failed = failed
            self.pendingSave = pendingSave
            self.pendingRequestKnown = pendingRequestKnown
            self.writing = writing
            self.deletingID = deletingID
            self.allowsSave = allowsSave
            self.allowsDelete = allowsDelete
            self.titles = titles
        }
    }

    public static func countText(_ count: Int?) -> String {
        guard let count else { return unknownDisplay }
        return String(count)
    }

    /// A numeric string is not a JSON number. `"0"` stays unknown.
    public static func countText(numericString _: String) -> String { unknownDisplay }

    public static func facts(_ input: Input) -> Facts {
        if !input.signedIn {
            return hidden(phase: .empty, copy: Copy.signIn, identifier: "invoice.titles.signIn")
        }
        if input.unavailable {
            return hidden(phase: .error, copy: Copy.unavailable, identifier: "invoice.titles.unavailable")
        }
        if input.loading, input.titles == nil {
            return slot(phase: .loading, copy: Copy.loading, identifier: "invoice.titles.loading",
                        count: unknownDisplay, rows: [], input: input, hasList: false)
        }
        if input.failed, input.titles == nil {
            return slot(phase: .error, copy: Copy.error, identifier: "invoice.titles.error",
                        count: unknownDisplay, rows: [], input: input, hasList: false)
        }
        guard let titles = input.titles else {
            return slot(phase: .unknown, copy: Copy.unknown, identifier: "invoice.titles.unknown",
                        count: unknownDisplay, rows: [], input: input, hasList: false)
        }
        let phase: Phase
        let copy: String
        let identifier: String
        if input.pendingSave {
            phase = .unknown
            copy = Copy.unknown
            identifier = "invoice.titles.unknown"
        } else if titles.isEmpty {
            phase = .empty
            copy = Copy.empty
            identifier = "invoice.titles.empty"
        } else {
            phase = .ready
            copy = Copy.titles
            identifier = "invoice.titles.ready"
        }
        return slot(phase: phase, copy: copy, identifier: identifier, count: countText(titles.count),
                    rows: titles.map { row($0, input: input) }, input: input, hasList: true)
    }

    private static func hidden(phase: Phase, copy: String, identifier: String) -> Facts {
        Facts(phase: phase, countText: unknownDisplay, rows: [], copyKey: copy,
              showsPendingSave: false, pendingHoldKey: nil, canQuerySave: false,
              showsAdd: false, canAdd: false, readOnly: false, readOnlyKey: nil,
              readOnlyIdentifier: nil, accessibilityIdentifier: identifier)
    }

    private static func slot(phase: Phase, copy: String, identifier: String, count: String,
                             rows: [Row], input: Input, hasList: Bool) -> Facts {
        let pending = input.pendingSave
        let readOnly = hasList && !pending && !input.loading && !input.failed && !input.allowsSave
        return Facts(phase: phase, countText: count, rows: rows, copyKey: copy,
                     showsPendingSave: pending, pendingHoldKey: pending ? Copy.pendingHold : nil,
                     canQuerySave: pending && input.pendingRequestKnown && !input.writing,
                     showsAdd: hasList, canAdd: hasList && !input.writing && !pending && input.allowsSave,
                     readOnly: readOnly, readOnlyKey: readOnly ? Copy.readOnly : nil,
                     readOnlyIdentifier: readOnly ? "invoice.titlesReadOnly" : nil,
                     accessibilityIdentifier: identifier)
    }

    private static func row(_ title: InvoiceLaunchTitle, input: Input) -> Row {
        let typeKey: String
        switch title.titleType {
        case Copy.personal, Copy.company: typeKey = title.titleType
        default: typeKey = unknownDisplay
        }
        let trimmed = title.titleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let editable = input.allowsSave && !input.pendingSave && !input.writing
        let deletable = input.allowsDelete && !input.writing && input.deletingID != title.id
        return Row(id: title.id, titleName: trimmed.isEmpty ? unknownDisplay : title.titleName,
                   typeKey: typeKey, taxText: taxText(title.taxNoMasked), showsDefault: title.isDefault,
                   canEdit: editable, canDelete: deletable)
    }

    /// Empty stays omitted. A contract mask is kept. Anything else is unknown, never the raw value.
    private static func taxText(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return InvoiceLaunchWire.masked(raw) ? raw : unknownDisplay
    }
}
