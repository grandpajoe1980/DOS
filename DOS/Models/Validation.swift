import Foundation

public enum RegistrationValidationError: Error, Equatable, LocalizedError {
    case noParticipants, blankParticipant, consentRequired, invalidSite

    public var errorDescription: String? {
        switch self {
        case .noParticipants: "Add at least one participant."
        case .blankParticipant: "Enter a name for every participant."
        case .consentRequired: "Review and accept the required waiver before continuing."
        case .invalidSite: "Choose a site belonging to this event."
        }
    }
}

public enum RegistrationValidator {
    public static func validate(_ request: RegistrationRequest, occurrence: EventOccurrence, requiredDocuments: Set<UUID>) throws {
        guard !request.participantNames.isEmpty else { throw RegistrationValidationError.noParticipants }
        guard request.participantNames.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw RegistrationValidationError.blankParticipant
        }
        guard requiredDocuments.isSubset(of: Set(request.acceptedDocumentIDs)) else { throw RegistrationValidationError.consentRequired }
        if let siteID = request.siteID, !occurrence.sites.contains(where: { $0.id == siteID }) {
            throw RegistrationValidationError.invalidSite
        }
    }
}
