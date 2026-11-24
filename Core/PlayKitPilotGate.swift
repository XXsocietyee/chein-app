import Foundation

/// P4 game kits draw only for an event in the pilot set. The set is empty, so the gate is off.
public enum PlayKitPilotGate {
    #if DEBUG || TEST
    nonisolated(unsafe) public static var pilotEventIDs: Set<Int> = []
    public static func allows(eventID: Int?) -> Bool {
        guard let eventID else { return false }
        return pilotEventIDs.contains(eventID)
    }
    #else
    public static let pilotEventIDs: Set<Int> = []
    public static func allows(eventID: Int?) -> Bool { false }
    #endif
}
