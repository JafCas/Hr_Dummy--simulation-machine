import LocationSimCore
import SwiftUI

struct HowToApplySheet: View {
    let coordinate: Coordinate?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Physical iPhone / iPad (whole device)") {
                    step(1, "Tap Export GPX and AirDrop/save the file to your Mac.")
                    step(2, "Replace GPX/CurrentLocation.gpx in this project with it (or add it to any Xcode project).")
                    step(3, "Connect the device, enable Developer Mode, and Run this app from Xcode.")
                    step(4, "Xcode applies CurrentLocation.gpx automatically. To switch: Debug ▸ Simulate Location ▸ pick a GPX.")
                    step(5, "Every app on the device (Maps, etc.) sees the location while the Xcode debug session is active. Stop simulating via Debug ▸ Simulate Location ▸ Don't Simulate Location.")
                }
                Section("iOS Simulator") {
                    step(1, "Copy ▸ Simulator command, then run it on the Mac:")
                    command(coordinate.map(SimulationCommands.simulator) ?? "xcrun simctl location booted set <lat>,<lon>")
                }
                Section("Physical device without Xcode running (iOS 17+)") {
                    step(1, "pip install pymobiledevice3, then keep a tunnel open: sudo pymobiledevice3 remote tunneld")
                    step(2, "Copy ▸ Device command and run it:")
                    command(coordinate.map(SimulationCommands.physicalDevice) ?? "pymobiledevice3 developer dvt simulate-location set -- <lat> <lon>")
                }
                Section("Accuracy") {
                    Text("Coordinates are written with 6 decimals (≈0.1 m). Without jitter the device reports the exact point. With jitter every point stays within the chosen radius (max 20 m).")
                        .font(.callout)
                }
            }
            .navigationTitle("How to apply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        Label { Text(text).font(.callout) } icon: { Text("\(n)").font(.callout.bold()) }
    }

    private func command(_ text: String) -> some View {
        Text(text)
            .font(.caption.monospaced())
            .textSelection(.enabled)
    }
}
