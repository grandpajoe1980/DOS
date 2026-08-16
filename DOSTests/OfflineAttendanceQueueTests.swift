import Foundation
import Testing
@testable import DOSCore

private actor AttendanceRecorder: EventServing {
    var received: [AttendanceOperation] = []
    func occurrences(organizationSlug: String) async throws -> [EventOccurrence] { [] }
    func register(_ request: RegistrationRequest, idempotencyKey: UUID) async throws -> Registration { fatalError() }
    func recordAttendance(_ operation: AttendanceOperation) async throws { received.append(operation) }
    func count() -> Int { received.count }
}

@Test("Queue deduplicates operations and removes reconciled work")
func queueReconciliation() async throws {
    let queue = try OfflineAttendanceQueue()
    let operation = AttendanceOperation(organizationID: UUID(), registrationID: UUID(), kind: .checkIn)
    try await queue.enqueue(operation)
    try await queue.enqueue(operation)
    #expect(await queue.pending().count == 1)

    let recorder = AttendanceRecorder()
    let failures = await queue.reconcile(using: recorder)
    #expect(failures.isEmpty)
    #expect(await queue.pending().isEmpty)
    #expect(await recorder.count() == 1)
}

@Test("Queue restores persisted operations")
func persistenceRoundTrip() async throws {
    let operation = AttendanceOperation(organizationID: UUID(), registrationID: UUID(), kind: .checkOut)
    let data = try JSONEncoder().encode([operation])
    let queue = try OfflineAttendanceQueue(data: data)
    #expect(await queue.pending() == [operation])
}
