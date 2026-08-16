export type UUID = string;
export type Timestamp = string;

export interface Organization {
  id: UUID;
  name: string;
  slug: string;
  time_zone_identifier: string;
}

export interface PublicSite {
  id: UUID;
  name: string;
  public_location: string;
  accessibility: string[];
  arrival_notes: string;
  soft_target: number;
  hard_safety_limit?: number | null;
}

export interface PublicOccurrence {
  id: UUID;
  organization_id: UUID;
  title: string;
  summary: string;
  starts_at: Timestamp;
  ends_at: Timestamp;
  time_zone_identifier: string;
  state: "draft" | "published" | "archived" | "unknown";
  sites: PublicSite[];
}

export type TeamMode = "individual" | "prefer_together" | "must_stay_together";

export interface ParticipantInput {
  profile_id?: UUID;
  dependent_id?: UUID;
}

export interface RegistrationCreate {
  occurrence_id: UUID;
  site_id?: UUID | null;
  participant_names: string[];
  team_mode: TeamMode;
  accommodations?: string | null;
  accepted_document_ids: UUID[];
}

export interface Registration {
  id: UUID;
  organization_id: UUID;
  occurrence_id: UUID;
  state: "draft" | "submitted" | "waitlisted" | "assigned" | "cancelled" | "unknown";
  version: number;
}

export interface UserProfile {
  id: UUID;
  display_name: string;
  state: "active" | "suspended" | "deleted";
  version: number;
  created_at?: Timestamp;
  updated_at?: Timestamp;
}

export interface LegalDocument {
  id: UUID;
  organization_id?: UUID | null;
  title: string;
  body_markdown: string;
  kind: "volunteer_waiver" | "guardian_consent" | "media_release" | "privacy_notice";
  version: number;
  effective_at: Timestamp;
}

export interface Job {
  id: UUID;
  organization_id: UUID | null;
  kind: "personal_data_export" | "attendance_export" | "hours_export" | "tasks_export" | "impact_export";
  state: "queued" | "running" | "succeeded" | "failed" | "expired";
  created_at: Timestamp;
  result_url?: string | null;
  result_expires_at?: Timestamp | null;
  version: number;
}

export interface ErrorEnvelope {
  code: string;
  message: string;
  request_id?: string | null;
  details?: Record<string, string> | null;
}

export interface Dependent {
  id: UUID;
  guardian_profile_id?: UUID;
  display_name: string;
  media_visibility: "hidden" | "event_feed_only" | "public_gallery_eligible";
  created_at?: Timestamp;
  updated_at?: Timestamp;
}

export interface ConsentRecord {
  id: UUID;
  organization_id?: UUID | null;
  document_id: UUID;
  signer_profile_id: UUID;
  subject_profile_id?: UUID | null;
  subject_dependent_id?: UUID | null;
  signature_representation: string;
  signed_at: Timestamp;
}

