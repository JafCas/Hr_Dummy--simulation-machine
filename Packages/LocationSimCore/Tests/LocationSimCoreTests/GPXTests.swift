import XCTest
@testable import LocationSimCore

final class GPXTests: XCTestCase {
    let location = SimulatedLocation(
        name: "Zócalo <CDMX> & \"Centro\"",
        coordinate: Coordinate(latitude: 19.432608, longitude: -99.133209),
        source: .appleMaps
    )

    func testStaticDocumentHasSingleWaypointWithSixDecimals() {
        let gpx = GPXBuilder.document(for: location)
        XCTAssertTrue(gpx.hasPrefix(#"<?xml version="1.0" encoding="UTF-8"?>"#))
        XCTAssertTrue(gpx.contains(#"<wpt lat="19.432608" lon="-99.133209">"#))
        XCTAssertEqual(gpx.components(separatedBy: "<wpt ").count - 1, 1)
        XCTAssertFalse(gpx.contains("<time>"))
    }

    func testNameIsXMLEscaped() {
        let gpx = GPXBuilder.document(for: location)
        XCTAssertTrue(gpx.contains("<name>Zócalo &lt;CDMX&gt; &amp; &quot;Centro&quot;</name>"))
    }

    func testRoundTripPreservesCoordinateWithinCentimeters() {
        let gpx = GPXBuilder.document(for: location)
        let parsed = GPXParser.waypoints(from: Data(gpx.utf8))
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(parsed[0].name, location.name)
        XCTAssertLessThan(GeoMath.distance(parsed[0].coordinate, location.coordinate), 0.2)
    }

    func testJitterDocumentStaysWithinAccuracyRadius() {
        var gen = SeededGenerator(seed: 99)
        let gpx = GPXBuilder.document(for: location, accuracyRadius: 20, jitterSamples: 30, using: &gen)
        let parsed = GPXParser.waypoints(from: Data(gpx.utf8))
        XCTAssertEqual(parsed.count, 30)
        XCTAssertEqual(parsed.first?.coordinate, location.coordinate)
        for wpt in parsed {
            XCTAssertLessThanOrEqual(GeoMath.distance(wpt.coordinate, location.coordinate), 20.2)
        }
        XCTAssertEqual(gpx.components(separatedBy: "<time>").count - 1, 30)
        XCTAssertTrue(gpx.contains("<time>2023-11-14T22:13:20Z</time>"))
        XCTAssertTrue(gpx.contains("<time>2023-11-14T22:13:25Z</time>"))
    }

    func testJitterRadiusIsClampedTo20Meters() {
        var gen = SeededGenerator(seed: 3)
        let gpx = GPXBuilder.document(for: location, accuracyRadius: 5_000, jitterSamples: 200, using: &gen)
        for wpt in GPXParser.waypoints(from: Data(gpx.utf8)) {
            XCTAssertLessThanOrEqual(GeoMath.distance(wpt.coordinate, location.coordinate), 20.2)
        }
    }

    func testZeroRadiusIgnoresJitter() {
        var gen = SeededGenerator(seed: 3)
        let gpx = GPXBuilder.document(for: location, accuracyRadius: 0, jitterSamples: 10, using: &gen)
        XCTAssertEqual(GPXParser.waypoints(from: Data(gpx.utf8)).count, 1)
    }

    func testParserRejectsGarbage() {
        XCTAssertTrue(GPXParser.waypoints(from: Data("not xml".utf8)).isEmpty)
    }

    func testFileNameIsSanitized() {
        XCTAssertEqual(location.fileName, "Zocalo-CDMX-Centro.gpx")
        let empty = SimulatedLocation(name: "///", coordinate: location.coordinate, source: .mapPin)
        XCTAssertEqual(empty.fileName, "SimulatedLocation.gpx")
    }
}
