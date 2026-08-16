import SwiftUI

struct ContentView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        TabView {
            NavigationStack { DiscoverView(model: model) }
                .tabItem { Label("Discover", systemImage: "sparkles") }
            NavigationStack { MyDayView(model: model) }
                .tabItem { Label("My Day", systemImage: "checkmark.circle") }
            NavigationStack { ProfileView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .tint(.teal)
        .task { await model.load() }
    }
}

private struct DiscoverView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Group {
            switch model.loadState {
            case .loading: ProgressView("Finding service opportunities…")
            case .empty: ContentUnavailableView("No upcoming events", systemImage: "calendar", description: Text("Check back soon for another way to serve."))
            case .failed(let message): ContentUnavailableView { Label("Unable to load events", systemImage: "wifi.exclamationmark") } description: { Text(message) } actions: { Button("Try Again") { Task { await model.load() } } }
            case .loaded:
                ScrollView {
                    LazyVStack(spacing: 18) {
                        welcome
                        ForEach(model.occurrences) { occurrence in
                            NavigationLink(value: occurrence) { EventCard(occurrence: occurrence) }.buttonStyle(.plain)
                        }
                    }.padding()
                }
            }
        }
        .navigationTitle("Day of Service")
        .navigationDestination(for: EventOccurrence.self) { EventDetailView(occurrence: $0, model: model) }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Make today matter.").font(.largeTitle.bold()).foregroundStyle(.white)
            Text("Find accessible, local ways to help your community.").foregroundStyle(.white.opacity(0.9))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
            .background(LinearGradient(colors: [.teal, .blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
    }
}

private struct EventCard: View {
    let occurrence: EventOccurrence
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { Label(occurrence.startsAt.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar"); Spacer(); Text("OPEN").font(.caption.bold()).foregroundStyle(.teal) }
            Text(occurrence.title).font(.title2.bold())
            Text(occurrence.summary).foregroundStyle(.secondary).lineLimit(3)
            Label(occurrence.sites.first?.publicLocation ?? "Location to come", systemImage: "mappin.and.ellipse").font(.subheadline)
            Label("View opportunity", systemImage: "arrow.right").font(.headline).foregroundStyle(.teal)
        }.padding(20).background(.background, in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(.quaternary)).shadow(color: .black.opacity(0.05), radius: 10, y: 4)
    }
}

private struct EventDetailView: View {
    let occurrence: EventOccurrence
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text(occurrence.title).font(.largeTitle.bold())
                Text(occurrence.summary).font(.title3).foregroundStyle(.secondary)
                detail("When", icon: "clock", text: occurrence.startsAt.formatted(date: .complete, time: .shortened))
                if let site = occurrence.sites.first {
                    detail("Where", icon: "mappin", text: site.publicLocation)
                    detail("Accessibility", icon: "accessibility", text: site.accessibility.joined(separator: " • "))
                    Text("For privacy and safety, the precise meeting point is shared after assignment.").font(.footnote).foregroundStyle(.secondary)
                }
                NavigationLink { RegistrationView(occurrence: occurrence, model: model) } label: { Text("Volunteer for this event").frame(maxWidth: .infinity).padding().fontWeight(.semibold) }.buttonStyle(.borderedProminent).tint(.teal)
            }.padding()
        }.navigationTitle("Opportunity").navigationBarTitleDisplayMode(.inline)
    }
    private func detail(_ title: String, icon: String, text: String) -> some View { HStack(alignment: .top) { Image(systemName: icon).foregroundStyle(.teal).frame(width: 26); VStack(alignment: .leading) { Text(title).font(.headline); Text(text).foregroundStyle(.secondary) } } }
}

private struct RegistrationView: View {
    let occurrence: EventOccurrence
    @ObservedObject var model: AppModel
    @State private var name = ""
    @State private var teamMode: TeamMode = .individual
    @State private var accommodation = ""
    @State private var accepted = false
    @State private var completed = false
    var body: some View {
        Form {
            if completed { Section { Label("Registration received", systemImage: "checkmark.seal.fill").font(.title2.bold()).foregroundStyle(.teal); Text("We’ll let you know when your assignment is confirmed.") } }
            else {
                Section("Participant") { TextField("Preferred name", text: $name).textContentType(.name); Picker("Registration type", selection: $teamMode) { Text("Just me").tag(TeamMode.individual); Text("Keep my team together if possible").tag(TeamMode.preferTogether); Text("My team must stay together").tag(TeamMode.mustStayTogether) } }
                Section("Site preference") { Text(occurrence.sites.first?.name ?? "No preference"); TextField("Accessibility or accommodation needs (optional)", text: $accommodation, axis: .vertical).lineLimit(3...6) }
                Section("Waiver") { Toggle("I have reviewed and accept the current volunteer waiver.", isOn: $accepted); Text("Consent is recorded as versioned evidence. A guardian must separately consent for each minor.").font(.footnote).foregroundStyle(.secondary) }
                if let error = model.submissionError { Section { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) } }
                Section { Button { Task { completed = await model.submit(request) } } label: { if model.isSubmitting { ProgressView().frame(maxWidth: .infinity) } else { Text("Submit registration").frame(maxWidth: .infinity) } }.disabled(model.isSubmitting) }
            }
        }.navigationTitle("Register").navigationBarTitleDisplayMode(.inline)
    }
    private var request: RegistrationRequest { RegistrationRequest(occurrenceID: occurrence.id, siteID: occurrence.sites.first?.id, participantNames: [name], teamMode: teamMode, accommodations: accommodation.isEmpty ? nil : accommodation, acceptedDocumentIDs: accepted ? [PreviewEventService.waiverID] : []) }
}

private struct MyDayView: View {
    @ObservedObject var model: AppModel
    var body: some View { Group { if let registration = model.registration { List { Section("Registration") { Label("Submitted", systemImage: "checkmark.circle.fill").foregroundStyle(.teal); LabeledContent("Reference", value: String(registration.id.uuidString.prefix(8)).uppercased()) }; Section("What happens next") { Text("Your organization will confirm your assignment and meeting details here.") } } } else { ContentUnavailableView("Nothing scheduled yet", systemImage: "hands.sparkles", description: Text("Choose an opportunity in Discover to plan your day of service.")) } }.navigationTitle("My Day") }
}

private struct ProfileView: View {
    var body: some View { List { Section("Your account") { Label("Sign in to save registrations", systemImage: "person.badge.key"); Label("Accessibility preferences", systemImage: "accessibility") }; Section("Privacy & support") { Label("Privacy choices", systemImage: "hand.raised"); Label("Get help", systemImage: "questionmark.circle"); Label("Request account deletion", systemImage: "trash") } }.navigationTitle("Profile") }
}

#Preview { ContentView() }
