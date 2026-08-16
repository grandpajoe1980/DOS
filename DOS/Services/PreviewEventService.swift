import Foundation

public actor PreviewEventService: EventServing {
    public static let organizationID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    public static let occurrenceID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    public static let waiverID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!

    public init() {}

    public func occurrences(organizationSlug: String) async throws -> [EventOccurrence] {
        try await Task.sleep(for: .milliseconds(250))
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: 12, to: Date()) ?? Date()
        let site = ServiceSite(id: UUID(uuidString: "40000000-0000-0000-0000-000000000001")!, organizationID: Self.organizationID, name: "Riverside Greenway", publicLocation: "East River neighborhood", accessibility: ["Step-free route", "Accessible restrooms", "Seated tasks available"], arrivalNotes: "Meet at the blue welcome tent. The precise entrance is shared after assignment.", softTarget: 80, hardSafetyLimit: 120)
        return [EventOccurrence(id: Self.occurrenceID, organizationID: Self.organizationID, title: "Riverside Renewal", summary: "Restore walking trails, prepare community garden beds, and make the riverfront welcoming for everyone.", startsAt: start, endsAt: start.addingTimeInterval(4 * 3600), timeZoneIdentifier: "America/New_York", state: .published, sites: [site])]
    }

    public func register(_ request: RegistrationRequest, idempotencyKey: UUID) async throws -> Registration {
        try await Task.sleep(for: .milliseconds(350))
        return Registration(id: idempotencyKey, organizationID: Self.organizationID, occurrenceID: request.occurrenceID, state: .submitted, version: 1)
    }

    public func recordAttendance(_ operation: AttendanceOperation) async throws {}
}
