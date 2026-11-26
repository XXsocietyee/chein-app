import SwiftUI

/// `PC-C-2-3` / `PC-C-2-4` / `PC-C-2-6`: Activity registration (`baoming`) child age picker,
/// delivery/pass/merchant-closed rows, and host reservation section.
public struct ActivityRegistrationGapSections: View {
    public let childAgeRange: ActivityChildAgeRange?
    @Binding public var selectedChildAge: Int?
    public let deliveryItems: [ActivityDeliveryItem]
    public let merchantClosed: Bool
    public let clubPriorityNotice: String?
    public let coveredByPass: Bool
    public let hostReservation: ActivityHostReservationState?
    public var isBusy: Bool = false
    public var onRequestHost: () -> Void = {}
    public var onCancelHostWaitlist: () -> Void = {}

    public init(
        childAgeRange: ActivityChildAgeRange? = nil,
        selectedChildAge: Binding<Int?> = .constant(nil),
        deliveryItems: [ActivityDeliveryItem] = [],
        merchantClosed: Bool = false,
        clubPriorityNotice: String? = nil,
        coveredByPass: Bool = false,
        hostReservation: ActivityHostReservationState? = nil,
        isBusy: Bool = false,
        onRequestHost: @escaping () -> Void = {},
        onCancelHostWaitlist: @escaping () -> Void = {}
    ) {
        self.childAgeRange = childAgeRange
        self._selectedChildAge = selectedChildAge
        self.deliveryItems = deliveryItems
        self.merchantClosed = merchantClosed
        self.clubPriorityNotice = clubPriorityNotice
        self.coveredByPass = coveredByPass
        self.hostReservation = hostReservation
        self.isBusy = isBusy
        self.onRequestHost = onRequestHost
        self.onCancelHostWaitlist = onCancelHostWaitlist
    }

    public var body: some View {
        Group {
            if merchantClosed {
                Section {
                    Label("registration.merchantClosed.banner", systemImage: "exclamationmark.triangle.fill")
                        .cyText(.bodyCompact)
                        .foregroundStyle(CYColor.textPrimary)
                }
            }

            if let range = childAgeRange {
                Section("registration.childAge.title") {
                    Picker("registration.childAge.title", selection: $selectedChildAge) {
                        Text("registration.childAge.placeholder").tag(Int?.none)
                        ForEach(range.options, id: \.self) { age in
                            Text("\(age) 岁").tag(Optional(age))
                        }
                    }
                    .cyText(.body)
                }
            }

            if coveredByPass || clubPriorityNotice != nil {
                Section("registration.benefits.title") {
                    if let priority = clubPriorityNotice, !priority.isEmpty {
                        LabeledContent("registration.clubPriority.label", value: priority)
                            .cyText(.bodyCompact)
                    }
                    if coveredByPass {
                        LabeledContent {
                            Text("registration.pass.covered")
                        } label: {
                            Text("registration.pass.label")
                        }
                        .cyText(.bodyCompact)
                    }
                }
            }

            if !deliveryItems.isEmpty {
                Section("registration.delivery.title") {
                    ForEach(deliveryItems) { item in
                        LabeledContent(item.label, value: item.value)
                            .cyText(.bodyCompact)
                    }
                }
            }

            if let resv = hostReservation, resv.isShown {
                Section("registration.hostResv.title") {
                    LabeledContent("registration.hostResv.status", value: resv.statusText)
                        .cyText(.bodyCompact)
                    if resv.awaitingPayment, let deadline = resv.paymentDeadlineText, !deadline.isEmpty {
                        LabeledContent("registration.hostResv.deadline", value: deadline)
                            .cyText(.bodyCompact)
                    }
                    if resv.canRequest {
                        Button("registration.hostResv.request", action: onRequestHost)
                            .buttonStyle(.bordered)
                            .disabled(isBusy)
                    }
                    if resv.canCancel {
                        Button("registration.hostResv.cancel", role: .destructive, action: onCancelHostWaitlist)
                            .disabled(isBusy)
                    }
                }
            }
        }
    }
}
