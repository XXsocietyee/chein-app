import SwiftUI

/// One city task as a single card: step progress (accept, answer, done), the question, tappable option rows, and ONE call to action per step.
/// Shared by the neutral and on-site task pages; the pages map their own task types into plain values.
struct CityTaskCard: View {
    struct Option: Identifiable { let id: String; let label: String }
    let title: String
    let question: String
    let status: String               // NOT_ACCEPTED / ACTIVE / anything else = finished
    let statusText: Text
    let attempts: Int
    let maxAttempts: Int
    let options: [Option]
    @Binding var selection: String
    let table: String
    let enabled: Bool
    var note: Text? = nil
    var resultNote: Text? = nil
    var details: [(Text, String)] = []
    let accept: () -> Void
    let submit: () -> Void
    @Environment(\.locale) private var locale
    private var step: Int { status == "NOT_ACCEPTED" ? 0 : status == "ACTIVE" ? 1 : 2 }
    var body: some View {
        CYInfoCard {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(verbatim: title).font(CYTypography.sectionTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true).accessibilityAddTraits(.isHeader)
                HStack(spacing: CYSpacing.sm) {
                    statusText.font(CYTypography.meta.weight(.semibold)).foregroundStyle(CYColor.textSecondary)
                    Text(verbatim: "·").foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
                    Text(verbatim: ChannelCopy.text("已答 \(attempts) / \(maxAttempts) 次", "\(attempts) of \(maxAttempts) attempts used", locale: locale))
                        .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                }
            }
            CYStepIndicator(titles: [ChannelCopy.text("接受", "Accept", locale: locale),
                                     ChannelCopy.text("作答", "Answer", locale: locale),
                                     ChannelCopy.text("完成", "Done", locale: locale)], current: step)
            Text(verbatim: question).font(CYTypography.body).foregroundStyle(CYColor.textPrimary).fixedSize(horizontal: false, vertical: true)
            if let note { note.font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).fixedSize(horizontal: false, vertical: true) }
            if status == "ACTIVE" {
                VStack(spacing: CYSpacing.sm) {
                    ForEach(options) { option in optionRow(option) }
                }
                CYPillButton(verbatim: ChannelCopy.text("提交答案", "Submit answer", locale: locale), systemImage: "paperplane.fill", action: submit)
                    .disabled(!enabled || !options.contains(where: { $0.id == selection }))
            } else if status == "NOT_ACCEPTED" {
                CYPillButton(verbatim: ChannelCopy.text("接受任务", "Accept task", locale: locale), systemImage: "checkmark.circle", action: accept)
                    .disabled(!enabled)
            } else if let resultNote {
                CYNoteBanner(text: resultNote, symbol: "checkmark.seal.fill", tone: .success)
            }
            if !details.isEmpty {
                CYDetailsDisclosure(title: Text(verbatim: ChannelCopy.text("记录详情", "Record details", locale: locale))) {
                    ForEach(details.indices, id: \.self) { CYFactRow(label: details[$0].0, value: details[$0].1) }
                }
            }
        }
    }
    private func optionRow(_ option: Option) -> some View {
        CYChoiceRow(label: option.label, selected: selection == option.id, enabled: enabled) { selection = option.id }
    }
}
