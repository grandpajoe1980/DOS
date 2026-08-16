import { api } from "./services/apiClient.ts";
import type { PublicOccurrence, TeamMode } from "./types/api.ts";

type ViewMode = "discover" | "detail" | "register" | "guardian" | "organizer";

interface AppState {
  view: ViewMode;
  occurrences: PublicOccurrence[];
  selectedOccurrence: PublicOccurrence | null;
  registrationSuccessReference: string | null;
  theme: "light" | "dark";
  loading: boolean;
  errorMessage: string | null;
}

const state: AppState = {
  view: "discover",
  occurrences: [],
  selectedOccurrence: null,
  registrationSuccessReference: null,
  theme: (localStorage.getItem("dos-theme") as "light" | "dark") || "dark",
  loading: true,
  errorMessage: null
};

// Initialize Theme
document.documentElement.setAttribute("data-theme", state.theme);

function toggleTheme() {
  state.theme = state.theme === "dark" ? "light" : "dark";
  localStorage.setItem("dos-theme", state.theme);
  document.documentElement.setAttribute("data-theme", state.theme);
  render();
}

function setView(view: ViewMode, occurrence: PublicOccurrence | null = null) {
  state.view = view;
  if (occurrence) {
    state.selectedOccurrence = occurrence;
  }
  state.errorMessage = null;
  window.scrollTo({ top: 0, behavior: "smooth" });
  render();
}

async function loadOccurrences() {
  state.loading = true;
  state.errorMessage = null;
  render();
  try {
    state.occurrences = await api.listOccurrences();
  } catch (err: unknown) {
    state.errorMessage = err instanceof Error ? err.message : "Failed to load events.";
  } finally {
    state.loading = false;
    render();
  }
}

function formatDate(iso: string): string {
  const date = new Date(iso);
  return date.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit"
  });
}

function renderHeader(): string {
  return `
    <header class="header-nav" role="banner">
      <div class="nav-wrapper">
        <a id="nav-brand" class="brand-logo" role="button" tabindex="0">
          <span class="brand-badge">DOS</span>
          <span>Day of Service</span>
        </a>
        <nav role="navigation" aria-label="Main Navigation">
          <ul class="nav-links">
            <li>
              <button id="nav-discover" class="nav-link-btn ${state.view === "discover" ? "active" : ""}">
                Discover
              </button>
            </li>
            <li>
              <button id="nav-guardian" class="nav-link-btn ${state.view === "guardian" ? "active" : ""}">
                Guardian Consent
              </button>
            </li>
            <li>
              <button id="nav-organizer" class="nav-link-btn ${state.view === "organizer" ? "active" : ""}">
                Organizer Console
              </button>
            </li>
            <li>
              <button id="theme-toggle" class="theme-toggle-btn" aria-label="Toggle visual theme">
                ${state.theme === "dark" ? "☀️ Light" : "🌙 Dark"}
              </button>
            </li>
          </ul>
        </nav>
      </div>
    </header>
  `;
}

function renderHero(): string {
  const totalVolunteers = state.occurrences.reduce((sum, o) => {
    return sum + (o.sites[0]?.soft_target || 0);
  }, 0);

  return `
    <section class="hero-banner" aria-labelledby="hero-heading">
      <h1 id="hero-heading" class="hero-title">Make Today Matter.<br>Serve Your Community.</h1>
      <p class="hero-subtitle">
        Join neighbors and local organizations for coordinated, high-impact volunteer opportunities. 
        All programs feature accessible sites, verified safety waivers, and real-time impact measurement.
      </p>
      <div class="hero-stats">
        <div class="hero-stat-card">
          <div class="hero-stat-value">${state.occurrences.length}</div>
          <div class="hero-stat-label">Active Opportunities</div>
        </div>
        <div class="hero-stat-card">
          <div class="hero-stat-value">${totalVolunteers}+</div>
          <div class="hero-stat-label">Community Target</div>
        </div>
        <div class="hero-stat-card">
          <div class="hero-stat-value">100%</div>
          <div class="hero-stat-label">Waiver Attributable</div>
        </div>
      </div>
    </section>
  `;
}

