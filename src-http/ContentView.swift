import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: KeyManagerViewModel
    @State private var showingAddSheet = false
    @State private var editingItem: ApiKeyItem?
    @State private var confirmingDelete: ApiKeyItem?
    @State private var confirmingDeleteMultiple: Bool = false
    @State private var selectedItems: Set<UUID> = []

    init() {
        // Create a shared view model
        _viewModel = ObservedObject(wrappedValue: KeyManagerViewModel.shared)
    }

    var hasSelection: Bool {
        !selectedItems.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.accentColor)
                Text("OpenLocalKeys")
                    .font(.headline)

                Spacer()

                HStack(spacing: 8) {
                    if hasSelection {
                        Button("Delete Selected (\(selectedItems.count))") {
                            confirmingDeleteMultiple = true
                        }
                        .buttonStyle(.borderedProminent)
                        .foregroundColor(.red)
                    }

                    if !hasSelection && !viewModel.items.isEmpty {
                        Button("Select All") {
                            selectedItems = Set(viewModel.items.map { $0.id })
                        }
                        .buttonStyle(.bordered)
                    }

                    Button(action: {
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .help("Add new API key")
                }
            }
            .padding()
            .padding(.bottom, 8)

            Divider()

            // List of items
            if viewModel.items.isEmpty {
                emptyStateView
            } else {
                listView
            }

            Divider()

            // Footer
            HStack {
                if hasSelection {
                    Button("Deselect All") {
                        selectedItems.removeAll()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                } else if !viewModel.items.isEmpty {
                    Button("Select All") {
                        selectedItems = Set(viewModel.items.map { $0.id })
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }

                Spacer()

                Text("\(viewModel.items.count) key\(viewModel.items.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .frame(width: 900, height: 1000)
        .sheet(isPresented: $showingAddSheet) {
            ItemEditView { displayName, provider, privateKey in
                viewModel.addItem(ApiKeyItem(
                    displayName: displayName,
                    provider: provider,
                    privateKey: privateKey
                ))
            }
        }
        .sheet(item: $editingItem) { item in
            ItemEditView(existingItem: item) { displayName, provider, privateKey in
                var updated = item
                updated.displayName = displayName
                updated.provider = provider
                updated.privateKey = privateKey
                viewModel.updateItem(updated)
            }
        }
        .alert("Delete Key?", isPresented: .constant(confirmingDelete != nil), presenting: confirmingDelete) { item in
            Button("Cancel", role: .cancel) {
                confirmingDelete = nil
            }
            Button("Delete", role: .destructive) {
                viewModel.deleteItem(item)
                confirmingDelete = nil
                selectedItems.remove(item.id)
            }
        } message: { item in
            Text("Are you sure you want to delete \"\(item.displayName)\"? This action cannot be undone.")
        }
        .alert("Delete Selected Keys?", isPresented: $confirmingDeleteMultiple) {
            Button("Cancel", role: .cancel) {
                confirmingDeleteMultiple = false
            }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
                confirmingDeleteMultiple = false
            }
        } message: {
            Text("Are you sure you want to delete \(selectedItems.count) key(s)? This action cannot be undone.")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverWillClose"))) { _ in
            // Dismiss all sheets when popover closes
            showingAddSheet = false
            editingItem = nil
            confirmingDelete = nil
            confirmingDeleteMultiple = false
        }
    }

    private func deleteSelectedItems() {
        for itemId in selectedItems {
            if let item = viewModel.items.first(where: { $0.id == itemId }) {
                viewModel.deleteItem(item)
            }
        }
        selectedItems.removeAll()
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "key.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No API Keys")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Click the + button to add your first API key.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var listView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                    ItemRow(
                        item: item,
                        isSelected: selectedItems.contains(item.id),
                        onToggleSelect: {
                            if selectedItems.contains(item.id) {
                                selectedItems.remove(item.id)
                            } else {
                                selectedItems.insert(item.id)
                            }
                        },
                        onEdit: { editingItem = item },
                        onDelete: { confirmingDelete = item },
                        onToggleVisibility: {
                            var updated = item
                            updated.isVisible = !item.isVisible
                            viewModel.updateItem(updated)
                        },
                        onMoveUp: index > 0 ? {
                            viewModel.moveItem(from: index, to: index - 1)
                        } : nil,
                        onMoveDown: index < viewModel.items.count - 1 ? {
                            viewModel.moveItem(from: index, to: index + 1)
                        } : nil
                    )

                    if index < viewModel.items.count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
        }
    }
}

struct ItemRow: View {
    let item: ApiKeyItem
    let isSelected: Bool
    let onToggleSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleVisibility: () -> Void
    let onMoveUp: (() -> Void)?
    let onMoveDown: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)
            .help(isSelected ? "Deselect" : "Select")

            // Provider icon
            Image(systemName: providerIcon)
                .font(.system(size: 20))
                .foregroundColor(.accentColor)
                .frame(width: 32)

            // Main content
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 4) {
                    Text(item.provider.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if case .custom = item.provider {
                        Image(systemName: "person.badge.key")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            // Key display with toggle
            HStack(spacing: 4) {
                if item.isVisible {
                    Text(item.privateKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                } else {
                    Text(item.maskedKey)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Button(action: onToggleVisibility) {
                    Image(systemName: item.isVisible ? "eye.slash.fill" : "eye.fill")
                }
                .buttonStyle(.borderless)
                .help(item.isVisible ? "Hide key" : "Show key")
            }

            // Reorder buttons
            VStack(spacing: 2) {
                Button(action: onMoveUp ?? {}) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(onMoveUp == nil)

                Button(action: onMoveDown ?? {}) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(onMoveDown == nil)
            }

            // Edit button
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            .help("Edit")

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .contextMenu {
            Button(isSelected ? "Deselect" : "Select", systemImage: isSelected ? "square" : "checkmark.square") {
                onToggleSelect()
            }
            Button("Edit", systemImage: "pencil") {
                onEdit()
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                onDelete()
            }
        }
    }

    private var providerIcon: String {
        return item.provider.icon
    }
}

#Preview {
    ContentView()
}
