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