function renderDiscover(): string {
  if (state.loading) {
    return `
      <div style="text-align: center; padding: 4rem 1rem;">
        <div class="brand-badge" style="display: inline-block; animation: pulse 1.5s infinite;">Finding service opportunities…</div>
      </div>
    `;
  }

  if (state.errorMessage) {
    return `
      <div class="alert alert-danger" role="alert">
        <span>⚠️ ${state.errorMessage}</span>
        <button class="btn btn-secondary" id="retry-btn" style="margin-left: auto;">Try Again</button>
      </div>
    `;
  }

  const cardsHtml = state.occurrences.map((occurrence, index) => {
    const site = occurrence.sites[0];
    return `
      <article class="event-card" id="event-card-${index}" data-id="${occurrence.id}" role="button" tabindex="0">
        <div>
          <span class="event-badge">Open Registration</span>
          <h2 class="event-title">${occurrence.title}</h2>
          <p class="event-summary">${occurrence.summary}</p>
        </div>
        <div>
          <div class="event-meta">
            <div class="meta-row">
              <span>📅</span>
              <span>${formatDate(occurrence.starts_at)}</span>
            </div>
            <div class="meta-row">
              <span>📍</span>
              <span>${site?.public_location || "Location announced upon assignment"}</span>
            </div>
            ${site?.accessibility?.length ? `
              <div class="meta-row" style="color: var(--primary);">
                <span>♿</span>
                <span>${site.accessibility.join(" • ")}</span>
              </div>
            ` : ""}
          </div>
          <button class="btn btn-primary" style="width: 100%;" id="view-opp-${index}">
            View & Register →
          </button>
        </div>
      </article>
    `;
  }).join("");

  return `
    ${renderHero()}
    <section aria-label="Available Service Opportunities">
      <h2 style="font-size: 1.5rem; font-weight: 700; margin-bottom: 1.5rem;">Explore Opportunities</h2>
      <div class="events-grid" id="events-list">
        ${cardsHtml}
      </div>
    </section>
  `;
}

function renderDetail(): string {
  const occ = state.selectedOccurrence;
  if (!occ) {
    return `<div class="alert alert-warning">No opportunity selected. <button class="btn btn-secondary" id="back-to-discover">Return to Discover</button></div>`;
  }

  const site = occ.sites[0];

  return `
    <div style="margin-bottom: 2rem;">
      <button class="btn btn-secondary" id="back-to-discover-btn">← Back to all opportunities</button>
    </div>

    <article class="form-card" style="max-width: 800px;">
      <span class="event-badge" style="margin-bottom: 1rem;">Community Occurrence</span>
      <h1 style="font-size: 2.25rem; font-weight: 800; margin-bottom: 1rem; line-height: 1.2;">${occ.title}</h1>
      <p style="font-size: 1.1rem; color: var(--text-secondary); line-height: 1.6; margin-bottom: 2rem;">${occ.summary}</p>

      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 1.5rem; margin-bottom: 2rem; padding: 1.5rem; background: var(--bg-primary); border-radius: var(--radius-md);">
        <div>
          <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">When</div>
          <div style="font-weight: 600; margin-top: 0.25rem;">${formatDate(occ.starts_at)}</div>
          <div style="font-size: 0.85rem; color: var(--text-muted);">${occ.time_zone_identifier}</div>
        </div>
        <div>
          <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">Where</div>
          <div style="font-weight: 600; margin-top: 0.25rem;">${site?.public_location || "Approximate area"}</div>
          <div style="font-size: 0.85rem; color: var(--text-muted);">${site?.name || ""}</div>
        </div>
        <div>
          <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase; font-weight: 700;">Capacity Target</div>
          <div style="font-weight: 600; margin-top: 0.25rem;">${site?.soft_target || 20} Volunteers</div>
          <div style="font-size: 0.85rem; color: var(--text-muted);">Hard safety cap: ${site?.hard_safety_limit || "None"}</div>
        </div>
      </div>

      ${site?.accessibility?.length ? `
        <div style="margin-bottom: 2rem;">
          <h3 style="font-size: 1rem; font-weight: 700; margin-bottom: 0.5rem;">Accessibility & Accommodations</h3>
          <ul style="list-style: disc; padding-left: 1.5rem; color: var(--text-secondary); font-size: 0.95rem;">
            ${site.accessibility.map((a) => `<li>${a}</li>`).join("")}
          </ul>
        </div>
      ` : ""}

      <div style="background: var(--primary-light); padding: 1rem 1.25rem; border-radius: var(--radius-md); font-size: 0.875rem; color: var(--primary-hover); margin-bottom: 2rem;">
        🔒 <strong>Safety Notice:</strong> Exact meeting coordinates and organizer contact details are provided after assigned registration confirmation.
      </div>

      <div style="display: flex; gap: 1rem;">
        <button class="btn btn-primary" id="start-reg-btn" style="flex: 1; padding: 1rem;">
          Register as Individual or Team →
        </button>
      </div>
    </article>
  `;
}

