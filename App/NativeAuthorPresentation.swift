import Foundation
import SwiftUI

/// Shared only by the P03 author surfaces. These views have no session,
/// permission, persistence or request dependencies.
struct NativeAuthorNotice: View {
    enum Tone { case information, attention, failure }
    let text: Text
    var tone: Tone = .information

    private var symbol: String {
        switch tone {
        case .information: "info.circle"
        case .attention: "exclamationmark.circle"
        case .failure: "exclamationmark.triangle"
        }
    }
    private var color: Color {
        switch tone {
        case .information: .secondary
        case .attention: .orange
        case .failure: .red
        }
    }
    var body: some View {
        Label {
            text
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct NativeAuthorLoading: View {
    let text: Text
    var body: some View {
        HStack {
            ProgressView().accessibilityHidden(true)
            text.font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Native system navigation and grouped content replace the mini-app's
    /// capsule and top spacer. Keep the host's explicit appearance domain:
    /// project/merchant authors are light; Account consumers retain theirs.
    func nativeAuthorSurface() -> some View {
        self
            .listStyle(.insetGrouped)
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
    }

    func nativeAuthorSupportingCopy() -> some View {
        self.font(.subheadline).foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    func nativeAuthorPrimaryAction() -> some View {
        self.buttonStyle(.borderedProminent).controlSize(.large)
    }
}
