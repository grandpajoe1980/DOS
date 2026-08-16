import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    enum LoadState { case loading, loaded, empty, failed(String) }
    @Published private(set) var loadState: LoadState = .loading
    @Published private(set) var occurrences: [EventOccurrence] = []
    @Published var selectedOccurrence: EventOccurrence?
    @Published var registration: Registration?
    @Published var isSubmitting = false
    @Published var submissionError: String?
    private let service: any EventServing

    init(service: any EventServing = PreviewEventService()) { self.service = service }

    func load() async {
        loadState = .loading
        do {
            occurrences = try await service.occurrences(organizationSlug: "community-action")
            loadState = occurrences.isEmpty ? .empty : .loaded
        } catch { loadState = .failed(error.localizedDescription) }
    }

    func submit(_ request: RegistrationRequest) async -> Bool {
        isSubmitting = true; submissionError = nil
        defer { isSubmitting = false }
        do {
            guard let occurrence = occurrences.first(where: { $0.id == request.occurrenceID }) else { return false }
            try RegistrationValidator.validate(request, occurrence: occurrence, requiredDocuments: [PreviewEventService.waiverID])
            registration = try await service.register(request, idempotencyKey: UUID())
            return true
        } catch { submissionError = error.localizedDescription; return false }
    }
}