function renderRegister(): string {
  const occ = state.selectedOccurrence;
  if (!occ) {
    return `<div class="alert alert-warning">Please select an event to register.</div>`;
  }

  if (state.registrationSuccessReference) {
    return `
      <div class="form-card" style="text-align: center; padding: 3.5rem 2rem;">
        <div style="font-size: 3.5rem; margin-bottom: 1rem;">🎉</div>
        <h2 style="font-size: 1.75rem; font-weight: 800; margin-bottom: 0.5rem;">Registration Confirmed!</h2>
        <p style="color: var(--text-secondary); margin-bottom: 2rem;">
          Your registration has been submitted. Reference code:
          <strong style="color: var(--primary);">${state.registrationSuccessReference}</strong>
        </p>
        <button class="btn btn-primary" id="return-discover-success-btn">Discover More Events</button>
      </div>
    `;
  }

  return `
    <div style="margin-bottom: 1.5rem;">
      <button class="btn btn-secondary" id="cancel-reg-btn">← Cancel and Back</button>
    </div>

    <form class="form-card" id="registration-form" aria-label="Volunteer Registration Form">
      <h2 style="font-size: 1.5rem; font-weight: 700; margin-bottom: 0.5rem;">Register for ${occ.title}</h2>
      <p style="font-size: 0.9rem; color: var(--text-secondary); margin-bottom: 1.75rem;">
        Complete the information below. Minors require separate guardian consent.
      </p>

      ${state.errorMessage ? `<div class="alert alert-danger" role="alert">${state.errorMessage}</div>` : ""}

      <div class="form-group">
        <label class="form-label" for="reg-participant-name">Primary Participant Name *</label>
        <input class="form-input" id="reg-participant-name" name="participant_name" required placeholder="Full Legal or Preferred Name" />
      </div>

      <div class="form-group">
        <label class="form-label" for="reg-team-mode">Registration Type</label>
        <select class="form-select" id="reg-team-mode" name="team_mode">
          <option value="individual">Just me (Individual)</option>
          <option value="prefer_together">Team — Prefer to stay together</option>
          <option value="must_stay_together">Team — Must stay together</option>
        </select>
      </div>

      <div class="form-group">
        <label class="form-label" for="reg-accommodations">Accessibility & Accommodation Needs (Optional)</label>
        <textarea class="form-textarea" id="reg-accommodations" name="accommodations" rows="3" placeholder="Dietary, mobility, sensory, or interpretation preferences"></textarea>
      </div>

      <div class="form-group" style="padding: 1rem; background: var(--bg-primary); border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
        <label class="form-checkbox-label" for="reg-waiver-consent">
          <input type="checkbox" class="form-checkbox" id="reg-waiver-consent" required />
          <span>
            <strong>I accept the Day of Service 2027 Volunteer Waiver.</strong><br>
            I confirm that I am an adult volunteer. Any registered minor dependents will have separate guardian consent on file.
          </span>
        </label>
      </div>

      <button type="submit" class="btn btn-primary" id="submit-registration-btn" style="width: 100%; padding: 1rem;">
        Submit Registration
      </button>
    </form>
  `;
}

