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

@Test("Production configuration rejects missing and placeholder API hosts")
func productionConfigurationFailsClosed() {
    #expect(throws: AppRuntimeConfigurationError.missingAPIHost) {
        try AppRuntimeConfiguration(environment: "production", apiScheme: "https", apiHost: nil)
    }
    #expect(throws: AppRuntimeConfigurationError.placeholderAPIHost) {
        try AppRuntimeConfiguration(environment: "production", apiScheme: "https", apiHost: "api.example.invalid")
    }
    #expect(throws: AppRuntimeConfigurationError.insecureAPIScheme) {
        try AppRuntimeConfiguration(environment: "production", apiScheme: "http", apiHost: "api.example.org")
    }
}

@Test("Live service selection is stable and derived from validated configuration")
func liveServiceSelectionIsStable() throws {
    let configuration = try AppRuntimeConfiguration(environment: "production", apiScheme: "https", apiHost: "api.example.org")
    let first = AppDependencies.live(configuration: configuration)
    let second = AppDependencies.live(configuration: configuration)
    #expect(first.selection == .live(baseURL: configuration.apiBaseURL))
    #expect(second.selection == first.selection)
    #expect(first.selection != .preview)
}

@Test("UserProfile and Job models encode and decode with nullable organization")
func userProfileAndJobCoding() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let profileJSON = """
    {
        "id": "40000000-0000-4000-8000-000000000001",
        "display_name": "Jordan Volunteer",
        "state": "active",
        "version": 2
    }
    """
    let profile = try decoder.decode(UserProfile.self, from: Data(profileJSON.utf8))
    #expect(profile.displayName == "Jordan Volunteer")
    #expect(profile.state == .active)
    #expect(profile.version == 2)

    let personalJobJSON = """
    {
        "id": "70000000-0000-4000-8000-000000000001",
        "organization_id": null,
        "kind": "personal_data_export",
        "state": "queued",
        "created_at": "2027-01-16T12:00:00Z",
        "version": 1
    }
    """
    let personalJob = try decoder.decode(Job.self, from: Data(personalJobJSON.utf8))
    #expect(personalJob.organizationID == nil)
    #expect(personalJob.kind == .personalDataExport)
    #expect(personalJob.state == .queued)

    let tenantJobJSON = """
    {
        "id": "70000000-0000-4000-8000-000000000002",
        "organization_id": "10000000-0000-4000-8000-000000000001",
        "kind": "attendance_export",
        "state": "succeeded",
        "created_at": "2027-01-16T12:00:00Z",
        "version": 3
    }
    """
    let tenantJob = try decoder.decode(Job.self, from: Data(tenantJobJSON.utf8))
    #expect(tenantJob.organizationID == UUID(uuidString: "10000000-0000-4000-8000-000000000001"))
    #expect(tenantJob.kind == .attendanceExport)
    #expect(tenantJob.state == .succeeded)
}

@Test("InMemoryTokenStore stores and clears tokens safely")
func tokenStoreOperations() async {
    let store = InMemoryTokenStore()
    #expect(await store.getToken() == nil)
    await store.setToken("test-jwt-token")
    #expect(await store.getToken() == "test-jwt-token")
    await store.clear()
    #expect(await store.getToken() == nil)
}

@Test("APIErrorEnvelope formats human-readable message")
func apiErrorEnvelopeHandling() {
    let envelope = APIErrorEnvelope(code: "CONFLICT", message: "Resource was modified", requestID: "req-123")
    let error = APIError.serverWithEnvelope(status: 409, envelope: envelope)
    #expect(error.errorDescription == "Resource was modified")
}

#if DEBUG
@Test("Preview service requires an explicit debug-only selection")
func previewServiceSelectionIsExplicit() {
    #expect(AppDependencies.preview().selection == .preview)
}
#endif

