import Foundation

public struct Organization: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let slug: String
    public let timeZoneIdentifier: String

    public init(id: UUID, name: String, slug: String, timeZoneIdentifier: String) {
        self.id = id; self.name = name; self.slug = slug; self.timeZoneIdentifier = timeZoneIdentifier
    }
}

public enum OccurrenceState: String, Codable, Hashable, Sendable {
    case draft, published, archived, unknown
    public init(from decoder: Decoder) throws { self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}

public struct ServiceSite: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let organizationID: UUID
    public let name: String
    public let publicLocation: String
    public let accessibility: [String]
    public let arrivalNotes: String
    public let softTarget: Int
    public let hardSafetyLimit: Int?

    public init(id: UUID, organizationID: UUID, name: String, publicLocation: String, accessibility: [String], arrivalNotes: String, softTarget: Int, hardSafetyLimit: Int?) {
        self.id = id; self.organizationID = organizationID; self.name = name; self.publicLocation = publicLocation
        self.accessibility = accessibility; self.arrivalNotes = arrivalNotes; self.softTarget = softTarget; self.hardSafetyLimit = hardSafetyLimit
    }
}

public struct EventOccurrence: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let organizationID: UUID
    public let title: String
    public let summary: String
    public let startsAt: Date
    public let endsAt: Date
    public let timeZoneIdentifier: String
    public let state: OccurrenceState
    public let sites: [ServiceSite]

    public init(id: UUID, organizationID: UUID, title: String, summary: String, startsAt: Date, endsAt: Date, timeZoneIdentifier: String, state: OccurrenceState, sites: [ServiceSite]) {
        self.id = id; self.organizationID = organizationID; self.title = title; self.summary = summary
        self.startsAt = startsAt; self.endsAt = endsAt; self.timeZoneIdentifier = timeZoneIdentifier; self.state = state; self.sites = sites
    }
}

public enum TeamMode: String, Codable, CaseIterable, Hashable, Sendable { case individual, preferTogether = "prefer_together", mustStayTogether = "must_stay_together" }
public enum RegistrationState: String, Codable, Hashable, Sendable {
    case draft, submitted, waitlisted, assigned, cancelled, unknown
    public init(from decoder: Decoder) throws { self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown }
}

public struct RegistrationRequest: Codable, Equatable, Sendable {
    public let occurrenceID: UUID
    public let siteID: UUID?
    public let participantNames: [String]
    public let teamMode: TeamMode
    public let accommodations: String?
    public let acceptedDocumentIDs: [UUID]

    public init(occurrenceID: UUID, siteID: UUID?, participantNames: [String], teamMode: TeamMode, accommodations: String?, acceptedDocumentIDs: [UUID]) {
        self.occurrenceID = occurrenceID; self.siteID = siteID; self.participantNames = participantNames
        self.teamMode = teamMode; self.accommodations = accommodations; self.acceptedDocumentIDs = acceptedDocumentIDs
    }
}

public struct Registration: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let organizationID: UUID
    public let occurrenceID: UUID
    public let state: RegistrationState
    public let version: Int
}

public struct AttendanceOperation: Codable, Identifiable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case checkIn = "check_in", checkOut = "check_out" }
    public let id: UUID
    public let organizationID: UUID
    public let registrationID: UUID
    public let kind: Kind
    public let occurredAt: Date

    public init(id: UUID = UUID(), organizationID: UUID, registrationID: UUID, kind: Kind, occurredAt: Date = Date()) {
        self.id = id; self.organizationID = organizationID; self.registrationID = registrationID; self.kind = kind; self.occurredAt = occurredAt
    }
}

public enum ProfileState: String, Codable, Hashable, Sendable {
    case active, suspended, deleted, unknown
    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

public struct UserProfile: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let state: ProfileState
    public let version: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case state
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: UUID, displayName: String, state: ProfileState = .active, version: Int = 1, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.displayName = displayName
        self.state = state
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct OrganizationMembership: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let organizationID: UUID
    public let profileID: UUID
    public let state: String
    public let roles: [String]
    public let version: Int
    public let createdAt: Date?
    public let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case profileID = "profile_id"
        case state
        case roles
        case version
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    public init(id: UUID, organizationID: UUID, profileID: UUID, state: String = "active", roles: [String] = [], version: Int = 1, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.organizationID = organizationID
        self.profileID = profileID
        self.state = state
        self.roles = roles
        self.version = version
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public enum JobKind: String, Codable, Hashable, Sendable {
    case personalDataExport = "personal_data_export"
    case attendanceExport = "attendance_export"
    case hoursExport = "hours_export"
    case tasksExport = "tasks_export"
    case impactExport = "impact_export"
    case unknown

    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

public enum JobState: String, Codable, Hashable, Sendable {
    case queued, running, succeeded, failed, expired, unknown
    public init(from decoder: Decoder) throws {
        self = Self(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
    }
}

public struct Job: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let organizationID: UUID?
    public let kind: JobKind
    public let state: JobState
    public let createdAt: Date
    public let resultURL: URL?
    public let resultExpiresAt: Date?
    public let version: Int

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case kind
        case state
        case createdAt = "created_at"
        case resultURL = "result_url"
        case resultExpiresAt = "result_expires_at"
        case version
    }

    public init(
        id: UUID,
        organizationID: UUID? = nil,
        kind: JobKind,
        state: JobState,
        createdAt: Date = Date(),
        resultURL: URL? = nil,
        resultExpiresAt: Date? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.organizationID = organizationID
        self.kind = kind
        self.state = state
        self.createdAt = createdAt
        self.resultURL = resultURL
        self.resultExpiresAt = resultExpiresAt
        self.version = version
    }
}

public enum ExportScope: String, Codable, Hashable, Sendable {
    case profile
    case allEligiblePersonalData = "all_eligible_personal_data"
}

public enum ExportFormat: String, Codable, Hashable, Sendable {
    case json, zip, csv
}

public struct PersonalExportRequest: Codable, Equatable, Sendable {
    public let scope: ExportScope
    public let format: ExportFormat

    public init(scope: ExportScope, format: ExportFormat) {
        self.scope = scope
        self.format = format
    }
}

