import SwiftUI

// MC7-02-5 (pages/merchant/apply/index.wxml:81-109, 253-300): the review timeline that the MP shows under the
// application status and on the submitted-result page. Native form: a plain list section, one row per step,
// with a status glyph (done / current / rejected / waiting) and the step's sub-line.

struct MerchantApplyTimelineStep: Identifiable, Equatable {
    enum State: Equatable { case done, current, rejected, waiting }
    let id: String
    let title: LocalizedStringKey
    let detail: Text
    let state: State

    static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id && lhs.state == rhs.state }

    /// MP merchant-identity-policy.js timelineClass / timelineText for an application read back from the server.
    static func status(_ application: MerchantOnboardingApplication) -> [MerchantApplyTimelineStep] {
        let disabled = application.accountStatus == 2
        let active = application.status == 1 && application.accountStatus == 1
        let rejected = application.status == 2
        let resultState: State = disabled || rejected ? .rejected : active ? .done : .waiting
        let resultKey: LocalizedStringKey = disabled ? "merchant.apply.timeline.result.disabled"
            : active ? "merchant.apply.timeline.result.active"
            : rejected ? "merchant.apply.timeline.result.rejected"
            : application.status == 1 ? "merchant.apply.timeline.result.identityPending"
            : "merchant.apply.timeline.waiting"
        return [
            .init(id: "submit", title: "merchant.apply.timeline.submit",
                  detail: application.createTime.isEmpty ? Text("merchant.apply.timeline.submitted") : Text(verbatim: application.createTime),
                  state: .done),
            .init(id: "review", title: "merchant.apply.timeline.review",
                  detail: application.status == 0 ? Text("merchant.apply.timeline.reviewing") : Text("merchant.apply.timeline.completed"),
                  state: application.status == 0 ? .current : .done),
            .init(id: "result", title: "merchant.apply.timeline.result", detail: Text(resultKey), state: resultState),
        ]
    }

    /// MP step 5 (提交成功): four steps, the first done and 资料初审 current.
    static let submitted: [MerchantApplyTimelineStep] = [
        .init(id: "submit", title: "merchant.apply.timeline.submit", detail: Text("merchant.apply.timeline.submitted"), state: .done),
        .init(id: "review", title: "merchant.apply.timeline.review", detail: Text("merchant.apply.timeline.reviewing"), state: .current),
        .init(id: "license", title: "merchant.apply.timeline.license", detail: Text("merchant.apply.timeline.waiting"), state: .waiting),
        .init(id: "result", title: "merchant.apply.timeline.result", detail: Text("merchant.apply.timeline.waiting"), state: .waiting),
    ]
}

struct MerchantApplyTimelineSection: View {
    let steps: [MerchantApplyTimelineStep]

    var body: some View {
        Section("merchant.apply.timeline.title") {
            ForEach(steps) { step in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .cyText(.bodyMedium)
                            .foregroundStyle(step.state == .waiting ? CYColor.textSecondary : CYColor.textPrimary)
                        step.detail
                            .cyText(.meta)
                            .foregroundStyle(step.state == .rejected ? CYColor.dangerText : CYColor.textSecondary)
                    }
                } icon: {
                    Image(systemName: symbol(step.state))
                        .foregroundStyle(tint(step.state))
                        .accessibilityHidden(true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("merchant.apply.timeline.\(step.id)")
            }
        }
    }

    private func symbol(_ state: MerchantApplyTimelineStep.State) -> String {
        switch state {
        case .done: return "checkmark.circle.fill"
        case .current: return "circle.inset.filled"
        case .rejected: return "xmark.circle.fill"
        case .waiting: return "circle"
        }
    }

    private func tint(_ state: MerchantApplyTimelineStep.State) -> Color {
        switch state {
        case .done: return CYColor.successText
        case .current: return Color.accentColor
        case .rejected: return CYColor.dangerText
        case .waiting: return CYColor.textTertiary
        }
    }
}

/// MC7-02-6 (apply/index.js:505 onApplyAddressTap): the store address opens Maps (geocoded, as the MP does).
struct MerchantApplyAddressRow: View {
    let name: String
    let address: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        if address.isEmpty {
            LabeledContent("merchant.onboarding.address", value: "—")
        } else {
            Button {
                var components = URLComponents(string: "https://maps.apple.com/")
                components?.queryItems = [URLQueryItem(name: "q", value: name.isEmpty ? address : name),
                                          URLQueryItem(name: "address", value: address)]
                if let url = components?.url { openURL(url) }
            } label: {
                LabeledContent {
                    HStack(spacing: CYSpacing.xs) {
                        Text(verbatim: address).multilineTextAlignment(.trailing)
                        Image(systemName: "map").accessibilityHidden(true)
                    }
                } label: {
                    Text("merchant.onboarding.address")
                }
            }
            .tint(CYColor.textPrimary)
            .accessibilityHint(Text("merchant.apply.address.openMapsHint"))
            .accessibilityIdentifier("merchant.onboarding.status.address")
        }
    }
}
