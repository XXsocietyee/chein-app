import Foundation

/// Lexical version gate only. ProjectEditJSON/ContentDraftJSON remain the JSON codecs.
/// Decimal alone cannot distinguish backend integer token 2 from floating token 2.0.
enum NativeConditionAuthorVersion {
    static func hasExplicitV2(_ raw: String) -> Bool {
        let bytes = Array(raw.utf8)
        var index = 0, depth = 0
        var versions: [String: [String]] = [:]
        func whitespace(_ c: UInt8) -> Bool { c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d }
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 0x22 {
                let start = index; index += 1
                while index < bytes.count && bytes[index] != 0x22 {
                    index += bytes[index] == 0x5c ? 2 : 1
                }
                guard index < bytes.count else { return false }
                let end = index; index += 1
                guard depth == 1 else { continue }
                var cursor = index
                while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
                guard cursor < bytes.count && bytes[cursor] == 0x3a,
                      let key = try? JSONDecoder().decode(String.self, from: Data(bytes[start...end])),
                      key == "schemaVersion" || key == "routeExpressionVersion" else { continue }
                cursor += 1
                while cursor < bytes.count && whitespace(bytes[cursor]) { cursor += 1 }
                let valueStart = cursor
                while cursor < bytes.count && !whitespace(bytes[cursor]) && ![0x2c, 0x7d, 0x5d].contains(bytes[cursor]) { cursor += 1 }
                versions[key, default: []].append(String(decoding: bytes[valueStart..<cursor], as: UTF8.self))
            } else {
                if byte == 0x7b || byte == 0x5b { depth += 1 }
                if byte == 0x7d || byte == 0x5d { depth -= 1 }
                index += 1
            }
        }
        return versions["schemaVersion"] == ["1"] && versions["routeExpressionVersion"] == ["2"]
    }
}