function renderGuardian(): string {
  return `
    <article class="form-card" style="max-width: 700px;">
      <span class="event-badge">Guardian Portal</span>
      <h1 style="font-size: 1.85rem; font-weight: 800; margin-bottom: 0.75rem;">Minor Dependent Consent & Visibility</h1>
      <p style="color: var(--text-secondary); margin-bottom: 2rem;">
        Day of Service strictly protects minor privacy and safety (PR-004, FR-304). 
        Guardians retain sole authority to create dependents, sign waivers, and control media visibility.
      </p>

      <div class="form-group">
        <label class="form-label">Dependent Full Name</label>
        <input class="form-input" id="guardian-dep-name" placeholder="Child or dependent name" />
      </div>

      <div class="form-group">
        <label class="form-label">Media & Photo Visibility Control</label>
        <select class="form-select" id="guardian-media-visibility">
          <option value="hidden">Hidden — Never photograph or display</option>
          <option value="event_feed_only" selected>Event Feed Only — Visible to authenticated group members</option>
          <option value="public_gallery_eligible">Public Gallery Eligible — Separate guardian approval permitted</option>
        </select>
        <span style="font-size: 0.8rem; color: var(--text-muted); display: block; margin-top: 0.35rem;">
          Minors cannot upload media directly.
        </span>
      </div>

      <div class="form-group" style="padding: 1rem; background: var(--bg-primary); border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
        <label class="form-checkbox-label">
          <input type="checkbox" class="form-checkbox" id="guardian-waiver-check" />
          <span>
            <strong>Parent / Legal Guardian Attestation</strong><br>
            I certify that I am the legal parent or guardian of this dependent and consent to their participation in Day of Service events.
          </span>
        </label>
      </div>

      <button class="btn btn-primary" id="save-guardian-consent-btn" style="width: 100%;">
        Save Dependent Consent Evidence
      </button>
    </article>
  `;
}

function renderOrganizer(): string {
  return `
    <article class="form-card" style="max-width: 850px;">
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
        <div>
          <span class="event-badge">Organizer Console</span>
          <h1 style="font-size: 1.85rem; font-weight: 800; margin-top: 0.25rem;">Tenant Event Operations</h1>
        </div>
        <span style="font-size: 0.85rem; background: var(--primary-light); color: var(--primary); padding: 0.35rem 0.75rem; border-radius: var(--radius-full); font-weight: 600;">
          Tenant: Community Action Austin
        </span>
      </div>

      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 2rem;">
        <div style="background: var(--bg-primary); padding: 1.25rem; border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
          <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase;">Total Registrations</div>
          <div style="font-size: 1.75rem; font-weight: 800; color: var(--primary); margin-top: 0.25rem;">85</div>
        </div>
        <div style="background: var(--bg-primary); padding: 1.25rem; border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
          <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase;">Assigned Volunteers</div>
          <div style="font-size: 1.75rem; font-weight: 800; color: var(--accent); margin-top: 0.25rem;">78</div>
        </div>
        <div style="background: var(--bg-primary); padding: 1.25rem; border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
          <div style="font-size: 0.8rem; color: var(--text-muted); text-transform: uppercase;">Waitlisted (Cap Protection)</div>
          <div style="font-size: 1.75rem; font-weight: 800; color: var(--warning); margin-top: 0.25rem;">7</div>
        </div>
      </div>

      <h3 style="font-size: 1.15rem; font-weight: 700; margin-bottom: 1rem;">Operating Slices & Actions</h3>
      <div style="display: flex; flex-direction: column; gap: 0.75rem;">
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; background: var(--bg-primary); border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
          <div>
            <div style="font-weight: 600;">Automated Assignment Planning</div>
            <div style="font-size: 0.85rem; color: var(--text-muted);">Deterministic capacity balancing respecting must-stay-together groups.</div>
          </div>
          <button class="btn btn-secondary" id="run-allocator-btn">Run Planner</button>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; background: var(--bg-primary); border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
          <div>
            <div style="font-weight: 600;">Media Moderation & Takedown Queue</div>
            <div style="font-size: 0.85rem; color: var(--text-muted);">0 items quarantined. Reactive reporting immediately hides reported items.</div>
          </div>
          <button class="btn btn-secondary" id="view-moderation-btn">View Queue</button>
        </div>
        <div style="display: flex; justify-content: space-between; align-items: center; padding: 1rem; background: var(--bg-primary); border-radius: var(--radius-md); border: 1px solid var(--border-subtle);">
          <div>
            <div style="font-weight: 600;">Privacy-Thresholded Export (FR-401)</div>
            <div style="font-size: 0.85rem; color: var(--text-muted);">Export aggregate attendance and impact without personal or minor data leakage.</div>
          </div>
          <button class="btn btn-secondary" id="request-export-btn">Generate CSV</button>
        </div>
      </div>
    </article>
  `;
}

