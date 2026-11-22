import SwiftUI

/// Value-only rendering in the existing session-fenced owner host. No retained child state.
@MainActor struct OwnedTemplateSensorConfigurationFields: View {
    let configuration: OwnedTemplateSensorConfiguration
    var body: some View {
        Section("templateOwnerSensor.configuration") {
            Text("templateOwnerSensor.scope").cyText(.meta).foregroundStyle(CYColor.textTertiary)
            if let kind = configuration.kind {
                Label(LocalizedStringKey("templateOwnerSensor.kind." + kind.rawValue), systemImage: "waveform.path").cyText(.cardTitle)
                ForEach(configuration.parameters, id: \.self) { parameter in
                    LabeledContent(LocalizedStringKey("templateOwnerSensor.parameter." + parameter.rawValue)) {
                        switch configuration.value(parameter) {
                        case .value(let value): Text(verbatim: String(value)).monospacedDigit().textSelection(.enabled)
                        case .missing, .null: Text("templateOwnerConfig.missing")
                        case .invalid: Label("templateOwnerSensor.invalid", systemImage: "exclamationmark.circle")
                        }
                    }
                }
            }
            switch configuration.status {
            case .missing, .null: Text("templateOwnerConfig.missing")
            case .invalid: Label("templateOwnerSensor.invalid", systemImage: "exclamationmark.circle")
            case .unsupportedType: Text("templateOwnerSensor.unsupportedType")
            case .partial: Label("templateOwnerConfig.partial", systemImage: "info.circle").font(.subheadline)
            case .ready: EmptyView()
            }
        }.accessibilityIdentifier("templateOwnerSensor.configuration")
    }
}
