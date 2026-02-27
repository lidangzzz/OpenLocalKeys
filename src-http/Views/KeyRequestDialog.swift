import SwiftUI
import SocketServer

struct KeyRequestDialog: View {
    @ObservedObject var viewModel: KeyManagerViewModel
    let request: SocketRequest
    @State private var selectedItems: Set<UUID> = []
    @State private var isProcessing = false
    let onRespond: (Bool, [ApiKeyItem]) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "hand.wave.fill")
                    .font(.title)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Access Request")
                        .font(.headline)
                    Text("\(request.clientName) wants to access your API keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()

            Divider()

            // Key selection list
            if viewModel.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("No API Keys Available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                            KeyRequestItemRow(
                                item: item,
                                isSelected: selectedItems.contains(item.id),
                                onToggleSelect: {
                                    if selectedItems.contains(item.id) {
                                        selectedItems.remove(item.id)
                                    } else {
                                        selectedItems.insert(item.id)
                                    }
                                }
                            )

                            if index < viewModel.items.count - 1 {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                }
            }

            Divider()

            // Footer with actions
            HStack(spacing: 12) {
                Button("Deny") {
                    onRespond(false, [])
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)

                if !viewModel.items.isEmpty {
                    Button("Select All") {
                        selectedItems = Set(viewModel.items.map { $0.id })
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Approve (\(selectedItems.count))") {
                        let approvedItems = viewModel.items.filter { selectedItems.contains($0.id) }
                        onRespond(true, approvedItems)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedItems.isEmpty || isProcessing)
                } else {
                    Spacer()
                }
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .onAppear {
            // Auto-select first item if available
            if let firstItem = viewModel.items.first {
                selectedItems.insert(firstItem.id)
            }
        }
    }
}

struct KeyRequestItemRow: View {
    let item: ApiKeyItem
    let isSelected: Bool
    let onToggleSelect: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox
            Button(action: onToggleSelect) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
            }
            .buttonStyle(.borderless)

            // Provider icon
            Image(systemName: item.provider.icon)
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

            // Key preview (masked)
            Text(item.maskedKey)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelect()
        }
    }
}

#Preview {
    KeyRequestDialog(
        viewModel: KeyManagerViewModel(),
        request: "http://localhost:3000"
    ) { approved, items in
        print("Approved: \(approved), Items: \(items)")
    }
}
