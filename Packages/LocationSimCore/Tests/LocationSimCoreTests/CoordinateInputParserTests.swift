import XCTest
@testable import LocationSimCore

final class CoordinateInputParserTests: XCTestCase {
    func coord(_ s: String) -> Coordinate? {
        if case let .coordinate(c)? = CoordinateInputParser.parse(s) { return c }
        return nil
    }

    func testPlainCoordinates() {
        XCTAssertEqual(coord("19.432608, -99.133209"), Coordinate(latitude: 19.432608, longitude: -99.133209))
        XCTAssertEqual(coord("  19.432608 -99.133209 "), Coordinate(latitude: 19.432608, longitude: -99.133209))
        XCTAssertEqual(coord("-33.8568;151.2153"), Coordinate(latitude: -33.8568, longitude: 151.2153))
        XCTAssertEqual(coord("40,-3"), Coordinate(latitude: 40, longitude: -3))
    }

    func testRejectsInvalidInput() {
        XCTAssertNil(CoordinateInputParser.parse(""))
        XCTAssertNil(CoordinateInputParser.parse("Zócalo CDMX"))
        XCTAssertNil(coord("95.0, 10.0"))
        XCTAssertNil(coord("10.0, 190.0"))
        XCTAssertNil(coord("https://example.com/foo"))
    }

    func testGoogleMapsPlaceURLPrefersPinOverViewport() {
        let url = "https://www.google.com/maps/place/Z%C3%B3calo/@19.4326077,-99.1353989,17z/data=!3m1!4b1!4m6!3m5!1s0x85d1fecd!8m2!3d19.4326077!4d-99.133209!16s"
        XCTAssertEqual(coord(url), Coordinate(latitude: 19.4326077, longitude: -99.133209))
    }

    func testGoogleMapsViewportURL() {
        XCTAssertEqual(coord("https://www.google.com/maps/@48.8583701,2.2944813,17z"), Coordinate(latitude: 48.8583701, longitude: 2.2944813))
    }

    func testGoogleMapsQueryURLs() {
        XCTAssertEqual(coord("https://maps.google.com/?q=19.4326,-99.1332"), Coordinate(latitude: 19.4326, longitude: -99.1332))
        XCTAssertEqual(coord("https://www.google.com/maps/search/?api=1&query=47.5951518%2C-122.3316393"), Coordinate(latitude: 47.5951518, longitude: -122.3316393))
        XCTAssertEqual(coord("https://www.google.com/maps/dir/?api=1&destination=40.4168,-3.7038"), Coordinate(latitude: 40.4168, longitude: -3.7038))
        XCTAssertEqual(coord("https://maps.google.com/maps?ll=35.6586,139.7454&z=15"), Coordinate(latitude: 35.6586, longitude: 139.7454))
    }

    func testShortLinksNeedResolution() {
        XCTAssertEqual(CoordinateInputParser.parse("https://maps.app.goo.gl/abc123XYZ"), .shortLink(URL(string: "https://maps.app.goo.gl/abc123XYZ")!))
        XCTAssertEqual(CoordinateInputParser.parse("https://goo.gl/maps/xyz"), .shortLink(URL(string: "https://goo.gl/maps/xyz")!))
    }
}
