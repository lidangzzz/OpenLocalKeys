import Foundation

struct ApiKeyItem: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var providerName: String
    var privateKey: String
    var isVisible: Bool  // For showing/hiding the key in UI

    init(displayName: String, providerName: String, privateKey: String) {
        self.id = UUID()
        self.displayName = displayName
        self.providerName = providerName
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
}
