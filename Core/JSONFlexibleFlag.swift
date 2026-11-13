import Foundation

/// A JSON flag that the backend sends as either a boolean or the integer 0/1 depending on the route
/// (contract §7.3: members send `has_more` as 0/1, roles, op-log, messages and moderation send a boolean).
/// Any other number or type is malformed.
@propertyWrapper
public struct JSONFlexibleFlag: Codable, Equatable, Hashable, Sendable {
    public var wrappedValue: Bool
    public init(wrappedValue: Bool) { self.wrappedValue = wrappedValue }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = try Self.decode(container)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
    static func decode(_ container: any SingleValueDecodingContainer) throws -> Bool {
        if let flag = try? container.decode(Bool.self) { return flag }
        guard let number = try? container.decode(Int.self), number == 0 || number == 1 else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "expected a boolean or 0/1")
        }
        return number == 1
    }
    /// The same rule for `JSONSerialization` values: `true`/`false` or exactly 0/1.
    public static func value(_ raw: Any?) -> Bool? {
        guard let number = raw as? NSNumber else { return nil }
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
        switch number.int64Value {
        case 0 where number.doubleValue == 0: return false
        case 1 where number.doubleValue == 1: return true
        default: return nil
        }
    }
}

/// An optional flag: a missing key or `null` is `nil`.
@propertyWrapper
public struct JSONFlexibleOptionalFlag: Codable, Equatable, Hashable, Sendable {
    public var wrappedValue: Bool?
    public init(wrappedValue: Bool?) { self.wrappedValue = wrappedValue }
    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = container.decodeNil() ? nil : try JSONFlexibleFlag.decode(container)
    }
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(wrappedValue)
    }
}

public extension KeyedDecodingContainer {
    /// A missing key decodes to `nil` instead of failing, matching a plain `Bool?`.
    func decode(_ type: JSONFlexibleOptionalFlag.Type, forKey key: Key) throws -> JSONFlexibleOptionalFlag {
        try decodeIfPresent(type, forKey: key) ?? JSONFlexibleOptionalFlag(wrappedValue: nil)
    }
    /// Boolean or 0/1 at `key`.
    func decodeFlag(forKey key: Key) throws -> Bool {
        try decode(JSONFlexibleFlag.self, forKey: key).wrappedValue
    }
}
