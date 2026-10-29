import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import LocationSimCore

final class MockTransport: HTTPTransport, @unchecked Sendable {
    var status = 200
    var body = Data()
    var finalURL: URL?
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let response = HTTPURLResponse(url: finalURL ?? request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (body, response)
    }
}

final class GooglePlacesClientTests: XCTestCase {
    func testAutocompleteRequestAndDecoding() async throws {
        let transport = MockTransport()
        transport.body = Data(#"""
        {"suggestions":[
          {"placePrediction":{"placeId":"ChIJ1","text":{"text":"Zócalo, Centro, CDMX"},
            "structuredFormat":{"mainText":{"text":"Zócalo"},"secondaryText":{"text":"Centro, CDMX, México"}}}},
          {"queryPrediction":{"text":{"text":"zocalo restaurants"}}}
        ]}
        """#.utf8)
        let client = GooglePlacesClient(apiKey: "KEY", bundleIdentifier: "com.jafcas.LocationSimulator", languageCode: "es", transport: transport)

        let results = try await client.autocomplete("Zocalo", near: Coordinate(latitude: 19.4, longitude: -99.1))

        XCTAssertEqual(results, [PlaceSuggestion(id: "ChIJ1", title: "Zócalo", subtitle: "Centro, CDMX, México", coordinate: nil, source: .googlePlaces)])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://places.googleapis.com/v1/places:autocomplete")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Goog-Api-Key"), "KEY")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Ios-Bundle-Identifier"), "com.jafcas.LocationSimulator")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["input"] as? String, "Zocalo")
        XCTAssertEqual(json["languageCode"] as? String, "es")
        XCTAssertNotNil(json["locationBias"])
    }

    func testPlaceDetailsDecoding() async throws {
        let transport = MockTransport()
        transport.body = Data(#"""
        {"id":"ChIJ1","displayName":{"text":"Zócalo","languageCode":"es"},
         "formattedAddress":"P.za de la Constitución S/N, Centro, CDMX","location":{"latitude":19.4326077,"longitude":-99.133208}}
        """#.utf8)
        let client = GooglePlacesClient(apiKey: "KEY", transport: transport)

        let place = try await client.placeDetails(id: "ChIJ1")

        XCTAssertEqual(place.name, "Zócalo")
        XCTAssertEqual(place.subtitle, "P.za de la Constitución S/N, Centro, CDMX")
        XCTAssertEqual(place.coordinate, Coordinate(latitude: 19.4326077, longitude: -99.133208))
        XCTAssertEqual(place.source, .googlePlaces)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/v1/places/ChIJ1")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Goog-FieldMask"), "id,displayName,formattedAddress,location")
    }

    func testHTTPErrorSurfacesGoogleMessage() async {
        let transport = MockTransport()
        transport.status = 403
        transport.body = Data(#"{"error":{"code":403,"message":"API key not valid.","status":"PERMISSION_DENIED"}}"#.utf8)
        let client = GooglePlacesClient(apiKey: "BAD", transport: transport)
        do {
            _ = try await client.autocomplete("x")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? GooglePlacesError, .http(status: 403, message: "API key not valid."))
        }
    }

    func testMissingKeyFailsWithoutNetwork() async {
        let transport = MockTransport()
        let client = GooglePlacesClient(apiKey: "", transport: transport)
        do {
            _ = try await client.autocomplete("x")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? GooglePlacesError, .missingAPIKey)
            XCTAssertTrue(transport.requests.isEmpty)
        }
    }

    func testDetailsWithoutLocationThrows() async {
        let transport = MockTransport()
        transport.body = Data(#"{"id":"x","displayName":{"text":"Nowhere"}}"#.utf8)
        do {
            _ = try await GooglePlacesClient(apiKey: "K", transport: transport).placeDetails(id: "x")
            XCTFail("expected error")
        } catch {
            XCTAssertEqual(error as? GooglePlacesError, .noLocation)
        }
    }

    func testShortLinkResolverUsesFinalRedirectURL() async throws {
        let transport = MockTransport()
        transport.finalURL = URL(string: "https://www.google.com/maps/place/Torre+Eiffel/@48.85837,2.29448,17z/data=!3d48.8583701!4d2.2944813")
        let c = try await GoogleMapsLinkResolver(transport: transport).resolve(URL(string: "https://maps.app.goo.gl/abc")!)
        XCTAssertEqual(c, Coordinate(latitude: 48.8583701, longitude: 2.2944813))
    }

    func testShortLinkResolverFallsBackToHTMLBody() async throws {
        let transport = MockTransport()
        transport.finalURL = URL(string: "https://consent.google.com/")
        transport.body = Data(#"<a href="https://www.google.com/maps/@35.6586,139.7454,15z">"#.utf8)
        let c = try await GoogleMapsLinkResolver(transport: transport).resolve(URL(string: "https://maps.app.goo.gl/abc")!)
        XCTAssertEqual(c, Coordinate(latitude: 35.6586, longitude: 139.7454))
    }
}
