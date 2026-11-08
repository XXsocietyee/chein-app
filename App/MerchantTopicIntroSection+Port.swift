import SwiftUI

/// Port-2: merchantinfo detail tab text blocks (subtitle, 主题介绍, 活动内容).
struct MerchantTopicIntroSection: View {
    let intro: MerchantTopicIntro
    let topicName: String?
    private func title(_ item: MerchantTopicIntro.Include) -> Text {
        switch item {
        case .chapters(let n): return Text("merchant.topicIntro.include.chapters \(n)")
        case .stations(let n): return Text("merchant.topicIntro.include.stations \(n)")
        case .plays(let n): return Text("merchant.topicIntro.include.plays \(n)")
        case .audio(let minutes):
            if let minutes { return Text("merchant.topicIntro.include.audioMinutes \(minutes)") }
            return Text("merchant.topicIntro.include.audio")
        case .medal(let name):
            if let name { return Text("merchant.topicIntro.include.medalNamed \(name)") }
            return Text("merchant.topicIntro.include.medal")
        case .completionCoupon: return Text("merchant.topicIntro.include.coupon")
        }
    }
    var body: some View {
        if !intro.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if let subtitle = intro.subtitle { Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary) }
                if let text = intro.introduction {
                    Text("merchant.topicIntro.description").font(.headline)
                    Text(verbatim: text).font(.body).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("merchant.topicIntro.description")
                }
                if !intro.includes.isEmpty {
                    Text("merchant.topicIntro.includes").font(.headline)
                    ForEach(Array(intro.includes.enumerated()), id: \.offset) { item in
                        Label { title(item.element) } icon: { Image(systemName: "checkmark.circle") }.font(.subheadline)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("merchant.topicIntro")
        }
    }
}
