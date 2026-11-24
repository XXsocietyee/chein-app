import SwiftUI

/// Mount hook for `ProfileEditView` (`AP-G03`):
/// Bind/rebind phone row.
public struct ProfileEditGapPhoneBindRow: View {
    public let maskedPhone: String?
    public let onTapBindOrRebind: () -> Void

    public init(maskedPhone: String?, onTapBindOrRebind: @escaping () -> Void) {
        self.maskedPhone = maskedPhone
        self.onTapBindOrRebind = onTapBindOrRebind
    }

    public var body: some View {
        Button(action: onTapBindOrRebind) {
            LabeledContent(
                "手机号",
                value: (maskedPhone?.isEmpty == false)
                    ? (maskedPhone ?? "")
                    : AccountPublishRemainingCopy.bindPhoneTitle
            )
            .cyText(.body)
        }
    }
}

/// Mount hook for `MiniCropView` (`AP-G06`):
/// Dimmed outer frame + circular logo cropper / rule-of-thirds grid + `还原` reset action.
public struct MiniCropGapOverlay: View {
    public let shape: CropGapShape
    public let onReset: () -> Void

    public init(shape: CropGapShape, onReset: @escaping () -> Void) {
        self.shape = shape
        self.onReset = onReset
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            GeometryReader { proxy in
                let size = min(proxy.size.width, proxy.size.height) * 0.8
                ZStack {
                    Color.black.opacity(0.45)
                        .mask(
                            Rectangle()
                                .overlay(
                                    Group {
                                        if shape == .circle {
                                            Circle().frame(width: size, height: size)
                                        } else {
                                            Rectangle().frame(width: size, height: size)
                                        }
                                    }
                                    .blendMode(.destinationOut)
                                )
                        )
                        .compositingGroup()
                        .allowsHitTesting(false)

                    if shape == .circle {
                        Circle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            .frame(width: size, height: size)
                    } else {
                        Rectangle()
                            .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                            .frame(width: size, height: size)
                            .overlay(
                                Path { path in
                                    let third = size / 3
                                    path.move(to: CGPoint(x: third, y: 0))
                                    path.addLine(to: CGPoint(x: third, y: size))
                                    path.move(to: CGPoint(x: third * 2, y: 0))
                                    path.addLine(to: CGPoint(x: third * 2, y: size))
                                    path.move(to: CGPoint(x: 0, y: third))
                                    path.addLine(to: CGPoint(x: size, y: third))
                                    path.move(to: CGPoint(x: 0, y: third * 2))
                                    path.addLine(to: CGPoint(x: size, y: third * 2))
                                }
                                .stroke(Color.white.opacity(0.4), lineWidth: 0.75)
                            )
                    }
                }
            }

            Button(AccountPublishRemainingCopy.cropReset, action: onReset)
                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                .padding(CYSpacing.md)
        }
    }
}

/// Mount hook for `SettingsView` (`AP-G08`):
/// `投诉建议` entry row.
public struct SettingsGapComplaintRow: View {
    public let onOpenComplaint: () -> Void

    public init(onOpenComplaint: @escaping () -> Void) {
        self.onOpenComplaint = onOpenComplaint
    }

    public var body: some View {
        Button(action: onOpenComplaint) {
            HStack {
                Text(verbatim: AccountPublishRemainingCopy.settingsComplaint)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
            }
        }
    }
}

/// Mount hook for `PublishingModesViews` (`AP-G12`):
/// POI-only location picker row (with sold lock) + Step 3 `发起人信息` load/retry.
public struct ActivityPublishGapOrganizerAndPOISection: View {
    public let pickedPlaceName: String?
    public let isSoldLocked: Bool
    public let organizerName: String?
    public let organizerLoadFailed: Bool
    public let onPickLocation: () -> Void
    public let onRetryOrganizer: () -> Void

    public init(
        pickedPlaceName: String?,
        isSoldLocked: Bool,
        organizerName: String?,
        organizerLoadFailed: Bool,
        onPickLocation: @escaping () -> Void,
        onRetryOrganizer: @escaping () -> Void
    ) {
        self.pickedPlaceName = pickedPlaceName
        self.isSoldLocked = isSoldLocked
        self.organizerName = organizerName
        self.organizerLoadFailed = organizerLoadFailed
        self.onPickLocation = onPickLocation
        self.onRetryOrganizer = onRetryOrganizer
    }

    public var body: some View {
        Group {
            Section {
                Button(action: onPickLocation) {
                    LabeledContent("活动地点", value: (pickedPlaceName?.isEmpty == false) ? (pickedPlaceName ?? "") : "选择地点")
                        .cyText(.body)
                }
                .disabled(isSoldLocked)
            } footer: {
                if isSoldLocked {
                    Text(verbatim: AccountPublishRemainingCopy.activitySoldLockNote).cyText(.meta)
                }
            }

            Section {
                if organizerLoadFailed {
                    CYEmptyState(
                        systemImage: "exclamationmark.triangle",
                        LocalizedStringKey(AccountPublishRemainingCopy.organizerLoadFailed),
                        actionTitle: LocalizedStringKey(AccountPublishRemainingCopy.retryLoad),
                        action: onRetryOrganizer
                    )
                } else if let organizerName, !organizerName.isEmpty {
                    LabeledContent(AccountPublishRemainingCopy.organizerInfoTitle, value: organizerName)
                        .cyText(.body)
                }
            } header: {
                Text(verbatim: AccountPublishRemainingCopy.organizerInfoTitle).cyText(.sectionTitle)
            }
        }
    }
}