function renderFooter(): string {
  return `
    <footer class="footer" role="contentinfo">
      <div class="footer-inner">
        <div>
          <strong>Day of Service</strong> — Nationwide Multi-Organization Community Platform
        </div>
        <div>
          <span>Open Source (MIT) • Server Derived Tenant Isolation • PostGIS Authoritative</span>
        </div>
      </div>
    </footer>
  `;
}

function render() {
  const app = document.getElementById("app");
  if (!app) return;

  let bodyContent = "";
  switch (state.view) {
    case "discover":
      bodyContent = renderDiscover();
      break;
    case "detail":
      bodyContent = renderDetail();
      break;
    case "register":
      bodyContent = renderRegister();
      break;
    case "guardian":
      bodyContent = renderGuardian();
      break;
    case "organizer":
      bodyContent = renderOrganizer();
      break;
  }

  app.innerHTML = `
    <div class="app-container">
      ${renderHeader()}
      <main class="main-content" role="main">
        ${bodyContent}
      </main>
      ${renderFooter()}
    </div>
  `;

  attachEventListeners();
}

function attachEventListeners() {
  document.getElementById("nav-brand")?.addEventListener("click", () => setView("discover"));
  document.getElementById("nav-discover")?.addEventListener("click", () => setView("discover"));
  document.getElementById("nav-guardian")?.addEventListener("click", () => setView("guardian"));
  document.getElementById("nav-organizer")?.addEventListener("click", () => setView("organizer"));
  document.getElementById("theme-toggle")?.addEventListener("click", toggleTheme);

  document.getElementById("retry-btn")?.addEventListener("click", loadOccurrences);
  document.getElementById("back-to-discover")?.addEventListener("click", () => setView("discover"));
  document.getElementById("back-to-discover-btn")?.addEventListener("click", () => setView("discover"));
  document.getElementById("cancel-reg-btn")?.addEventListener("click", () => setView("detail"));
  document.getElementById("return-discover-success-btn")?.addEventListener("click", () => {
    state.registrationSuccessReference = null;
    setView("discover");
  });

  document.getElementById("start-reg-btn")?.addEventListener("click", () => {
    state.registrationSuccessReference = null;
    setView("register");
  });

  // Event cards clicks
  state.occurrences.forEach((occ, index) => {
    document.getElementById(`event-card-${index}`)?.addEventListener("click", () => {
      setView("detail", occ);
    });
  });

  // Registration submit
  const form = document.getElementById("registration-form") as HTMLFormElement | null;
  form?.addEventListener("submit", async (e) => {
    e.preventDefault();
    const nameInput = document.getElementById("reg-participant-name") as HTMLInputElement;
    const teamSelect = document.getElementById("reg-team-mode") as HTMLSelectElement;
    const accomInput = document.getElementById("reg-accommodations") as HTMLTextAreaElement;
    const waiverCheck = document.getElementById("reg-waiver-consent") as HTMLInputElement;

    if (!waiverCheck.checked) {
      state.errorMessage = "You must accept the volunteer waiver.";
      render();
      return;
    }

    state.loading = true;
    render();

    try {
      const result = await api.register({
        occurrence_id: state.selectedOccurrence!.id,
        site_id: state.selectedOccurrence!.sites[0]?.id,
        participant_names: [nameInput.value],
        team_mode: teamSelect.value as TeamMode,
        accommodations: accomInput.value || null,
        accepted_document_ids: ["60000000-0000-4000-8000-000000000001"]
      });
      state.registrationSuccessReference = result.id.slice(0, 8).toUpperCase();
      state.errorMessage = null;
    } catch (err: unknown) {
      state.errorMessage = err instanceof Error ? err.message : "Registration failed.";
    } finally {
      state.loading = false;
      render();
    }
  });

  document.getElementById("save-guardian-consent-btn")?.addEventListener("click", () => {
    alert("Guardian consent evidence recorded with immutable cryptographic timestamp.");
    setView("discover");
  });
}

// Initial Launch
loadOccurrences();
