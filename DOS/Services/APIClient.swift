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

public enum AppEnvironment: String, Equatable, Sendable {
    case debug, staging, production
}

public enum AppRuntimeConfigurationError: Error, LocalizedError, Equatable, Sendable {
    case missingEnvironment
    case unsupportedEnvironment
    case missingAPIScheme
    case insecureAPIScheme
    case missingAPIHost
    case placeholderAPIHost
    case invalidAPIURL

    public var errorDescription: String? {
        switch self {
        case .missingEnvironment: "The app environment is not configured."
        case .unsupportedEnvironment: "The app environment is not supported."
        case .missingAPIScheme, .missingAPIHost: "The service address is not configured."
        case .insecureAPIScheme: "The service address must use a secure connection."
        case .placeholderAPIHost: "The service address is still a placeholder."
        case .invalidAPIURL: "The service address is invalid."
        }
    }
}

public struct AppRuntimeConfiguration: Equatable, Sendable {
    public let environment: AppEnvironment
    public let apiBaseURL: URL

    public init(environment: String?, apiScheme: String?, apiHost: String?) throws {
        let environmentValue = environment?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !environmentValue.isEmpty else { throw AppRuntimeConfigurationError.missingEnvironment }
        guard let environment = AppEnvironment(rawValue: environmentValue) else { throw AppRuntimeConfigurationError.unsupportedEnvironment }

        let scheme = apiScheme?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !scheme.isEmpty else { throw AppRuntimeConfigurationError.missingAPIScheme }
        guard scheme == "https" else { throw AppRuntimeConfigurationError.insecureAPIScheme }

        let host = apiHost?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !host.isEmpty else { throw AppRuntimeConfigurationError.missingAPIHost }
        guard host != "invalid", !host.hasSuffix(".invalid") else { throw AppRuntimeConfigurationError.placeholderAPIHost }
        guard !host.contains(where: { "/?#@".contains($0) }) else { throw AppRuntimeConfigurationError.invalidAPIURL }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        guard let url = components.url, url.host == host else { throw AppRuntimeConfigurationError.invalidAPIURL }
        self.environment = environment
        self.apiBaseURL = url
    }

    public init(bundle: Bundle) throws {
        try self.init(
            environment: bundle.object(forInfoDictionaryKey: "DOSAppEnvironment") as? String,
            apiScheme: bundle.object(forInfoDictionaryKey: "DOSAPIScheme") as? String,
            apiHost: bundle.object(forInfoDictionaryKey: "DOSAPIHost") as? String
        )
    }
}

public enum AppServiceSelection: Equatable, Sendable {
    case preview
    case live(baseURL: URL)
}

public struct AppDependencies: Sendable {
    public let service: any EventServing
    public let selection: AppServiceSelection
    public let organizationSlug: String
    public let requiredDocumentIDs: Set<UUID>

    public init(service: any EventServing, selection: AppServiceSelection, organizationSlug: String, requiredDocumentIDs: Set<UUID>) {
        self.service = service
        self.selection = selection
        self.organizationSlug = organizationSlug
        self.requiredDocumentIDs = requiredDocumentIDs
    }

    public static func live(configuration: AppRuntimeConfiguration, session: URLSession = .shared) -> Self {
        Self(
            service: APIClient(baseURL: configuration.apiBaseURL, session: session),
            selection: .live(baseURL: configuration.apiBaseURL),
            organizationSlug: "community-action",
            requiredDocumentIDs: []
        )
    }
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
