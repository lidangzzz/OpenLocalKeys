import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                Text("OpenLocalKeys")
                    .font(.headline)
                Spacer()
            }

            Divider()

            // Main content area
            VStack(alignment: .leading, spacing: 12) {
                Text("Welcome!")
                    .font(.title2)
                    .bold()

                Text("This is your menu bar app.")
                    .foregroundColor(.secondary)

                // Example buttons
                VStack(spacing: 8) {
                    Button(action: {
                        print("Action 1 clicked")
                    }) {
                        Label("First Action", systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        print("Action 2 clicked")
                    }) {
                        Label("Second Action", systemImage: "gear")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                // Settings or info
                HStack {
                    Text("Version 1.0.0")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding()
        }
        .padding()
        .frame(width: 300, height: 400)
    }
}

#Preview {
    ContentView()
}
