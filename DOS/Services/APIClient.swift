import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum APIError: Error, LocalizedError, Equatable {
    case invalidResponse, unauthorized, conflict, server(status: Int), decoding
    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The service returned an invalid response."
        case .unauthorized: "Your session has expired. Please sign in again."
        case .conflict: "This information changed. Refresh and try again."
        case .server: "The service is temporarily unavailable."
        case .decoding: "The response could not be read."
        }
    }
}

public protocol EventServing: Sendable {
    func occurrences(organizationSlug: String) async throws -> [EventOccurrence]
    func register(_ request: RegistrationRequest, idempotencyKey: UUID) async throws -> Registration
    func recordAttendance(_ operation: AttendanceOperation) async throws
}

public struct APIClient: EventServing, Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL; self.session = session
        decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
    }

    public func occurrences(organizationSlug: String) async throws -> [EventOccurrence] {
        var componentCharacters = CharacterSet.urlPathAllowed
        componentCharacters.remove(charactersIn: "/?#")
        let slug = organizationSlug.addingPercentEncoding(withAllowedCharacters: componentCharacters) ?? organizationSlug
        return try await send(path: "v1/public/organizations/\(slug)/occurrences", method: "GET", body: Optional<Data>.none, idempotencyKey: nil)
    }

    public func register(_ request: RegistrationRequest, idempotencyKey: UUID) async throws -> Registration {
        try await send(path: "v1/registrations", method: "POST", body: encoder.encode(request), idempotencyKey: idempotencyKey)
    }

    public func recordAttendance(_ operation: AttendanceOperation) async throws {
        let _: EmptyResponse = try await send(path: "v1/attendance-events", method: "POST", body: encoder.encode(operation), idempotencyKey: operation.id)
    }

    private func send<Response: Decodable>(path: String, method: String, body: Data?, idempotencyKey: UUID?) async throws -> Response {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method; request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let idempotencyKey { request.setValue(idempotencyKey.uuidString, forHTTPHeaderField: "Idempotency-Key") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        switch http.statusCode {
        case 200..<300: break
        case 401, 403: throw APIError.unauthorized
        case 409: throw APIError.conflict
        default: throw APIError.server(status: http.statusCode)
        }
        if Response.self == EmptyResponse.self, data.isEmpty { return EmptyResponse() as! Response }
        do { return try decoder.decode(Response.self, from: data) } catch { throw APIError.decoding }
    }
}

private struct EmptyResponse: Codable { init() {} }
