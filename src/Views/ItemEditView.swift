import SwiftUI

struct ItemEditView: View {
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String
    @State private var providerName: String
    @State private var privateKey: String

    let onSave: (String, String, String) -> Void

    init(existingItem: ApiKeyItem? = nil, onSave: @escaping (String, String, String) -> Void) {
        self.onSave = onSave

        if let item = existingItem {
            _displayName = State(initialValue: item.displayName)
            _providerName = State(initialValue: item.providerName)
            _privateKey = State(initialValue: item.privateKey)
        } else {
            _displayName = State(initialValue: "")
            _providerName = State(initialValue: "")
            _privateKey = State(initialValue: "")
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("API Key Details")
                .font(.headline)
                .padding(.bottom, 8)

            Form {
                Section("Display Name") {
                    TextField("e.g., My OpenAI Key", text: $displayName)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Provider") {
                    TextField("e.g., OpenAI, Anthropic", text: $providerName)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Private Key") {
                    SecureField("sk-...", text: $privateKey)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .formStyle(.grouped)

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    onSave(displayName, providerName, privateKey)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(displayName.isEmpty || providerName.isEmpty || privateKey.isEmpty)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 700, height: 600)
    }
}

#Preview {
    ItemEditView { displayName, providerName, privateKey in
        print("Save: \(displayName), \(providerName), \(privateKey)")
    }
}
