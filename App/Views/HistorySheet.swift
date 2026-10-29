import SwiftUI

struct HistorySheet: View {
    let viewModel: SimulatorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if viewModel.history.isEmpty {
                    ContentUnavailableView("No locations yet", systemImage: "mappin.slash", description: Text("Search, drop a pin or enter coordinates."))
                }
                ForEach(viewModel.history) { location in
                    Button {
                        viewModel.setSelection(location, recenter: true)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name).foregroundStyle(.primary)
                            Text("\(location.coordinate.formatted) · \(location.source.label)")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityIdentifier("historyRow")
                }
                .onDelete { viewModel.deleteHistory(at: $0) }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear", role: .destructive) { viewModel.clearHistory() }
                        .disabled(viewModel.history.isEmpty)
                }
            }
        }
    }
}
