import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum GooglePlacesError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case http(status: Int, message: String)
    case noLocation

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Google Places API key is not configured."
        case let .http(status, message): return "Google Places error \(status): \(message)"
        case .noLocation: return "Google Places returned no location for this place."
        }
    }
}

/// Minimal client for Google Places API (New): Autocomplete + Place Details.
/// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
public struct GooglePlacesClient: Sendable {
    public static let baseURL = URL(string: "https://places.googleapis.com/v1")!

    let apiKey: String
    let bundleIdentifier: String?
    let languageCode: String?
    let transport: HTTPTransport

    public init(apiKey: String, bundleIdentifier: String? = nil, languageCode: String? = nil, transport: HTTPTransport = URLSessionTransport()) {
        self.apiKey = apiKey
        self.bundleIdentifier = bundleIdentifier
        self.languageCode = languageCode
        self.transport = transport
    }

    public func autocomplete(_ input: String, near bias: Coordinate? = nil) async throws -> [PlaceSuggestion] {
        var body: [String: Any] = ["input": input]
        if let languageCode { body["languageCode"] = languageCode }
        if let bias {
            body["locationBias"] = ["circle": [
                "center": ["latitude": bias.latitude, "longitude": bias.longitude],
                "radius": 50_000.0
            ]]
        }
        var request = makeRequest(url: Self.baseURL.appendingPathComponent("places:autocomplete"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response: AutocompleteResponse = try await perform(request)
        return (response.suggestions ?? []).compactMap { suggestion in
            guard let p = suggestion.placePrediction else { return nil }
            return PlaceSuggestion(
                id: p.placeId,
                title: p.structuredFormat?.mainText?.text ?? p.text?.text ?? p.placeId,
                subtitle: p.structuredFormat?.secondaryText?.text ?? "",
                coordinate: nil,
                source: .googlePlaces
            )
        }
    }

    public func placeDetails(id: String) async throws -> SimulatedLocation {
        var components = URLComponents(url: Self.baseURL.appendingPathComponent("places/\(id)"), resolvingAgainstBaseURL: false)!
        if let languageCode { components.queryItems = [URLQueryItem(name: "languageCode", value: languageCode)] }
        var request = makeRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue("id,displayName,formattedAddress,location", forHTTPHeaderField: "X-Goog-FieldMask")

        let place: PlaceDetails = try await perform(request)
        guard let loc = place.location else { throw GooglePlacesError.noLocation }
        return SimulatedLocation(
            name: place.displayName?.text ?? place.formattedAddress ?? id,
            subtitle: place.formattedAddress,
            coordinate: Coordinate(latitude: loc.latitude, longitude: loc.longitude),
            source: .googlePlaces
        )
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue(apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        if let bundleIdentifier {
            // Required when the key is restricted to iOS apps.
            request.setValue(bundleIdentifier, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        guard !apiKey.isEmpty else { throw GooglePlacesError.missingAPIKey }
        let (data, response) = try await transport.send(request)
        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorEnvelope.self, from: data))?.error.message
                ?? HTTPURLResponse.localizedString(forStatusCode: response.statusCode)
            throw GooglePlacesError.http(status: response.statusCode, message: message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    struct Text: Decodable { let text: String? }
    struct AutocompleteResponse: Decodable {
        struct Suggestion: Decodable { let placePrediction: Prediction? }
        struct Prediction: Decodable {
            struct Structured: Decodable { let mainText: Text?; let secondaryText: Text? }
            let placeId: String
            let text: Text?
            let structuredFormat: Structured?
        }
        let suggestions: [Suggestion]?
    }
    struct PlaceDetails: Decodable {
        struct Location: Decodable { let latitude: Double; let longitude: Double }
        let id: String?
        let displayName: Text?
        let formattedAddress: String?
        let location: Location?
    }
    struct ErrorEnvelope: Decodable {
        struct Body: Decodable { let message: String }
        let error: Body
    }
}

/// Resolves Google Maps short links (maps.app.goo.gl/...) by following redirects, then parses the final URL.
public struct GoogleMapsLinkResolver: Sendable {
    let transport: HTTPTransport

    public init(transport: HTTPTransport = URLSessionTransport()) {
        self.transport = transport
    }

    public func resolve(_ url: URL) async throws -> Coordinate? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        let (data, response) = try await transport.send(request)
        if let final = response.url?.absoluteString, let c = CoordinateInputParser.coordinate(fromGoogleMapsURL: final) {
            return c
        }
        // Some redirects land on an HTML page that embeds the canonical URL.
        let html = String(decoding: data, as: UTF8.self)
        return CoordinateInputParser.coordinate(fromGoogleMapsURL: html)
    }
}
