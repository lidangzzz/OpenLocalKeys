import Foundation

enum Provider: Codable, Equatable, Hashable, Identifiable {
    case anthropic
    case openai
    case mistral
    case openrouter
    case kimi
    case gemini
    case zai
    case minimax
    case custom(name: String, baseURL: String)

    var id: String {
        switch self {
        case .custom(let name, _):
            return "custom-\(name)"
        case .anthropic: return "anthropic"
        case .openai: return "openai"
        case .mistral: return "mistral"
        case .openrouter: return "openrouter"
        case .kimi: return "kimi"
        case .gemini: return "gemini"
        case .zai: return "zai"
        case .minimax: return "minimax"
        }
    }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .mistral: return "Mistral"
        case .openrouter: return "OpenRouter"
        case .kimi: return "Kimi"
        case .gemini: return "Gemini"
        case .zai: return "Zai"
        case .minimax: return "MiniMax"
        case .custom(let name, _): return name
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .anthropic: return "https://api.anthropic.com"
        case .openai: return "https://api.openai.com/v1"
        case .mistral: return "https://api.mistral.ai/v1"
        case .openrouter: return "https://openrouter.ai/api/v1"
        case .kimi: return "https://api.moonshot.cn/v1"
        case .gemini: return "https://generativelanguage.googleapis.com"
        case .zai: return "https://api.zai.ai/v1"
        case .minimax: return "https://api.minimax.chat/v1"
        case .custom(_, let baseURL): return baseURL
        }
    }

    // Standard cases for picker (excluding custom)
    static var standardCases: [Provider] {
        return [
            .anthropic,
            .openai,
            .mistral,
            .openrouter,
            .kimi,
            .gemini,
            .zai,
            .minimax
        ]
    }

    // Custom CodingKeys to handle the custom case with associated values
    private enum CodingKeys: String, CodingKey {
        case type, customName, customBaseURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "anthropic": self = .anthropic
        case "openai": self = .openai
        case "mistral": self = .mistral
        case "openrouter": self = .openrouter
        case "kimi": self = .kimi
        case "gemini": self = .gemini
        case "zai": self = .zai
        case "minimax": self = .minimax
        case "custom":
            let customName = try container.decode(String.self, forKey: .customName)
            let customBaseURL = try container.decode(String.self, forKey: .customBaseURL)
            self = .custom(name: customName, baseURL: customBaseURL)
        default:
            self = .openai // fallback
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .anthropic:
            try container.encode("anthropic", forKey: .type)
        case .openai:
            try container.encode("openai", forKey: .type)
        case .mistral:
            try container.encode("mistral", forKey: .type)
        case .openrouter:
            try container.encode("openrouter", forKey: .type)
        case .kimi:
            try container.encode("kimi", forKey: .type)
        case .gemini:
            try container.encode("gemini", forKey: .type)
        case .zai:
            try container.encode("zai", forKey: .type)
        case .minimax:
            try container.encode("minimax", forKey: .type)
        case .custom(let name, let baseURL):
            try container.encode("custom", forKey: .type)
            try container.encode(name, forKey: .customName)
            try container.encode(baseURL, forKey: .customBaseURL)
        }
    }
}

extension Provider {
    var icon: String {
        switch self {
        case .anthropic: return "brain"
        case .openai: return "brain.head.profile"
        case .mistral: return "wind"
        case .openrouter: return "arrow.triangle.2.circlepath"
        case .kimi: return "moon.stars.fill"
        case .gemini: return "sparkles"
        case .zai: return "z.circle"
        case .minimax: return "m.circle"
        case .custom: return "key.fill"
        }
    }
}
