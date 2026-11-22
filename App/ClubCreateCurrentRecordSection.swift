import SwiftUI

/// A fresh read projection only; never a creation receipt or available quota.
struct ClubCreateCurrentRecordSection: View {
    let countText: String
    @Environment(\.locale) private var locale
    var body: some View {
        Section {
            LabeledContent(locale.language.languageCode?.identifier == "zh" ? "当前读取的俱乐部记录数" : "Club records in this read") {
                Text(verbatim: countText)
            }
            Text(locale.language.languageCode?.identifier == "zh"
                ? "这只是当前记录，不是可用名额，也不能确认原创建请求。原请求仍待确认，请勿再次提交。"
                : "These are current records, not available slots or confirmation of the original creation request. That request remains unconfirmed. Do not submit it again.")
                .cyText(.bodyCompact).foregroundStyle(.secondary)
        }.accessibilityIdentifier("club.ops.create.currentRecordCount")
    }
}
