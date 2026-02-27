import Foundation

/// Represents an API key that can be sent to HTTP clients
public struct HTTPApiKey: Codable, Sendable {
    public let displayName: String
    public let privateKey: String
    public let provider: String
    public let customProviderName: String?
    public let customProviderURL: String?

    public init(
        displayName: String,
        privateKey: String,
        provider: String,
        customProviderName: String? = nil,
        customProviderURL: String? = nil
    ) {
        self.displayName = displayName
        self.privateKey = privateKey
        self.provider = provider
        self.customProviderName = customProviderName
        self.customProviderURL = customProviderURL
    }
}
