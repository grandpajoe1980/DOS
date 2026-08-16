import Foundation

public actor OfflineAttendanceQueue {
    public typealias Persist = @Sendable (Data) throws -> Void
    private var operations: [AttendanceOperation]
    private let persist: Persist
    private let encoder = JSONEncoder()

    public init(data: Data? = nil, persist: @escaping Persist = { _ in }) throws {
        if let data { operations = try JSONDecoder().decode([AttendanceOperation].self, from: data) } else { operations = [] }
        self.persist = persist
    }

    public func enqueue(_ operation: AttendanceOperation) throws {
        guard !operations.contains(where: { $0.id == operation.id }) else { return }
        operations.append(operation); try save()
    }

    public func pending() -> [AttendanceOperation] { operations }

    public func reconcile(using service: any EventServing) async -> [UUID: Error] {
        var failures: [UUID: Error] = [:]
        for operation in operations {
            do {
                try await service.recordAttendance(operation)
                operations.removeAll { $0.id == operation.id }
                try save()
            } catch { failures[operation.id] = error }
        }
        return failures
    }

    private func save() throws { try persist(encoder.encode(operations)) }
}
