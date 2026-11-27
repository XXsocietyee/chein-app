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
        }
        .foregroundStyle(.primary)
    }
}

/// Mount hook for `MiniCropView` (`AP-G06` / `A7-01/03/05`):
/// Dimmed outer frame + circular logo cropper / rule-of-thirds grid + `还原` reset action,
/// aligned to the exact computed `cropSize` from `MiniCropGeometry.frame(ratio:)`.
public struct MiniCropGapOverlay: View {
    public let shape: CropGapShape
    public let cropSize: CGSize
    public let onReset: () -> Void

    public init(shape: CropGapShape, cropSize: CGSize, onReset: @escaping () -> Void) {
        self.shape = shape
        self.cropSize = cropSize
        self.onReset = onReset
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                Color.black.opacity(0.45)
                    .mask(
                        Rectangle()
                            .overlay(
                                Group {
                                    if shape == .circle {
                                        Circle().frame(width: cropSize.width, height: cropSize.height)
                                    } else {
                                        Rectangle().frame(width: cropSize.width, height: cropSize.height)
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
                        .frame(width: cropSize.width, height: cropSize.height)
                } else {
                    Rectangle()
                        .stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                        .frame(width: cropSize.width, height: cropSize.height)
                        .overlay(
                            Path { path in
                                let thirdW = cropSize.width / 3
                                let thirdH = cropSize.height / 3
                                path.move(to: CGPoint(x: thirdW, y: 0))
                                path.addLine(to: CGPoint(x: thirdW, y: cropSize.height))
                                path.move(to: CGPoint(x: thirdW * 2, y: 0))
                                path.addLine(to: CGPoint(x: thirdW * 2, y: cropSize.height))
                                path.move(to: CGPoint(x: 0, y: thirdH))
                                path.addLine(to: CGPoint(x: cropSize.width, y: thirdH))
                                path.move(to: CGPoint(x: 0, y: thirdH * 2))
                                path.addLine(to: CGPoint(x: cropSize.width, y: thirdH * 2))
                            }
                            .stroke(Color.white.opacity(0.4), lineWidth: 0.75)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            Button("fixr8.crop.reset", action: onReset)
                .buttonStyle(.bordered)
                .padding()
                .accessibilityIdentifier("miniCrop.reset")
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
            Text(verbatim: AccountPublishRemainingCopy.settingsComplaint)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(.primary)
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
                    LabeledContent("活动地点", value: (pickedPlaceName?.isEmpty == false) ? (pickedPlaceName ?? "") : appLocalized("i18nR3.choosePlace", locale: .current))
                }
                .foregroundStyle(.primary)
                .disabled(isSoldLocked)
            } footer: {
                if isSoldLocked {
                    Text(verbatim: AccountPublishRemainingCopy.activitySoldLockNote)
                }
            }

            Section {
                if organizerLoadFailed {
                    ContentUnavailableView {
                        Label(LocalizedStringKey(AccountPublishRemainingCopy.organizerLoadFailed), systemImage: "exclamationmark.triangle")
                    } actions: {
                        Button(LocalizedStringKey(AccountPublishRemainingCopy.retryLoad), action: onRetryOrganizer)
                            .buttonStyle(.bordered)
                    }
                } else if let organizerName, !organizerName.isEmpty {
                    LabeledContent(AccountPublishRemainingCopy.organizerInfoTitle, value: organizerName)
                }
            } header: {
                Text(verbatim: AccountPublishRemainingCopy.organizerInfoTitle)
            }
        }
    }
}
