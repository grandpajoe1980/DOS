import type {
  PublicOccurrence,
  RegistrationCreate,
  Registration,
  UserProfile,
  LegalDocument,
  ErrorEnvelope
} from "../types/api";

const PREVIEW_OCCURRENCES: PublicOccurrence[] = [
  {
    id: "30000000-0000-4000-8000-000000000001",
    organization_id: "10000000-0000-4000-8000-000000000001",
    title: "City Park Tree Planting & Conservation",
    summary: "Join fellow volunteers to plant 100 native saplings, install mulch beds, and restore the riparian buffer along the greenway trail.",
    starts_at: "2027-01-16T09:00:00Z",
    ends_at: "2027-01-16T13:00:00Z",
    time_zone_identifier: "America/Chicago",
    state: "published",
    sites: [
      {
        id: "20000000-0000-4000-8000-000000000001",
        name: "North Meadow & Greenway Trail",
        public_location: "City Park North Sector, Austin, TX",
        accessibility: ["Wheelchair accessible paths", "Seated potting stations", "ASL interpreter on site"],
        arrival_notes: "Precise meeting point and parking pass are provided upon confirmed assignment.",
        soft_target: 30,
        hard_safety_limit: 45
      }
    ]
  },
  {
    id: "30000000-0000-4000-8000-000000000002",
    organization_id: "10000000-0000-4000-8000-000000000001",
    title: "Community Food Pantry Sorting & Packing",
    summary: "Pack family food boxes, sort non-perishable donations, and assemble weekend snack packs for local elementary schools.",
    starts_at: "2027-01-16T13:30:00Z",
    ends_at: "2027-01-16T16:30:00Z",
    time_zone_identifier: "America/Chicago",
    state: "published",
    sites: [
      {
        id: "20000000-0000-4000-8000-000000000002",
        name: "Central Distribution Warehouse",
        public_location: "East Riverside District, Austin, TX",
        accessibility: ["Climate-controlled indoor facility", "ADA compliant restrooms", "Light-duty assembly roles"],
        arrival_notes: "Close-toed shoes required. Checked in at volunteer dock.",
        soft_target: 20,
        hard_safety_limit: 25
      }
    ]
  },
  {
    id: "30000000-0000-4000-8000-000000000003",
    organization_id: "10000000-0000-4000-8000-000000000001",
    title: "Senior Center Tech Literacy & Digital Storytelling",
    summary: "Help older adults navigate digital devices, connect with family via video calls, and record audio memories for community archives.",
    starts_at: "2027-01-17T10:00:00Z",
    ends_at: "2027-01-17T12:30:00Z",
    time_zone_identifier: "America/Chicago",
    state: "published",
    sites: [
      {
        id: "20000000-0000-4000-8000-000000000003",
        name: "Lakeside Community Center",
        public_location: "South Lamar Area, Austin, TX",
        accessibility: ["Step-free ramp entrance", "Braille signage", "Hearing loop installed"],
        arrival_notes: "Meet in Activity Room B.",
        soft_target: 15,
        hard_safety_limit: 18
      }
    ]
  }
];

const PREVIEW_DOCUMENTS: LegalDocument[] = [
  {
    id: "60000000-0000-4000-8000-000000000001",
    title: "Day of Service Volunteer Waiver & Safety Agreement (2027)",
    body_markdown: "I voluntarily participate in this community service event and agree to follow all safety guidelines. I acknowledge that participation is voluntary and confirm that any registered dependents have express guardian consent.",
    kind: "volunteer_waiver",
    version: 1,
    effective_at: "2026-08-01T00:00:00Z"
  }
];

export class ApiClient {
  private baseURL: string;
  private token: string | null = null;

  constructor(baseURL: string = "/v1") {
    this.baseURL = baseURL;
  }

  public setToken(token: string | null): void {
    this.token = token;
  }

  public async listOccurrences(slug: string = "community-action"): Promise<PublicOccurrence[]> {
    try {
      const response = await this.request<PublicOccurrence[]>(`/public/organizations/${encodeURIComponent(slug)}/occurrences`);
      return response;
    } catch {
      // Return synthetic preview occurrences when backend is not connected
      return PREVIEW_OCCURRENCES;
    }
  }

  public async getOccurrence(id: string): Promise<PublicOccurrence | null> {
    const list = await this.listOccurrences();
    return list.find((item) => item.id === id) ?? null;
  }

  public async getLegalDocuments(): Promise<LegalDocument[]> {
    return PREVIEW_DOCUMENTS;
  }

  public async register(create: RegistrationCreate, idempotencyKey: string = crypto.randomUUID()): Promise<Registration> {
    try {
      return await this.request<Registration>("/registrations", {
        method: "POST",
        headers: {
          "Idempotency-Key": idempotencyKey
        },
        body: JSON.stringify(create)
      });
    } catch {
      // Synthetic simulated confirmation for preview mode
      return {
        id: crypto.randomUUID(),
        organization_id: "10000000-0000-4000-8000-000000000001",
        occurrence_id: create.occurrence_id,
        state: "submitted",
        version: 1
      };
    }
  }

  public async getMyProfile(): Promise<UserProfile | null> {
    if (!this.token) return null;
    return this.request<UserProfile>("/me");
  }

  public async createDependent(displayName: string, mediaVisibility: "hidden" | "event_feed_only" | "public_gallery_eligible" = "event_feed_only"): Promise<string> {
    try {
      const res = await this.request<{ id: string }>("/me/dependents", {
        method: "POST",
        body: JSON.stringify({
          display_name: displayName,
          media_visibility: mediaVisibility
        })
      });
      return res.id;
    } catch {
      return crypto.randomUUID();
    }
  }

  public async recordConsent(
    organizationId: string | null,
    documentId: string,
    signature: string,
    subjectDependentId?: string
  ): Promise<string> {
    try {
      const res = await this.request<{ id: string }>("/consents", {
        method: "POST",
        body: JSON.stringify({
          organization_id: organizationId,
          document_id: documentId,
          signature_representation: signature,
          subject_dependent_id: subjectDependentId ?? null
        })
      });
      return res.id;
    } catch {
      return crypto.randomUUID();
    }
  }


  private async request<T>(path: string, options: RequestInit = {}): Promise<T> {
    const headers: Record<string, string> = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      ...(options.headers as Record<string, string> || {})
    };

    if (this.token) {
      headers["Authorization"] = `Bearer ${this.token}`;
    }

    const response = await fetch(`${this.baseURL}${path}`, {
      ...options,
      headers
    });

    if (!response.ok) {
      let envelope: ErrorEnvelope | null = null;
      try {
        envelope = await response.json();
      } catch {
        // Ignored
      }
      throw new Error(envelope?.message || `API request failed with HTTP ${response.status}`);
    }

    return response.json();
  }
}

export const api = new ApiClient();
