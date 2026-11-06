import Foundation

/// Concrete reference reader for the committed e16 strict Collector/37 endpoint ONLY.
/// Root must select this adapter only for a deployment whose original successful references
/// response means complete collection. It is never inferred from login, a URL, or positions[].
/// The supplied transport still independently requires the exact references-read grant.
@MainActor public final class NativeAttributeAuthorE16References {
    private let transport: any NativeAttributeAuthorTransport
    private let current: () -> NativeAttributeAuthorBinding?
    public init(transport: any NativeAttributeAuthorTransport,
                current: @escaping () -> NativeAttributeAuthorBinding?) {
        self.transport = transport; self.current = current
    }
    public func read(binding: NativeAttributeAuthorBinding, key: String,
                     requestKey: UUID) async throws -> NativeAttributeAuthorReferences {
        let request = try NativeAttributeAuthorRequest.definitionReferences(key, binding: binding, requestKey: requestKey)
        let check: @MainActor () throws -> Void = { [weak self] in
            try Task.checkCancellation()
            guard self?.current() == binding else { throw NativeAttributeAuthorError.staleSource }
        }
        try check()
        let (data, status) = try await transport.send(request, finalCheck: check)
        try check()
        // An error/missing/null/partial response is not an empty certificate. The original
        // strict envelope also verifies exact integer spelling and complete topic/version.
        guard let root = try NativeAttributeAuthorWire.decode(data).object,
              let code = root["code"]?.integer else { throw NativeAttributeAuthorError.invalid("references response") }
        guard (200..<300).contains(status), code == 200 else {
            if status == 409 || code == 409 {
                throw NativeAttributeAuthorError.versionConflict(root["msg"]?.text ?? "nativeAttribute.stale")
            }
            throw NativeAttributeAuthorError.rejected(root["msg"]?.text ?? "HTTP \(status)")
        }
        let envelope = try NativeAttributeAuthorVersionedEnvelope(data, expected: binding, version: binding.sourceConfigVersion)
        guard let fields = envelope.root["data"]?.object,
              fields["stateKey"]?.text?.utf8.elementsEqual(key.utf8) == true,
              let raw = fields["positions"]?.array, raw.count <= 8192 else { throw NativeAttributeAuthorError.invalid("complete original references") }
        let positions = try raw.map { value -> String in
            guard let text = value.text, !text.isEmpty else { throw NativeAttributeAuthorError.invalid("reference position") }
            return text
        }
        return .init(binding: binding, requestKey: requestKey, stateKey: key, positions: positions, incompleteReason: nil)
    }
}
