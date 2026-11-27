import SwiftUI

@main
struct HostFirstDemoApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

private struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Host-first remote shell")
                    .font(.title2.weight(.semibold))
                Text("SwiftUI launch and simulator workflow are validated here. Pairing needs the unimplemented daemon identity flow and a reachable test device.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Pi TV Remote")
        }
    }
}
