import Foundation

public enum OrganizationRole: String, Codable, CaseIterable, Hashable, Sendable {
    case owner = "org_owner", organizer, mediaModerator = "media_moderator", siteLead = "site_lead"
}

public enum Capability: Sendable {
    case readPublishedEvent, register, viewRoster, checkAttendance, editProgramming, moderateMedia, manageOrganization
}

public struct AuthorizationContext: Sendable {
    public let organizationID: UUID
    public let roles: Set<OrganizationRole>
    public let assignedSiteIDs: Set<UUID>
    public let suspended: Bool

    public init(organizationID: UUID, roles: Set<OrganizationRole>, assignedSiteIDs: Set<UUID> = [], suspended: Bool = false) {
        self.organizationID = organizationID; self.roles = roles; self.assignedSiteIDs = assignedSiteIDs; self.suspended = suspended
    }

    public func permits(_ capability: Capability, organizationID: UUID, siteID: UUID? = nil) -> Bool {
        guard !suspended, self.organizationID == organizationID else { return false }
        if roles.contains(.owner) { return true }
        switch capability {
        case .readPublishedEvent: return true
        case .register: return roles.contains(.organizer)
        case .viewRoster, .checkAttendance:
            return roles.contains(.organizer) || (roles.contains(.siteLead) && siteID.map(assignedSiteIDs.contains) == true)
        case .editProgramming: return roles.contains(.organizer)
        case .moderateMedia: return roles.contains(.organizer) || roles.contains(.mediaModerator)
        case .manageOrganization: return false
        }
    }
}

public struct AssignmentCandidate: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let registrationID: UUID
    public let participantCount: Int
    public let teamMode: TeamMode
    public let eligibleSiteIDs: Set<UUID>
    public let preferredSiteID: UUID?
    public init(id: UUID = UUID(), registrationID: UUID, participantCount: Int, teamMode: TeamMode, eligibleSiteIDs: Set<UUID>, preferredSiteID: UUID? = nil) {
        self.id = id; self.registrationID = registrationID; self.participantCount = participantCount; self.teamMode = teamMode; self.eligibleSiteIDs = eligibleSiteIDs; self.preferredSiteID = preferredSiteID
    }
}

public struct SiteCapacity: Sendable {
    public let siteID: UUID
    public let softTarget: Int
    public let hardLimit: Int?
    public let occupied: Int
    public init(siteID: UUID, softTarget: Int, hardLimit: Int?, occupied: Int = 0) {
        self.siteID = siteID; self.softTarget = max(0, softTarget); self.hardLimit = hardLimit; self.occupied = max(0, occupied)
    }
}

public struct AssignmentPlan: Equatable, Sendable {
    public let assignments: [UUID: UUID]
    public let waitlisted: Set<UUID>
}

public enum AssignmentAllocator {
    /// Deterministic, side-effect-free planning. Hard limits are never exceeded; soft targets rank sites but are not caps.
    public static func plan(candidates: [AssignmentCandidate], capacities: [SiteCapacity]) -> AssignmentPlan {
        var used = Dictionary(uniqueKeysWithValues: capacities.map { ($0.siteID, $0.occupied) })
        let capacity = Dictionary(uniqueKeysWithValues: capacities.map { ($0.siteID, $0) })
        var assignments: [UUID: UUID] = [:], waitlisted: Set<UUID> = []
        for candidate in candidates.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            guard candidate.participantCount > 0 else { waitlisted.insert(candidate.registrationID); continue }
            let choices = candidate.eligibleSiteIDs.compactMap { id -> SiteCapacity? in
                guard let site = capacity[id], site.hardLimit.map({ used[id, default: 0] + candidate.participantCount <= $0 }) ?? true else { return nil }
                return site
            }.sorted {
                let lhsPreferred = $0.siteID == candidate.preferredSiteID
                let rhsPreferred = $1.siteID == candidate.preferredSiteID
                if lhsPreferred != rhsPreferred { return lhsPreferred }
                let lhsLoad = Double(used[$0.siteID, default: 0]) / Double(max(1, $0.softTarget))
                let rhsLoad = Double(used[$1.siteID, default: 0]) / Double(max(1, $1.softTarget))
                return lhsLoad == rhsLoad ? $0.siteID.uuidString < $1.siteID.uuidString : lhsLoad < rhsLoad
            }
            guard let selected = choices.first else { waitlisted.insert(candidate.registrationID); continue }
            assignments[candidate.registrationID] = selected.siteID
            used[selected.siteID, default: 0] += candidate.participantCount
        }
        return AssignmentPlan(assignments: assignments, waitlisted: waitlisted)
    }
}

public enum MediaState: String, Codable, Hashable, Sendable { case draft, uploadedPrivate = "uploaded_private", scanning, reviewPending = "review_pending", approved, rejected, published, unpublished, removed }
public enum MediaTransitionError: Error, Equatable { case invalidTransition, reasonRequired, minorUploader }

public struct MediaAsset: Identifiable, Equatable, Sendable {
    public let id: UUID
    public private(set) var state: MediaState
    public let uploaderIsAdult: Bool
    public private(set) var moderationReason: String?
    public init(id: UUID = UUID(), state: MediaState = .draft, uploaderIsAdult: Bool) { self.id = id; self.state = state; self.uploaderIsAdult = uploaderIsAdult }
    public mutating func transition(to next: MediaState, reason: String? = nil) throws {
        guard uploaderIsAdult else { throw MediaTransitionError.minorUploader }
        let allowed: [MediaState: Set<MediaState>] = [.draft: [.uploadedPrivate], .uploadedPrivate: [.scanning], .scanning: [.reviewPending, .rejected], .reviewPending: [.approved, .rejected], .approved: [.published, .unpublished], .published: [.unpublished, .removed], .unpublished: [.published, .removed]]
        guard allowed[state]?.contains(next) == true else { throw MediaTransitionError.invalidTransition }
        if [.rejected, .unpublished, .removed].contains(next), reason?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false { throw MediaTransitionError.reasonRequired }
        state = next; moderationReason = reason
    }
}

public struct SafetyShare: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let organizationID: UUID
    public let occurrenceID: UUID
    public let siteID: UUID
    public let recipientIDs: Set<UUID>
    public let expiresAt: Date
    public private(set) var stoppedAt: Date?
    public init(id: UUID = UUID(), organizationID: UUID, occurrenceID: UUID, siteID: UUID, recipientIDs: Set<UUID>, expiresAt: Date) {
        self.id = id; self.organizationID = organizationID; self.occurrenceID = occurrenceID; self.siteID = siteID; self.recipientIDs = recipientIDs; self.expiresAt = expiresAt
    }
    public func isActive(at date: Date = Date()) -> Bool { stoppedAt == nil && date < expiresAt }
    public mutating func stop(at date: Date = Date()) { if stoppedAt == nil { stoppedAt = date } }
}
