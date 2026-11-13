import Foundation

/// UG-11 author hint ladder (mini-program pages/publish/temp/questo-author.js). It writes only the two root
/// keys the server already accepts: `hintLadder[{level,type,payload?,cost:{points}?}]` and the run-wide
/// `hintFreeUsesPerRun`. There is no per-layer free count, no gem or coin price and no LOCATION type.
/// The screen never shows these key names. Server save and publish checks stay the authority.
public struct TemplateHintLayerDraft: Equatable, Identifiable {
    public let index: Int
    public let type: String
    /// TEXT/ANSWER text, IMAGE https reference, or the LETTER position as typed. Empty when unset.
    public let payload: String
    /// Points as typed. Empty means no price was written.
    public let points: String
    public var id: Int { index }
}

public enum TemplateHintLadder {
    public static let types = ["TEXT", "IMAGE", "LETTER", "DIGIT", "ANSWER", "SKIP"]
    public static let maxLayers = 6
    public static let maxRunFreeUses = 1000
    static let rootKeys: Set<String> = ["hintLadder", "hintFreeUsesPerRun"]

    public static func typeLabelKey(_ type: String) -> String { "templateHint.type." + type.lowercased() }

    /// Same reference rule as option pictures: https, a site path or `media-asset:`. No http, data, `//host` or backslash.
    public static func validImageReference(_ raw: String) -> Bool {
        guard !raw.contains("\\") else { return false }
        if raw.hasPrefix("media-asset:") { return raw.count > "media-asset:".count }
        if raw.hasPrefix("/") { return !raw.hasPrefix("//") }
        return PlayExperienceService.validHTTPS(raw)
    }
}

extension TemplateAdvancedDraft {
    public var hintLadderOn: Bool { value["hintLadder"]?.array != nil }

    public var hintLayers: [TemplateHintLayerDraft] {
        (value["hintLadder"]?.array ?? []).enumerated().map { index, row in
            let fields = row.object ?? [:]
            let payload: String
            switch fields["payload"] {
            case .string(let text)?: payload = text
            case .number(let number)?: payload = number.rounded() == number ? String(Int(number)) : String(number)
            default: payload = ""
            }
            let points: String
            switch fields["cost"]?.object?["points"] {
            case .number(let number)?: points = number.rounded() == number ? String(Int(number)) : String(number)
            case .string(let text)?: points = text
            default: points = ""
            }
            return TemplateHintLayerDraft(index: index, type: fields["type"]?.string ?? "TEXT", payload: payload, points: points)
        }
    }

    /// Run-wide free uses as typed; empty when not written.
    public var hintFreeUsesText: String {
        switch value["hintFreeUsesPerRun"] {
        case .number(let number)?: return number.rounded() == number ? String(Int(number)) : String(number)
        case .string(let text)?: return text
        default: return ""
        }
    }

    /// On starts one empty text layer. Off removes the ladder and the run quota together.
    public mutating func setHintLadder(on: Bool) {
        if on {
            guard !hintLadderOn else { return }
            value["hintLadder"] = .array([layer(level: 1, type: "TEXT")])
        } else {
            value.removeValue(forKey: "hintLadder"); value.removeValue(forKey: "hintFreeUsesPerRun")
        }
    }

    public mutating func addHintLayer() {
        var rows = value["hintLadder"]?.array ?? []
        guard rows.count < TemplateHintLadder.maxLayers else { return }
        rows.append(layer(level: rows.count + 1, type: "TEXT"))
        value["hintLadder"] = .array(rows)
    }

    /// Levels are renumbered in order. Removing the last layer turns the ladder off.
    public mutating func removeHintLayer(_ index: Int) {
        var rows = value["hintLadder"]?.array ?? []
        guard rows.indices.contains(index) else { return }
        rows.remove(at: index)
        if rows.isEmpty { setHintLadder(on: false); return }
        value["hintLadder"] = .array(rows.enumerated().map { offset, row in
            var fields = row.object ?? [:]; fields["level"] = .number(Double(offset + 1)); return .object(fields)
        })
    }

    /// A new type drops the old content, which belonged to the old type.
    public mutating func setHintType(_ index: Int, _ type: String) {
        guard TemplateHintLadder.types.contains(type) else { return }
        editLayer(index) { fields in
            guard fields["type"]?.string != type else { return }
            fields["type"] = .string(type); fields.removeValue(forKey: "payload")
        }
    }

