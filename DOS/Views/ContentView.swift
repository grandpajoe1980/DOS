import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48))

                Text("Day of Service")
                    .font(.title)
                    .fontWeight(.semibold)

                Text("Initial application shell")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("DOS")
        }
    }
}

#Preview {
    ContentView()
}
