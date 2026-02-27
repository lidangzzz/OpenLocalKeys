import SwiftUI

struct ItemEditView: View {
    @Environment(\.dismiss) var dismiss
    @State private var displayName: String
    @State private var selectedProvider: Provider
    @State private var privateKey: String
    @State private var isCustomProvider: Bool
    @State private var customProviderName: String
    @State private var customProviderURL: String
    @State private var jsonInput: String = ""
    @State private var showingJsonError: Bool = false
    @State private var jsonErrorMessage: String = ""

    let onSave: (String, Provider, String) -> Void

    init(existingItem: ApiKeyItem? = nil, onSave: @escaping (String, Provider, String) -> Void) {
        self.onSave = onSave

        if let item = existingItem {
            _displayName = State(initialValue: item.displayName)
            _privateKey = State(initialValue: item.privateKey)

            switch item.provider {
            case .custom(let name, let url):
                _isCustomProvider = State(initialValue: true)
                _customProviderName = State(initialValue: name)
                _customProviderURL = State(initialValue: url)
                _selectedProvider = State(initialValue: .custom(name: name, baseURL: url))
            default:
                _isCustomProvider = State(initialValue: false)
                _customProviderName = State(initialValue: "")
                _customProviderURL = State(initialValue: "")
                _selectedProvider = State(initialValue: item.provider)
            }
        } else {
            _displayName = State(initialValue: "")
            _privateKey = State(initialValue: "")
            _isCustomProvider = State(initialValue: false)
            _customProviderName = State(initialValue: "")
            _customProviderURL = State(initialValue: "")
            _selectedProvider = State(initialValue: .openai)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("API Key Details")
                .font(.headline)
                .padding(.bottom, 8)

            ScrollView {
                Form {
                    Section("Display Name") {
                        TextField("e.g., My OpenAI Key", text: $displayName)
                            .textFieldStyle(.roundedBorder)
                    }

                    Section("Provider") {
                        Picker("Provider", selection: $isCustomProvider) {
                            Text("Predefined Provider").tag(false)
                            Text("Custom Provider").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)

                        if isCustomProvider {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Provider Name", text: $customProviderName, prompt: Text("e.g., My Custom Provider"))
                                    .textFieldStyle(.roundedBorder)

                                TextField("Base URL", text: $customProviderURL, prompt: Text("https://api.example.com/v1"))
                                    .textFieldStyle(.roundedBorder)
                            }
                        } else {
                            Picker("Select Provider", selection: $selectedProvider) {
                                ForEach(Provider.standardCases) { provider in
                                    HStack {
                                        Image(systemName: provider.icon)
                                            .foregroundColor(.accentColor)
                                        Text(provider.displayName)
                                        Spacer()
                                        Text(provider.defaultBaseURL)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .tag(provider)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    Section("Private Key") {
                        SecureField("sk-...", text: $privateKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    Section("Import from JSON") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $jsonInput)
                                .frame(minHeight: 80, maxHeight: 120)
                                .font(.system(.body, design: .monospaced))
                                .border(Color.secondary.opacity(0.3))

                            if !jsonInput.isEmpty {
                                HStack {
                                    Spacer()
                                    Button("Clear") {
                                        jsonInput = ""
                                    }
                                    .buttonStyle(.borderless)
                                    .font(.caption)
                                }
                            }

                            // Example JSON format
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Example JSON Format")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                Text("""
{
  "displayName": "My OpenAI Key",
  "provider": "openai",
  "privateKey": "sk-..."
}

Or for custom providers:
{
  "displayName": "My Custom Key",
  "provider": "custom",
  "customName": "My Provider",
  "customBaseURL": "https://api.example.com/v1",
  "privateKey": "sk-..."
}
""")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .formStyle(.grouped)
            }

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    saveItem()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(width: 700, height: 1050)
        .alert("JSON Error", isPresented: $showingJsonError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(jsonErrorMessage)
        }
    }

    private func saveItem() {
        // If JSON input is provided, parse and use it
        if !jsonInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let data = jsonInput.data(using: .utf8) else {
                showingJsonError = true
                jsonErrorMessage = "Invalid UTF-8 encoding"
                return
            }

            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    showingJsonError = true
                    jsonErrorMessage = "JSON must be an object"
                    return
                }

                // Parse displayName (optional, use current value if not provided)
                let finalDisplayName = (json["displayName"] as? String)?.isEmpty == false ? (json["displayName"] as! String) : displayName

                // Parse privateKey (optional, use current value if not provided)
                let finalPrivateKey = (json["privateKey"] as? String)?.isEmpty == false ? (json["privateKey"] as! String) : privateKey

                // Parse provider (optional, use current value if not provided)
                var finalProvider: Provider
                if let providerString = json["provider"] as? String {
                    if providerString.lowercased() == "custom" {
                        // Custom provider
                        let customName = (json["customName"] as? String)?.isEmpty == false ? (json["customName"] as! String) : customProviderName
                        let customURL = (json["customBaseURL"] as? String)?.isEmpty == false ? (json["customBaseURL"] as! String) : customProviderURL
                        if customName.isEmpty {
                            showingJsonError = true
                            jsonErrorMessage = "Custom provider name is required"
                            return
                        }
                        if customURL.isEmpty {
                            showingJsonError = true
                            jsonErrorMessage = "Custom provider URL is required"
                            return
                        }
                        finalProvider = .custom(name: customName, baseURL: customURL)
                    } else {
                        // Standard provider
                        let normalizedProvider = providerString.lowercased()
                        switch normalizedProvider {
                        case "anthropic":
                            finalProvider = .anthropic
                        case "openai":
                            finalProvider = .openai
                        case "mistral":
                            finalProvider = .mistral
                        case "openrouter":
                            finalProvider = .openrouter
                        case "kimi":
                            finalProvider = .kimi
                        case "gemini":
                            finalProvider = .gemini
                        case "zai":
                            finalProvider = .zai
                        case "minimax":
                            finalProvider = .minimax
                        default:
                            showingJsonError = true
                            jsonErrorMessage = "Unknown provider: \(providerString)"
                            return
                        }
                    }
                } else {
                    // Use current form values
                    if isCustomProvider {
                        if customProviderName.isEmpty || customProviderURL.isEmpty {
                            showingJsonError = true
                            jsonErrorMessage = "Custom provider name and URL are required"
                            return
                        }
                        finalProvider = .custom(name: customProviderName, baseURL: customProviderURL)
                    } else {
                        finalProvider = selectedProvider
                    }
                }

                // Validate required fields
                if finalDisplayName.isEmpty {
                    showingJsonError = true
                    jsonErrorMessage = "Display name is required"
                    return
                }
                if finalPrivateKey.isEmpty {
                    showingJsonError = true
                    jsonErrorMessage = "Private key is required"
                    return
                }

                // Save the parsed data
                onSave(finalDisplayName, finalProvider, finalPrivateKey)
                dismiss()

            } catch {
                showingJsonError = true
                jsonErrorMessage = "Invalid JSON: \(error.localizedDescription)"
            }
        } else {
            // No JSON input, use form fields
            if displayName.isEmpty || privateKey.isEmpty || (isCustomProvider && (customProviderName.isEmpty || customProviderURL.isEmpty)) {
                showingJsonError = true
                jsonErrorMessage = "Please fill in all required fields"
                return
            }

            let finalProvider: Provider
            if isCustomProvider {
                finalProvider = .custom(name: customProviderName.isEmpty ? "Custom" : customProviderName,
                                        baseURL: customProviderURL.isEmpty ? "https://api.example.com" : customProviderURL)
            } else {
                finalProvider = selectedProvider
            }
            onSave(displayName, finalProvider, privateKey)
            dismiss()
        }
    }
}

#Preview {
    ItemEditView { displayName, provider, privateKey in
        print("Save: \(displayName), \(provider), \(privateKey)")
    }
}
