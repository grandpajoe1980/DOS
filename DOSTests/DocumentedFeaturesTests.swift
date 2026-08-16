import Foundation
import Testing
@testable import DOSCore

@Test("Authorization is tenant and site scoped")
func authorizationScope() {
    let tenant = UUID(), site = UUID()
    let lead = AuthorizationContext(organizationID: tenant, roles: [.siteLead], assignedSiteIDs: [site])
    #expect(lead.permits(.checkAttendance, organizationID: tenant, siteID: site))
    #expect(!lead.permits(.checkAttendance, organizationID: tenant, siteID: UUID()))
    #expect(!lead.permits(.checkAttendance, organizationID: UUID(), siteID: site))
}

@Test("Allocator keeps groups together and enforces hard capacity")
func allocationCapacity() {
    let site = UUID(), first = UUID(), second = UUID()
    let candidates = [
        AssignmentCandidate(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, registrationID: first, participantCount: 3, teamMode: .mustStayTogether, eligibleSiteIDs: [site]),
        AssignmentCandidate(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, registrationID: second, participantCount: 2, teamMode: .individual, eligibleSiteIDs: [site])
    ]
    let plan = AssignmentAllocator.plan(candidates: candidates, capacities: [SiteCapacity(siteID: site, softTarget: 2, hardLimit: 4)])
    #expect(plan.assignments[first] == site)
    #expect(plan.waitlisted == [second])
}

@Test("Media requires moderation reasons and prevents minor uploads")
func mediaLifecycle() throws {
    var asset = MediaAsset(uploaderIsAdult: true)
    try asset.transition(to: .uploadedPrivate)
    try asset.transition(to: .scanning)
    try asset.transition(to: .reviewPending)
    #expect(throws: MediaTransitionError.reasonRequired) { try asset.transition(to: .rejected) }
    try asset.transition(to: .rejected, reason: "Consent unavailable")
    var minorAsset = MediaAsset(uploaderIsAdult: false)
    #expect(throws: MediaTransitionError.minorUploader) { try minorAsset.transition(to: .uploadedPrivate) }
}

@Test("Safety sharing stops manually and expires automatically")
func safetyShareExpiry() {
    let now = Date()
    var share = SafetyShare(organizationID: UUID(), occurrenceID: UUID(), siteID: UUID(), recipientIDs: [UUID()], expiresAt: now.addingTimeInterval(60))
    #expect(share.isActive(at: now))
    #expect(!share.isActive(at: now.addingTimeInterval(61)))
    share.stop(at: now)
    #expect(!share.isActive(at: now))
}

@Test("Server enum additions decode safely")
func unknownStates() throws {
    #expect(try JSONDecoder().decode(OccurrenceState.self, from: Data("\"new_server_state\"".utf8)) == .unknown)
    #expect(try JSONDecoder().decode(RegistrationState.self, from: Data("\"new_server_state\"".utf8)) == .unknown)
}
