import SwiftUI

/// Local inspiration from the c6 simple-publish reference. These values are not
/// draft fields, saved records, permissions or generated places.
struct QuickPublishingInterest: Identifiable {
    let id: String
    let chinese: String
    let english: String
    let symbol: String
    let x: CGFloat
    let y: CGFloat
    let diameter: CGFloat
    func title(chinese: Bool) -> String { chinese ? self.chinese : english }
    static let all: [Self] = [
        .init(id: "coffee", chinese: "咖啡", english: "Coffee", symbol: "fork.knife", x: 14, y: 90, diameter: 150),
        .init(id: "food", chinese: "美食", english: "Food", symbol: "bag", x: 36, y: 10, diameter: 132),
        .init(id: "photo", chinese: "拍照", english: "Photography", symbol: "camera", x: 58, y: 110, diameter: 140),
        .init(id: "story", chinese: "老建筑", english: "Old buildings", symbol: "mappin.circle", x: 78, y: 20, diameter: 128),
        .init(id: "night", chinese: "夜游", english: "Night walks", symbol: "star", x: 18, y: 280, diameter: 128),
        .init(id: "walk", chinese: "散步", english: "Walking", symbol: "map", x: 44, y: 250, diameter: 140),
        .init(id: "park", chinese: "公园", english: "Parks", symbol: "leaf", x: 70, y: 280, diameter: 132)
    ]
}

enum QuickPublishingPalette {
    /// Native r2: selection uses the system accent.
    static func selection(in domain: ThemeDomain) -> Color { .accentColor }
}

/// Native r2: the MP interest bubbles have no Apple equivalent; the closest system control is a
/// multi-select list of rows with a checkmark (Settings / Reminders pattern). Row-shaped: host it in a Section.
struct QuickPublishingInterestPicker: View {
    let selected: Set<String>
    let toggle: (String) -> Void
    @Environment(\.locale) private var locale
    private var chinese: Bool { locale.language.languageCode?.identifier == "zh" }
    var body: some View {
        ForEach(QuickPublishingInterest.all) { item in interest(item) }
    }
    private func interest(_ item: QuickPublishingInterest) -> some View {
        let on = selected.contains(item.id)
        return Button { toggle(item.id) } label: {
            HStack {
                Label(item.title(chinese: chinese), systemImage: item.symbol)
                    .foregroundStyle(.primary)
                Spacer()
                if on { Image(systemName: "checkmark").foregroundStyle(.tint).accessibilityHidden(true) }
            }
        }
            .accessibilityLabel(Text(verbatim: item.title(chinese: chinese)))
            .accessibilityValue(on ? Text("publishModes.selected") : Text("publishModes.notSelected"))
            .accessibilityAddTraits(on ? .isSelected : [])
            .accessibilityIdentifier("publishModes.quick.interest." + item.id)
    }
}

/// Native r2: the reference's decorative canvas is gone; the ground is the system grouped background.
struct QuickPublishingCanvas: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

/// Presentation helpers shared only by the publishing journey. They own no state,
/// permissions or request callbacks.
/// Native r2: a system form row — the label as the system draws it (`LabeledContent`), the control trailing.
struct PublishingField<Content: View>: View {
    let title: Text
    let content: Content
    var required = false
    @Environment(\.locale) private var locale
    init(_ key: LocalizedStringKey, required: Bool = false, @ViewBuilder content: () -> Content) {
        title = Text(key); self.required = required; self.content = content()
    }
    init(title: Text, required: Bool = false, @ViewBuilder content: () -> Content) {
        self.title = title; self.required = required; self.content = content()
    }
    var body: some View {
        LabeledContent {
            content
        } label: {
            title
                .accessibilityLabel(title + Text(verbatim: required ? (locale.language.languageCode?.identifier == "zh" ? "，必填" : ", required") : ""))
        }
    }
}

struct PublishingStatusRow: View {
    let title: Text
    var symbol = "info.circle"
    var isError = false
    var body: some View {
        Label {
            title
        } icon: {
            Image(systemName: symbol).accessibilityHidden(true)
        }
        .font(isError ? .body : .footnote)
        .foregroundStyle(isError ? AnyShapeStyle(Color.red) : AnyShapeStyle(.secondary))
        .accessibilityElement(children: .combine)
    }
}

/// Native r2: system grouped Form background; only keyboard dismissal remains.
struct PublishingFormSurface: ViewModifier {
    func body(content: Content) -> some View {
        content.scrollDismissesKeyboard(.interactively)
    }
}

