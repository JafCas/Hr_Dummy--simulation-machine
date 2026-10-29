import LocationSimCore
import SwiftUI

struct LocationPanel: View {
    @Bindable var viewModel: SimulatorViewModel
    @Binding var showHowTo: Bool

    var body: some View {
        if let selected = viewModel.selected {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selected.name)
                            .font(.headline)
                            .accessibilityIdentifier("selectedName")
                        if let subtitle = selected.subtitle, !subtitle.isEmpty {
                            Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                    Spacer()
                    Button { viewModel.clearSelection() } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Clear selection")
                    .accessibilityIdentifier("clearSelectionButton")
                }

                HStack {
                    Text(selected.coordinate.formatted)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityIdentifier("selectedCoordinate")
                    Spacer()
                    Text(selected.source.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                Toggle("GPS jitter (realistic noise)", isOn: $viewModel.jitterEnabled)
                    .font(.subheadline)
                    .accessibilityIdentifier("jitterToggle")

                if viewModel.jitterEnabled {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Radius: \(Int(viewModel.accuracyRadius.rounded())) m")
                            .font(.caption)
                            .accessibilityIdentifier("accuracyLabel")
                        Slider(value: $viewModel.accuracyRadius, in: 1...GeoMath.maxAccuracyRadius, step: 1)
                            .accessibilityIdentifier("accuracySlider")
                        Stepper("Points: \(viewModel.jitterSampleCount) (every 5 s)", value: $viewModel.jitterSampleCount, in: 2...120)
                            .font(.caption)
                    }
                } else {
                    Text("Exact point (0 m offset).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("accuracyLabel")
                }

                HStack {
                    Button {
                        viewModel.exportGPX()
                    } label: {
                        Label("Export GPX", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("exportButton")

                    Menu {
                        Button("Coordinates") { viewModel.copy(selected.coordinate.formatted, label: "Coordinates") }
                        Button("GPX contents") { viewModel.copy(viewModel.gpxDocument() ?? "", label: "GPX") }
                        Button("Simulator command") { viewModel.copy(SimulationCommands.simulator(selected.coordinate), label: "Command") }
                        Button("Device command (iOS 17+)") { viewModel.copy(SimulationCommands.physicalDevice(selected.coordinate), label: "Command") }
                        Divider()
                        Button("How to apply…") { showHowTo = true }
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("copyMenu")
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 4, y: 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("selectedLocationPanel")
        }
    }
}

extension SimulatedLocation.Source {
    var label: String {
        switch self {
        case .appleMaps: return "Apple Maps"
        case .googlePlaces: return "Google Places"
        case .mapPin: return "Map pin"
        case .coordinates: return "Coordinates"
        case .googleMapsLink: return "Google Maps link"
        }
    }
}
