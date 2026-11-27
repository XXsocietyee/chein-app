import SwiftUI

/// JSEAT-r8-1 (MP seats wxml:66-83, DEC-F12 B): 转赠第 N 席 by phone. 称呼 (1–20 characters) + 手机号 (mainland
/// mobile; +86 / 0086 / spaces / dashes allowed), field errors under each field, one 确认转赠 primary.
/// The write is injected (`submit`); nil keeps every 转赠给同伴 row hidden. The phone number lives only in this sheet.
enum JourneySeatTransferForm {
    /// MP `journey-view.normalizePhone`: strip spaces, dashes and brackets, drop +86 / 0086 / 86 prefixes, then 1[3-9]xxxxxxxxx.
    static func normalizePhone(_ raw: String) -> String? {
        var digits = raw.filter { !" -()（）".contains($0) }
        if digits.hasPrefix("+86") { digits.removeFirst(3) }
        else if digits.hasPrefix("0086") { digits.removeFirst(4) }
        else if digits.count == 13, digits.hasPrefix("86") { digits.removeFirst(2) }
        let chars = Array(digits)
        guard chars.count == 11, chars[0] == "1", let second = chars[1].wholeNumberValue, second >= 3,
              chars.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return digits
    }
    /// MP `transferErrors`: 请填写称呼 / 最多 20 个字; 手机号格式不对.
    static func nameError(_ name: String) -> LocalizedStringKey? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "mp.seats.transfer.nameRequired" }
        return trimmed.count > 20 ? "mp.seats.transfer.nameTooLong" : nil
    }
    static func phoneError(_ phone: String) -> LocalizedStringKey? {
        normalizePhone(phone) == nil ? "mp.seats.transfer.phoneInvalid" : nil
    }
}

/// Result of one transfer attempt; `failed(nil)` uses the MP fallback 转赠失败.
enum JourneySeatTransferOutcome: Equatable {
    case sent
    /// The answer was lost; the same request id is reused on the next tap (MP 结果还没确认，请再点一次).
    case unconfirmed
    case failed(String?)
}

struct JourneySeatTransferSheet: View {
    let seatNo: Int
    /// name (trimmed), normalized phone, request id → outcome.
    let submit: (String, String, String) async -> JourneySeatTransferOutcome
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var phone = ""
    @State private var nameError: LocalizedStringKey?
    @State private var phoneError: LocalizedStringKey?
    @State private var failure: Text?
    @State private var busy = false
    @State private var requestID: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("mp.seats.transfer.name", text: $name)
                        .textContentType(.name)
                        .onChange(of: name) { _, value in
                            if value.count > 20 { name = String(value.prefix(20)) }
                            requestID = nil; nameError = nil; failure = nil
                        }
                        .accessibilityIdentifier("journeySeats.transfer.name")
                    if let nameError { Text(nameError).cyText(.meta).foregroundStyle(CYColor.dangerText) }
                    TextField("mp.seats.transfer.phone", text: $phone)
                        .keyboardType(.phonePad).textContentType(.telephoneNumber)
                        .onChange(of: phone) { _, _ in requestID = nil; phoneError = nil; failure = nil }
                        .accessibilityIdentifier("journeySeats.transfer.phone")
                    if let phoneError { Text(phoneError).cyText(.meta).foregroundStyle(CYColor.dangerText) }
                }
                if let failure {
                    Section { failure.cyText(.meta).foregroundStyle(CYColor.dangerText) }
                }
                Section {
                    Button(action: confirm) {
                        HStack { Spacer(); CYBusyLabel(busy: busy) { Text("mp.seats.transfer.confirm") }; Spacer() }
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(busy)
                    .accessibilityIdentifier("journeySeats.transfer.confirm")
                }
                .listRowBackground(Color.clear)
            }
            .navigationTitle(Text("mp.seats.transfer.title \(seatNo)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action.cancel") { dismiss() }.disabled(busy)
                }
            }
        }
        .interactiveDismissDisabled(busy)
        .cySheet(detents: [.medium, .large])
    }

    private func confirm() {
        guard !busy else { return }
        nameError = JourneySeatTransferForm.nameError(name)
        phoneError = JourneySeatTransferForm.phoneError(phone)
        guard nameError == nil, phoneError == nil, let normalized = JourneySeatTransferForm.normalizePhone(phone) else { return }
        let id = requestID ?? "seatphone-" + UUID().uuidString.lowercased()
        requestID = id; busy = true; failure = nil
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            let outcome = await submit(trimmed, normalized, id)
            busy = false
            switch outcome {
            case .sent: requestID = nil; onDone(); dismiss()
            case .unconfirmed: failure = Text("mp.seats.transfer.unconfirmed")
            case .failed(let message):
                requestID = nil
                failure = message.map { Text(verbatim: $0) } ?? Text("mp.seats.transfer.failed")
            }
        }
    }
}
