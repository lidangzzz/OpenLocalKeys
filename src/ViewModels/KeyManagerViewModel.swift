import Foundation
import SwiftUI

class KeyManagerViewModel: ObservableObject {
    @Published var items: [ApiKeyItem] = []
    private let userDefaultsKey = "ApiKeyItems"

    static let shared = KeyManagerViewModel()

    init() {
        loadItems()
    }

    // MARK: - CRUD Operations

    func addItem(_ item: ApiKeyItem) {
        items.append(item)
        saveItems()
    }

    func updateItem(_ item: ApiKeyItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
            saveItems()
        }
    }

    func deleteItem(_ item: ApiKeyItem) {
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func deleteItem(at indexSet: IndexSet) {
        items.remove(atOffsets: indexSet)
        saveItems()
    }

    // MARK: - Reordering

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        saveItems()
    }

    func moveItem(from source: Int, to destination: Int) {
        guard source != destination,
              source >= 0, source < items.count,
              destination >= 0, destination <= items.count else {
            return
        }

        let item = items.remove(at: source)
        items.insert(item, at: destination)
        saveItems()
    }

    // MARK: - Persistence

    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    private func loadItems() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ApiKeyItem].self, from: data) {
            items = decoded
        }
    }
}
