import Foundation

/// Registration fallback and onboarding observation. Kept out of `AppSession.swift` (size ratchet).
@MainActor struct UnconfiguredRegistrationBackend:RegistrationCoordinatingService {
    func quote(_ selection:RegistrationQuoteRequest,token:String) async throws -> RegistrationQuote { throw APIError.notConfigured }
    func create(_ intent:RegistrationCreateIntent,token:String) async throws -> RegistrationCreateResult { throw APIError.notConfigured }
    func readStatus(registrationID:Int,token:String) async throws -> RegistrationStatusSnapshot { throw APIError.notConfigured }
}

// Registration intent is navigation only; merchant authorization still comes from access/me.
extension AppSession: MerchantOnboardingObserving {}
