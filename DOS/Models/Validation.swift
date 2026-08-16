import Foundation

public enum RegistrationValidationError: Error, Equatable, LocalizedError {
    case noParticipants, blankParticipant, consentRequired, invalidSite, occurrenceUnavailable, invalidSchedule, capacityExceeded

    public var errorDescription: String? {
        switch self {
        case .noParticipants: "Add at least one participant."
        case .blankParticipant: "Enter a name for every participant."
        case .consentRequired: "Review and accept the required waiver before continuing."
        case .invalidSite: "Choose a site belonging to this event."
        case .occurrenceUnavailable: "This event is not open for registration."
        case .invalidSchedule: "This event has an invalid schedule."
        case .capacityExceeded: "This site cannot safely accommodate the whole group."
        }
    }
}

public enum RegistrationValidator {
    public static func validate(_ request: RegistrationRequest, occurrence: EventOccurrence, requiredDocuments: Set<UUID>) throws {
        guard occurrence.state == .published else { throw RegistrationValidationError.occurrenceUnavailable }
        guard occurrence.startsAt < occurrence.endsAt else { throw RegistrationValidationError.invalidSchedule }
        guard request.occurrenceID == occurrence.id else { throw RegistrationValidationError.occurrenceUnavailable }
        guard !request.participantNames.isEmpty else { throw RegistrationValidationError.noParticipants }
        guard request.participantNames.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RegistrationValidationError.blankParticipant
        }
        guard requiredDocuments.isSubset(of: Set(request.acceptedDocumentIDs)) else { throw RegistrationValidationError.consentRequired }
        if let siteID = request.siteID {
            guard let site = occurrence.sites.first(where: { $0.id == siteID && $0.organizationID == occurrence.organizationID }) else {
                throw RegistrationValidationError.invalidSite
            }
            if let limit = site.hardSafetyLimit, request.participantNames.count > limit {
                throw RegistrationValidationError.capacityExceeded
            }
        }
    }
}
