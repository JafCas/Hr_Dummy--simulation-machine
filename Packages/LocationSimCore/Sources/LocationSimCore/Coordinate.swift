import Foundation

/// Platform-independent WGS84 coordinate (no CoreLocation dependency so it can be tested on any platform).
public struct Coordinate: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90.0...90.0).contains(latitude)
            && (-180.0...180.0).contains(longitude)
    }

    /// "19.432608, -99.133209" (6 decimals ≈ 0.11 m).
    public var formatted: String {
        "\(Self.format(latitude)), \(Self.format(longitude))"
    }

    public static func format(_ value: Double) -> String {
        String(format: "%.6f", value)
    }
}
