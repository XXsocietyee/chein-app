import SwiftUI

/// mp-journey r3: MP `pages/play/index` 终章结局信 (`.ending`, mode 2): 你的城市故事 · opener · one block per stop
/// (第 N 步 · name, then its line). Shown only when the ending has visible words (MP `hasVisibleContent`).
struct FreeExplorationEndingLetter: View {
    let ending: PlayEndingDocument
    @Environment(\.dismiss) private var dismiss

    static func hasVisibleContent(_ ending: PlayEndingDocument) -> Bool {
        if !ending.opener.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        return ending.fragments.contains { fragment in
            !fragment.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !(fragment.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if !ending.opener.isEmpty {
                    Section {
                        Text(verbatim: ending.opener)
                            .font(.title3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                ForEach(ending.fragments) { fragment in
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("playFree.ending.step \(fragment.step) \(fragment.name)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            if let text = fragment.text, !text.isEmpty {
                                Text(verbatim: text).font(.body)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle(Text("playFree.ending.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("action.done") { dismiss() }
                }
            }
        }
        .accessibilityIdentifier("playFree.ending.letter")
    }
}
