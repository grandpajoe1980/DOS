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
    let requiredDocumentIDs: Set<UUID>
    private let service: (any EventServing)?
    private let organizationSlug: String
    private let configurationErrorMessage: String?

    init(dependencies: AppDependencies) {
        service = dependencies.service
        organizationSlug = dependencies.organizationSlug
        requiredDocumentIDs = dependencies.requiredDocumentIDs
        configurationErrorMessage = nil
    }

    init(configurationError: any Error) {
        service = nil
        organizationSlug = ""
        requiredDocumentIDs = []
        let message = configurationError.localizedDescription
        configurationErrorMessage = message
        loadState = .failed(message)
    }

    func load() async {
        guard let service else {
            loadState = .failed(configurationErrorMessage ?? "The app is not configured.")
            return
        }
        loadState = .loading
        do {
            occurrences = try await service.occurrences(organizationSlug: organizationSlug)
            loadState = occurrences.isEmpty ? .empty : .loaded
        } catch { loadState = .failed(error.localizedDescription) }
    }

    func submit(_ request: RegistrationRequest) async -> Bool {
        guard let service else {
            submissionError = configurationErrorMessage ?? "The app is not configured."
            return false
        }
        isSubmitting = true; submissionError = nil
        defer { isSubmitting = false }
        do {
            guard let occurrence = occurrences.first(where: { $0.id == request.occurrenceID }) else { return false }
            try RegistrationValidator.validate(request, occurrence: occurrence, requiredDocuments: requiredDocumentIDs)
            registration = try await service.register(request, idempotencyKey: UUID())
            return true
        } catch { submissionError = error.localizedDescription; return false }
    }
}
