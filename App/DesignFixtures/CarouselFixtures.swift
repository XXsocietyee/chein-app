#if DEBUG
import SwiftUI

/// Glass carousel fixtures. Each mounts the REAL kit (`CYCarouselRail`) on synthetic, clearly labelled slides; nothing ships in Release.
/// Reach with `--design-fixture carousel-<name>`; add `--uitesting-reduce-motion` for the Reduce Motion fallback.
///
/// | name | shows |
/// |---|---|
/// | `carousel-events` | event rail (Upcoming / Editor's picks look), 6 cards, scrub handle |
/// | `carousel-tickets` | ticket wallet entry: stub-notch cards with status badges, one expired (dimmed) |
/// | `carousel-empty` | empty phase inside the rail frame, neutral backdrop |
/// | `carousel-loading` | loading phase: one card silhouette, neutral backdrop |
/// | `carousel-ax` | accessibility Dynamic Type: the carousel steps aside for the vertical hero list |
enum CarouselFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "carousel-events": return wrap(rail(.loaded(events), label: "carousel.upcoming"))
        case "carousel-tickets": return wrap(rail(.loaded(tickets), label: "carousel.tickets"))
        case "carousel-empty": return wrap(rail(.empty, label: "carousel.upcoming"))
        case "carousel-loading": return wrap(rail(.loading, label: "carousel.upcoming"))
        case "carousel-ax":
            return wrap(rail(.loaded(events), label: "carousel.upcoming").environment(\.dynamicTypeSize, .accessibility3))
        default: return nil
        }
    }

    static let events: [CYCarouselSlide] = [
        CYCarouselSlide(id: "e1", seed: "Night Market Quest", title: "Night Market Quest", date: "Sat, Nov 14 · 19:00", place: "Dongmen Old Street"),
        CYCarouselSlide(id: "e2", seed: "Riverside Jazz Walk", title: "Riverside Jazz Walk", date: "Sun, Nov 15 · 16:30", place: "Binjiang Park", badge: "Hosting"),
        CYCarouselSlide(id: "e3", seed: "Old Town Tea Trail", title: "Old Town Tea Trail", date: "Fri, Nov 20 · 14:00", place: "Laojie Teahouse"),
        CYCarouselSlide(id: "e4", seed: "Rooftop Film Night", title: "Rooftop Film Night", date: "Sat, Nov 21 · 20:00", place: "Harbor Roof"),
        CYCarouselSlide(id: "e5", seed: "Dawn Temple Run", title: "Dawn Temple Run", date: "Sun, Nov 22 · 06:30", place: "West Lake"),
        CYCarouselSlide(id: "e6", seed: "Hidden Bookshop Crawl", title: "Hidden Bookshop Crawl", date: "Sat, Nov 28 · 13:00", place: "Lane 9"),
    ]

    static let tickets: [CYCarouselSlide] = [
        CYCarouselSlide(id: "0-101", seed: "ticket-101", title: "Night Market Quest", date: "2026-11-14 19:00", place: "Dongmen Old Street", badge: "Ready", kind: .ticket),
        CYCarouselSlide(id: "1-102", seed: "ticket-102", title: "Riverside Jazz Walk", date: "2026-11-15 16:30", place: "Binjiang Park", badge: "Pending", kind: .ticket),
        CYCarouselSlide(id: "2-103", seed: "ticket-103", title: "Old Town Tea Trail", date: "2026-10-02 14:00", place: "Laojie Teahouse", badge: "Expired", kind: .ticket, dimmed: true),
    ]

    @MainActor private static func rail(_ phase: CYPhase<[CYCarouselSlide], Error>, label: LocalizedStringKey) -> some View {
        List {
            Section {
                CYCarouselRail(phase: phase, railLabel: label, onOpen: { _ in }) {
                    ForEach(events) { slide in
                        CYImageCard(verbatim: slide.title, fallback: "ticketWallet.untitled", meta: [slide.date, slide.place].compactMap { $0 }.joined(separator: " · "))
                            .listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                    }
                }
                .questifyCardListRow()
            } header: {
                Text(verbatim: "Upcoming").cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary).textCase(nil)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }

    @MainActor private static func wrap<V: View>(_ view: V) -> AnyView {
        AnyView(
            VStack(spacing: 0) {
                Text(verbatim: "DEBUG fixture · synthetic data")
                    .cyText(.caption).foregroundStyle(CYColor.textTertiary)
                    .frame(maxWidth: .infinity).padding(.vertical, 4).background(CYColor.bgRaised)
                view
            }
            .themeDomain(.player)
            .preferredColorScheme(.dark)
            .background(CYColor.bgPage.ignoresSafeArea())
        )
    }
}
#endif
