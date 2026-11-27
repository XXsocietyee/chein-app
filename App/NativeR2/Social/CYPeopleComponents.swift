import SwiftUI

// Design pass · clubs + social (design-principles P6 people present, P11 invites as cards, P12 language-proof).
// Presentation only: every name, count and answer comes from the existing owner; these views hold no state of
// their own and never start a write. Answers call the caller's existing review / confirm path.

/// P6 "other people are present": overlapping member avatars with a rolling "+N". Initials stand in when a member has
/// no HTTPS avatar (`CYAvatarView`). One VoiceOver element that reads the visible names and how many more.
struct CYFacePile: View {
    struct Person: Identifiable, Hashable {
        let id: String
        let name: String
        let url: URL?
    }

    let people: [Person]
    /// Everyone this pile stands for; nil or no more than `people` shows no "+N".
    var total: Int? = nil
    var size: CYAvatarSize = .xs
    var limit = 4
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shown: [Person] { Array(people.prefix(max(limit, 1))) }
    private var extra: Int {
        let count = total ?? people.count
        return max(count - shown.count, 0)
    }

    var body: some View {
        HStack(spacing: -size.rawValue * 0.3) {
            ForEach(Array(shown.enumerated()), id: \.element.id) { index, person in
                CYAvatarView(url: person.url, name: person.name, size: size)
                    .overlay(Circle().strokeBorder(CYColor.bgPage, lineWidth: 2))
                    .zIndex(Double(shown.count - index))
            }
            if extra > 0 {
                Text(verbatim: "+" + extra.formatted(.number.notation(.compactName)))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .contentTransition(.numericText(value: Double(extra)))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .frame(minWidth: size.rawValue, minHeight: size.rawValue)
                    .background(.quaternary, in: Capsule())
                    .overlay(Capsule().strokeBorder(CYColor.bgPage, lineWidth: 2))
            }
        }
        .animation(reduceMotion ? nil : .snappy, value: extra)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        let names = shown.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let list = Text(verbatim: names.joined(separator: ", "))
        guard extra > 0 else { return list }
        return list + Text(verbatim: ", ") + Text("comp.social.people.more \(extra)")
    }
}

/// One fact line on an invite card (when / where / who), an SF Symbol and the source's own text.
struct CYInviteFact: Hashable {
    let symbol: String
    let text: String
}

/// P11 "invites are cards, answers are one tap": what (title) · when / where / who (facts), an optional taped-note line
/// (the inviter's own message, P7), the people already in (P6), then the answers. Calm system surface, one accent from
/// the caller. Every line wraps (P12); at accessibility sizes the icon tile steps aside.
struct CYInviteCard<Answers: View>: View {
    let symbol: String
    let tint: Color
    let kicker: Text?
    let title: Text
    let note: String?
    let facts: [CYInviteFact]
    let people: [CYFacePile.Person]
    let peopleTotal: Int?
    let answers: Answers
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .headline) private var tileSide: CGFloat = 40

    init(symbol: String, tint: Color, kicker: Text? = nil, title: Text, note: String? = nil,
         facts: [CYInviteFact] = [], people: [CYFacePile.Person] = [], peopleTotal: Int? = nil,
         @ViewBuilder answers: () -> Answers) {
        self.symbol = symbol
        self.tint = tint
        self.kicker = kicker
        self.title = title
        self.note = note
        self.facts = facts
        self.people = people
        self.peopleTotal = peopleTotal
        self.answers = answers()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            HStack(alignment: .top, spacing: CYSpacing.md) {
                if !typeSize.isAccessibilitySize {
                    Image(systemName: symbol)
                        .font(.headline)
                        .foregroundStyle(tint)
                        .frame(width: tileSide, height: tileSide)
                        .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    if let kicker {
                        kicker.font(.footnote.weight(.semibold)).foregroundStyle(tint)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    title.font(.headline).foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(facts, id: \.self) { fact in
                        Label { Text(verbatim: fact.text) } icon: { Image(systemName: fact.symbol) }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                // Taped note (R-island): the inviter's words in their own voice, quiet and slightly tilted.
                Text(verbatim: "“" + note + "”")
                    .font(.callout.italic())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, CYSpacing.md)
                    .padding(.vertical, CYSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CYColor.warningSoft, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .rotationEffect(.degrees(typeSize.isAccessibilitySize ? 0 : -0.6))
            }
            if !people.isEmpty {
                CYFacePile(people: people, total: peopleTotal)
            }
            answers
        }
        .padding(.vertical, CYSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

/// The answer row under an invite: one prominent yes, a quieter no, and an optional gentle "later" (Tuck) that leaves
/// the invite open. Side by side when they fit, stacked when the words are long (P12).
struct CYInviteAnswers: View {
    let primary: Text
    var primaryDisabled = false
    let onPrimary: () -> Void
    var secondary: Text? = nil
    var secondaryIsDestructive = false
    var secondaryDisabled = false
    var onSecondary: (() -> Void)? = nil
    var showsLater = false
    var onLater: (() -> Void)? = nil
    /// Kept so existing UI tests still find each answer.
    var primaryIdentifier = "comp.social.invite.primary"
    var secondaryIdentifier = "comp.social.invite.secondary"

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.sm) { buttons }
            VStack(alignment: .leading, spacing: CYSpacing.sm) { buttons }
        }
    }

    @ViewBuilder private var buttons: some View {
        Button(action: onPrimary) {
            primary.lineLimit(2).frame(minWidth: 72)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
        .disabled(primaryDisabled)
        .accessibilityIdentifier(primaryIdentifier)
        if let secondary, let onSecondary {
            Button(role: secondaryIsDestructive ? .destructive : nil, action: onSecondary) {
                secondary.lineLimit(2).frame(minWidth: 72)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.regular)
            .disabled(secondaryDisabled)
            .accessibilityIdentifier(secondaryIdentifier)
        }
        if showsLater, let onLater {
            Button(action: onLater) { Text("comp.social.invite.later").lineLimit(1) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .frame(minHeight: CYSpacing.minTouchTarget)
        }
    }
}

#if DEBUG
#Preview("People + invite card") {
    List {
        CYFacePile(people: [
            .init(id: "1", name: "林", url: nil), .init(id: "2", name: "Lena", url: nil),
            .init(id: "3", name: "周", url: nil), .init(id: "4", name: "Sam", url: nil)
        ], total: 128)
        CYInviteCard(symbol: "person.3.fill", tint: .orange, kicker: Text(verbatim: "组队邀请"),
                     title: Text(verbatim: "周末夜跑 · 外滩"), note: "一起漫游？",
                     facts: [CYInviteFact(symbol: "person.crop.circle", text: "Lena")]) {
            CYInviteAnswers(primary: Text(verbatim: "加入"), onPrimary: {},
                            secondary: Text(verbatim: "拒绝"), secondaryIsDestructive: true, onSecondary: {},
                            showsLater: true, onLater: {})
        }
    }
    .preferredColorScheme(.dark)
}
#endif
