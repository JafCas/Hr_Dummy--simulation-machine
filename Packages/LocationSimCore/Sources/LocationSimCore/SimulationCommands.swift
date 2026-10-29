import Foundation

/// Shell commands that apply a coordinate outside the app (run on the Mac).
public enum SimulationCommands {
    /// Booted iOS Simulator.
    public static func simulator(_ c: Coordinate) -> String {
        "xcrun simctl location booted set \(Coordinate.format(c.latitude)),\(Coordinate.format(c.longitude))"
    }

    /// Physical device on iOS 17+ via pymobiledevice3 (requires `sudo pymobiledevice3 remote tunneld` running).
    public static func physicalDevice(_ c: Coordinate) -> String {
        "pymobiledevice3 developer dvt simulate-location set -- \(Coordinate.format(c.latitude)) \(Coordinate.format(c.longitude))"
    }

    /// Repo helper script that wraps both paths.
    public static func helperScript(_ c: Coordinate, target: String = "simulator") -> String {
        "./scripts/simulate-location.sh \(target) \(Coordinate.format(c.latitude)) \(Coordinate.format(c.longitude))"
    }
}
