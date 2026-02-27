import Foundation

struct ApiKeyItem: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var provider: Provider
    var privateKey: String
    var isVisible: Bool  // For showing/hiding the key in UI

    init(displayName: String, provider: Provider, privateKey: String) {
        self.id = UUID()
        self.displayName = displayName
        self.provider = provider
        self.privateKey = privateKey
        self.isVisible = false
    }

    // Mask the private key for display
    var maskedKey: String {
        if privateKey.isEmpty { return "" }
        if privateKey.count <= 8 {
            return String(repeating: "•", count: privateKey.count)
        }
        return String(privateKey.prefix(4)) + String(repeating: "•", count: privateKey.count - 8) + String(privateKey.suffix(4))
    }

    // For backward compatibility during migration
    private enum CodingKeys: String, CodingKey {
        case id, displayName, providerName, privateKey, isVisible
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        privateKey = try container.decode(String.self, forKey: .privateKey)
        isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? false

        // Try to decode as new Provider enum first
        if let provider = try? container.decode(Provider.self, forKey: .providerName) {
            self.provider = provider
        } else if let providerName = try? container.decode(String.self, forKey: .providerName) {
            // Migrate old providerName string to new Provider enum
            let normalized = providerName.lowercased()
            switch normalized {
            case "anthropic": self.provider = .anthropic
            case "openai": self.provider = .openai
            case "mistral": self.provider = .mistral
            case "openrouter": self.provider = .openrouter
            case "kimi": self.provider = .kimi
            case "gemini": self.provider = .gemini
            case "zai": self.provider = .zai
            case "minimax": self.provider = .minimax
            default: self.provider = .custom(name: providerName, baseURL: "")
            }
        } else {
            // Fallback
            self.provider = .openai
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(provider, forKey: .providerName)
        try container.encode(privateKey, forKey: .privateKey)
        try container.encode(isVisible, forKey: .isVisible)
    }
}
