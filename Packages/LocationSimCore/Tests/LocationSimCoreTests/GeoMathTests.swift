import XCTest
@testable import LocationSimCore

final class GeoMathTests: XCTestCase {
    let zocalo = Coordinate(latitude: 19.432608, longitude: -99.133209)

    func testOneDegreeOfLatitude() {
        let d = GeoMath.distance(Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 0))
        XCTAssertEqual(d, 111_195.08, accuracy: 1)
    }

    func testDistanceToSelfIsZero() {
        XCTAssertEqual(GeoMath.distance(zocalo, zocalo), 0, accuracy: 1e-9)
    }

    func testKnownCityDistance() {
        // Zócalo -> Ángel de la Independencia ≈ 3.6 km
        let angel = Coordinate(latitude: 19.427025, longitude: -99.167665)
        XCTAssertEqual(GeoMath.distance(zocalo, angel), 3_660, accuracy: 60)
    }

    func testDestinationRoundTrip() {
        for bearing in stride(from: 0.0, to: 360.0, by: 45.0) {
            let p = GeoMath.destination(from: zocalo, bearing: bearing, distance: 20)
            XCTAssertEqual(GeoMath.distance(zocalo, p), 20, accuracy: 0.01, "bearing \(bearing)")
        }
    }

    func testDestinationWrapsAntimeridian() {
        let p = GeoMath.destination(from: Coordinate(latitude: 0, longitude: 179.9999), bearing: 90, distance: 100)
        XCTAssertTrue(p.isValid)
        XCTAssertLessThan(p.longitude, -179)
    }

    func testRandomPointsStayWithin20Meters() {
        var gen = SeededGenerator(seed: 42)
        var maxSeen = 0.0
        for _ in 0..<10_000 {
            let p = GeoMath.randomPoint(around: zocalo, within: 20, using: &gen)
            maxSeen = max(maxSeen, GeoMath.distance(zocalo, p))
        }
        XCTAssertLessThanOrEqual(maxSeen, 20.0001)
        XCTAssertGreaterThan(maxSeen, 19) // actually covers the disk
    }

    func testRandomPointsAreUniformOverArea() {
        // Uniform disk: ~25% of points fall within r/2.
        var gen = SeededGenerator(seed: 7)
        let n = 20_000
        var inner = 0
        for _ in 0..<n where GeoMath.distance(zocalo, GeoMath.randomPoint(around: zocalo, within: 20, using: &gen)) <= 10 {
            inner += 1
        }
        XCTAssertEqual(Double(inner) / Double(n), 0.25, accuracy: 0.02)
    }

    func testZeroRadiusReturnsCenter() {
        var gen = SeededGenerator(seed: 1)
        XCTAssertEqual(GeoMath.randomPoint(around: zocalo, within: 0, using: &gen), zocalo)
    }

    func testClampAccuracy() {
        XCTAssertEqual(GeoMath.clampAccuracy(-5), 0)
        XCTAssertEqual(GeoMath.clampAccuracy(12.5), 12.5)
        XCTAssertEqual(GeoMath.clampAccuracy(500), 20)
        XCTAssertEqual(GeoMath.clampAccuracy(.nan), 0)
    }

    func testCoordinateValidity() {
        XCTAssertTrue(zocalo.isValid)
        XCTAssertFalse(Coordinate(latitude: 91, longitude: 0).isValid)
        XCTAssertFalse(Coordinate(latitude: 0, longitude: -181).isValid)
        XCTAssertFalse(Coordinate(latitude: .nan, longitude: 0).isValid)
        XCTAssertEqual(zocalo.formatted, "19.432608, -99.133209")
    }
}
