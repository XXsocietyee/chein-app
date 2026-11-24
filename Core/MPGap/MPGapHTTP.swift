import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Error carrying the server's `msg` string when a non-200 business code is returned (`F-C23`).
public enum MPGapHTTPError: Error, LocalizedError, Equatable {
    case serverMessage(code: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .serverMessage(_, let message):
            return message
        }
    }
}

/// Shared JSON envelope decoder and request builder for `Core/MPGap/*` clients.
public enum MPGapHTTP {
    private struct StatusEnvelope: Decodable {
        let code: Int?
        let msg: String?

        enum CodingKeys: String, CodingKey { case code, msg }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let intCode = try? container.decode(Int.self, forKey: .code) {
                code = intCode
            } else if let strCode = try? container.decode(String.self, forKey: .code), let intCode = Int(strCode) {
                code = intCode
            } else {
                code = nil
            }
            msg = try? container.decode(String.self, forKey: .msg)
        }
    }

    private struct DataEnvelope<T: Decodable>: Decodable {
        let data: T?
    }

    public static func getJSON<T: Decodable>(
        configuration: APIConfiguration,
        transport: any HTTPTransport,
        path: String,
        queryItems: [URLQueryItem] = [],
        token: String
    ) async throws -> T {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        let (data, status) = try await transport.send(request)
        return try decodeEnvelope(data: data, status: status)
    }

    public static func postJSON<T: Decodable>(
        configuration: APIConfiguration,
        transport: any HTTPTransport,
        path: String,
        body: [String: Any] = [:],
        token: String
    ) async throws -> T {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let (data, status) = try await transport.send(request)
        return try decodeEnvelope(data: data, status: status)
    }

    public static func postAction(
        configuration: APIConfiguration,
        transport: any HTTPTransport,
        path: String,
        body: [String: Any] = [:],
        token: String
    ) async throws {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])

        let (data, status) = try await transport.send(request)
        let envelope = try? JSONDecoder().decode(StatusEnvelope.self, from: data)
        if status == 401 || envelope?.code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.httpStatus(status)
        }
        if let code = envelope?.code, code != 200 {
            if let message = envelope?.msg?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                throw MPGapHTTPError.serverMessage(code: code, message: message)
            }
            throw APIError.businessCode(code)
        }
    }

    private static func decodeEnvelope<T: Decodable>(data: Data, status: Int) throws -> T {
        let envelope = try? JSONDecoder().decode(StatusEnvelope.self, from: data)
        if status == 401 || envelope?.code == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else {
            throw APIError.httpStatus(status)
        }
        if let code = envelope?.code, code != 200 {
            if let message = envelope?.msg?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                throw MPGapHTTPError.serverMessage(code: code, message: message)
            }
            throw APIError.businessCode(code)
        }
        do {
            let decoded = try JSONDecoder().decode(DataEnvelope<T>.self, from: data)
            guard let payload = decoded.data else { throw APIError.malformedResponse }
            return payload
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.malformedResponse
        }
    }
}
