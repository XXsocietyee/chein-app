import Foundation

/// Exact `POST api/team/create` JSON from `TeamWriteContract`. Extra fields, money fields and a missing owner are not this write.
public enum TeamCreateWriteBody {
    public static func accepts(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        let keys = Set(object.keys)
        guard keys.isSubset(of: ["ownerType", "ownerId", "maxMembers", "joinMode"]),
              keys.isSuperset(of: ["ownerType", "ownerId", "maxMembers"]) else { return false }
        guard exactInt(object["ownerType"]) == 2 else { return false }
        guard let owner = exactInt(object["ownerId"]), owner > 0 else { return false }
        guard let size = exactInt(object["maxMembers"]), (2...4).contains(size) else { return false }
        if keys.contains("joinMode") {
            guard exactInt(object["joinMode"]) == 1 else { return false }
        }
        return true
    }

    private static func exactInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite, double.rounded() == double, double >= Double(Int.min), double <= Double(Int.max) else { return nil }
        return Int(double)
    }
}
