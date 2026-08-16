import Foundation
import Testing
@testable import DOSCore

private let organizationID = UUID()
private let site = ServiceSite(id: UUID(), organizationID: organizationID, name: "Park", publicLocation: "Downtown", accessibility: [], arrivalNotes: "", softTarget: 10, hardSafetyLimit: 20)
private let occurrence = EventOccurrence(id: UUID(), organizationID: organizationID, title: "Cleanup", summary: "", startsAt: Date(), endsAt: Date().addingTimeInterval(3600), timeZoneIdentifier: "UTC", state: .published, sites: [site])
private let waiverID = UUID()

@Test("A complete registration is valid")
func validRegistration() throws {
    let request = RegistrationRequest(occurrenceID: occurrence.id, siteID: site.id, participantNames: ["Sam"], teamMode: .individual, accommodations: nil, acceptedDocumentIDs: [waiverID])
    try RegistrationValidator.validate(request, occurrence: occurrence, requiredDocuments: [waiverID])
}

@Test("Every participant needs a name")
func participantNameRequired() {
    let request = RegistrationRequest(occurrenceID: occurrence.id, siteID: site.id, participantNames: ["  "], teamMode: .individual, accommodations: nil, acceptedDocumentIDs: [waiverID])
    #expect(throws: RegistrationValidationError.blankParticipant) {
        try RegistrationValidator.validate(request, occurrence: occurrence, requiredDocuments: [waiverID])
    }
}

@Test("Active consent evidence is required")
func consentRequired() {
    let request = RegistrationRequest(occurrenceID: occurrence.id, siteID: site.id, participantNames: ["Sam"], teamMode: .individual, accommodations: nil, acceptedDocumentIDs: [])
    #expect(throws: RegistrationValidationError.consentRequired) {
        try RegistrationValidator.validate(request, occurrence: occurrence, requiredDocuments: [waiverID])
    }
}

@Test("A site must belong to the occurrence")
func rejectsForeignSite() {
    let request = RegistrationRequest(occurrenceID: occurrence.id, siteID: UUID(), participantNames: ["Sam"], teamMode: .individual, accommodations: nil, acceptedDocumentIDs: [waiverID])
    #expect(throws: RegistrationValidationError.invalidSite) {
        try RegistrationValidator.validate(request, occurrence: occurrence, requiredDocuments: [waiverID])
    }
}