@MainActor struct PublishingModePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selection: ProjectEditProduct
    let confirm: (ProjectEditProduct) -> Void
    init(current: ProjectEditProduct, confirm: @escaping (ProjectEditProduct) -> Void) {
        _selection = State(initialValue: current); self.confirm = confirm
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("contextPublish.mode.choose", selection: $selection) {
                        Text("projectEdit.city").tag(ProjectEditProduct.city)
                        Text("projectEdit.freeExplore").tag(ProjectEditProduct.freeExplore)
                    }.pickerStyle(.inline).labelsHidden()
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("contextPublish.mode.cityDetail")
                        Text("contextPublish.mode.exploreDetail")
                    }
                }
            }.modifier(PublishingFormSurface())
                .navigationTitle(Text("contextPublish.mode.choose"))
                .navigationBarTitleDisplayMode(.inline)
                .cyDomainScreen(.topicEditor)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("contextPublish.mode.use") { confirm(selection) } }
            }
        }
    }
}
@MainActor struct PublishingSubmissionResultSheet: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var lifecycle = ProjectSubmissionResultLifecycle()
    let receipt: PublishingSubmissionHandoff
    let canNavigate: Bool
    var canVerifyRelease = false
    var statusLoader: (@MainActor () async throws -> TopicPublicationStatus)? = nil
    let close: () -> Void
    var body: some View {
        let capture = lifecycle.capture
        result(capture: capture)
            .onAppear { lifecycle.appear(active: scenePhase == .active) }
            .onDisappear { lifecycle.disappear() }
            .onChange(of: scenePhase) { _, phase in lifecycle.sceneChanged(active: phase == .active) }
            .task(id: capture) {
                guard receipt.bundleAcknowledgment == nil, canNavigate, let capture else { return }
                do { try await Task.sleep(nanoseconds: 2_000_000_000) } catch { return }
                guard !Task.isCancelled else { return }
                lifecycle.finish(capture, action: close)
            }
    }
    @ViewBuilder private func result(capture: UUID?) -> some View {
        if let acknowledgment = receipt.bundleAcknowledgment {
            List {
                Section {
                    Label("contextPublish.result.acknowledged", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(.green)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: receipt.title)
                }
                if let statusLoader {
                    Section {
                        TopicPublicationStatusPanel(topicID: acknowledgment.topicID, load: statusLoader)
                    }
                }
                Section {
                    ProjectSubmissionEvidenceView(acknowledgment: acknowledgment, currentVerificationConfigured: canVerifyRelease)
                }
                Section {
                    Button { if let capture { lifecycle.finish(capture, action: close) } } label: {
                        Text("action.done").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(capture == nil)
                    .accessibilityIdentifier("projectSubmission.done")
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.insetGrouped)
            .cyDomainScreen(.topicEditor)
            .accessibilityIdentifier("projectSubmission.receipt")
            .interactiveDismissDisabled()
        } else { legacyResult(capture: capture) }
    }
    private func legacyResult(capture: UUID?) -> some View {
        List {
            Section {
                Label("contextPublish.result.acknowledged", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: receipt.title)
                LabeledContent("contextPublish.result.chapters") {
                    Text(verbatim: String(receipt.chapterCount)).monospacedDigit()
                }
            } footer: {
                Text("contextPublish.result.readStatus")
            }
            if !canNavigate {
                Section {
                    Button { if let capture { lifecycle.finish(capture, action: close) } } label: {
                        Text("action.done").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(capture == nil)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .listStyle(.insetGrouped)
        .cyDomainScreen(.topicEditor)
        .interactiveDismissDisabled()
    }
}

/// Presentation-only lease. Backgrounding or closing retires old timer/button captures;
/// becoming visible again starts a fresh full delay without changing the request journal.
@MainActor final class ProjectSubmissionResultLifecycle: ObservableObject {
    @Published private(set) var capture: UUID?
    private var visible = false
    private var active = false
    private var finished = false
    func appear(active: Bool) {
        guard !finished else { return }
        if !visible || self.active != active { capture = active ? UUID() : nil }
        visible = true; self.active = active
    }
    func sceneChanged(active: Bool) {
        guard !finished, self.active != active else { return }
        self.active = active; capture = visible && active ? UUID() : nil
    }
    func disappear() { visible = false; active = false; capture = nil }
    func finish(_ original: UUID, action: () -> Void) {
        guard visible, active, !finished, capture == original else { return }
        finished = true; capture = nil; action()
    }
}
