import Foundation

public enum GeoMath {
    /// Mean Earth radius (IUGG) in meters.
    public static let earthRadius: Double = 6_371_008.8

    /// Upper bound for the simulated location's accuracy radius, in meters.
    public static let maxAccuracyRadius: Double = 20

    /// Great-circle distance in meters (haversine).
    public static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let lat1 = a.latitude.radians, lat2 = b.latitude.radians
        let dLat = (b.latitude - a.latitude).radians
        let dLon = (b.longitude - a.longitude).radians
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Point reached travelling `distance` meters from `origin` on initial `bearing` (degrees from north).
    public static func destination(from origin: Coordinate, bearing: Double, distance: Double) -> Coordinate {
        let delta = distance / earthRadius
        let theta = bearing.radians
        let lat1 = origin.latitude.radians, lon1 = origin.longitude.radians
        let lat2 = asin(sin(lat1) * cos(delta) + cos(lat1) * sin(delta) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(delta) * cos(lat1), cos(delta) - sin(lat1) * sin(lat2))
        var lon = lon2.degrees
        lon = (lon + 540).truncatingRemainder(dividingBy: 360) - 180
        return Coordinate(latitude: lat2.degrees, longitude: lon)
    }

    /// Uniformly distributed random point inside a disk of `radius` meters around `center`.
    public static func randomPoint<G: RandomNumberGenerator>(
        around center: Coordinate,
        within radius: Double,
        using generator: inout G
    ) -> Coordinate {
        let r = max(0, radius)
        guard r > 0 else { return center }
        let distance = r * sqrt(Double.random(in: 0...1, using: &generator))
        let bearing = Double.random(in: 0..<360, using: &generator)
        return destination(from: center, bearing: bearing, distance: distance)
    }

    public static func clampAccuracy(_ radius: Double) -> Double {
        guard radius.isFinite else { return 0 }
        return min(max(radius, 0), maxAccuracyRadius)
    }
}

extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}

/// Deterministic generator (SplitMix64) for reproducible jitter and tests.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