    public mutating func setHintPayload(_ index: Int, _ text: String) {
        editLayer(index) { $0["payload"] = .string(text) }
    }

    public mutating func setHintPoints(_ index: Int, _ text: String) {
        editLayer(index) { fields in
            if text.isEmpty { fields.removeValue(forKey: "cost") } else { fields["cost"] = .object(["points": .string(text)]) }
        }
    }

    public mutating func setHintFreeUses(_ text: String) {
        if text.isEmpty { value.removeValue(forKey: "hintFreeUsesPerRun") } else { value["hintFreeUsesPerRun"] = .string(text) }
    }

    /// Quota problem, if any. Shown next to the run-wide field.
    public var hintQuotaIssue: String? {
        let raw = hintFreeUsesText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hintLadderOn, !raw.isEmpty else { return nil }
        guard let n = Int(raw), (0...TemplateHintLadder.maxRunFreeUses).contains(n) else { return "templateHint.validation.quota" }
        return nil
    }

    /// Per-layer problem keyed by index. Mirrors only what the server must refuse; the rest is the server's call.
    public var hintLayerIssues: [Int: String] {
        var out: [Int: String] = [:]
        for layer in hintLayers {
            let payload = layer.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            let points = layer.points.trimmingCharacters(in: .whitespacesAndNewlines)
            if !TemplateHintLadder.types.contains(layer.type) { out[layer.index] = "templateHint.validation.type" }
            else if layer.type == "TEXT" && payload.isEmpty { out[layer.index] = "templateHint.validation.text" }
            else if layer.type == "IMAGE" && payload.isEmpty { out[layer.index] = "templateHint.validation.image" }
            else if layer.type == "IMAGE" && !TemplateHintLadder.validImageReference(payload) { out[layer.index] = "templateHint.validation.imageURL" }
            else if layer.type == "LETTER" && !payload.isEmpty && (Int(payload) ?? 0) < 1 { out[layer.index] = "templateHint.validation.letter" }
            else if !points.isEmpty && (Int(points) ?? -1) < 0 { out[layer.index] = "templateHint.validation.points" }
        }
        return out
    }

    /// Issue keys that block saving, folded into `issues`.
    var hintLadderIssues: [String] {
        guard hintLadderOn else { return value["hintFreeUsesPerRun"] == nil ? [] : ["templateHint.validation.quotaWithoutLadder"] }
        var out: [String] = []
        if let quota = hintQuotaIssue { out.append(quota) }
        if hintLayers.count > TemplateHintLadder.maxLayers { out.append("templateHint.validation.tooMany") }
        out += Set(hintLayerIssues.values).sorted()
        return out
    }

    /// The saved shape: levels 1…n in order, text trimmed, LETTER position and points as integers, empty keys dropped.
    mutating func normalizeHintLadder() {
        guard let rows = value["hintLadder"]?.array else { value.removeValue(forKey: "hintFreeUsesPerRun"); return }
        value["hintLadder"] = .array(hintLayers.prefix(rows.count).map { layer in
            var out: [String: TemplateAuthoringJSON] = ["level": .number(Double(layer.index + 1)), "type": .string(layer.type)]
            let payload = layer.payload.trimmingCharacters(in: .whitespacesAndNewlines)
            if ["TEXT", "IMAGE", "ANSWER"].contains(layer.type), !payload.isEmpty { out["payload"] = .string(payload) }
            if layer.type == "LETTER", let position = Int(payload) { out["payload"] = .number(Double(position)) }
            if let points = Int(layer.points.trimmingCharacters(in: .whitespacesAndNewlines)) { out["cost"] = .object(["points": .number(Double(points))]) }
            return .object(out)
        })
        if let n = Int(hintFreeUsesText.trimmingCharacters(in: .whitespacesAndNewlines)) { value["hintFreeUsesPerRun"] = .number(Double(n)) }
        else { value.removeValue(forKey: "hintFreeUsesPerRun") }
    }

    private func layer(level: Int, type: String) -> TemplateAuthoringJSON {
        .object(["level": .number(Double(level)), "type": .string(type), "payload": .string("")])
    }

    private mutating func editLayer(_ index: Int, _ change: (inout [String: TemplateAuthoringJSON]) -> Void) {
        var rows = value["hintLadder"]?.array ?? []
        guard rows.indices.contains(index) else { return }
        var fields = rows[index].object ?? [:]
        change(&fields)
        rows[index] = .object(fields)
        value["hintLadder"] = .array(rows)
    }
}
