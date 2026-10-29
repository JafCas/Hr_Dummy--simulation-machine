import SwiftUI

struct CoordinateEntrySheet: View {
    let viewModel: SimulatorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var error: String?
    @State private var isWorking = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("19.432608, -99.133209 or Google Maps link", text: $text)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("coordinateInput")
                    if UIPasteboard.general.hasStrings {
                        Button("Paste from clipboard") { text = UIPasteboard.general.string ?? "" }
                    }
                } header: {
                    Text("Coordinates or Google Maps link")
                } footer: {
                    Text("Accepted: “lat, lon”, google.com/maps URLs (place, @lat,lon, ?q=, ?query=) and maps.app.goo.gl short links.")
                }
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("coordinateError")
                }
            }
            .navigationTitle("Enter location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isWorking {
                        ProgressView()
                    } else {
                        Button("Use") { apply() }
                            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityIdentifier("applyCoordinateButton")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func apply() {
        isWorking = true
        Task {
            let message = await viewModel.applyManualInput(text)
            isWorking = false
            if let message { error = message } else { dismiss() }
        }
    }
}
