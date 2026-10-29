import Foundation
import LocationSimCore
import MapKit

protocol PlaceSearchService: Sendable {
    var providerName: String { get }
    func suggestions(for query: String, near: Coordinate?) async throws -> [PlaceSuggestion]
    func resolve(_ suggestion: PlaceSuggestion) async throws -> SimulatedLocation
}

enum PlaceSearchError: LocalizedError {
    case missingCoordinate

    var errorDescription: String? { "This result has no coordinates." }
}

extension PlaceSearchService {
    func resolve(_ suggestion: PlaceSuggestion) async throws -> SimulatedLocation {
        guard let coordinate = suggestion.coordinate else { throw PlaceSearchError.missingCoordinate }
        return SimulatedLocation(name: suggestion.title, subtitle: suggestion.subtitle, coordinate: coordinate, source: suggestion.source)
    }
}

/// Apple Maps search (no API key required).
struct AppleMapsSearchService: PlaceSearchService {
    let providerName = "Apple Maps"

    func suggestions(for query: String, near: Coordinate?) async throws -> [PlaceSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let near {
            request.region = MKCoordinateRegion(center: near.clCoordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        }
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.enumerated().map { index, item in
                let c = Coordinate(item.placemark.coordinate)
                return PlaceSuggestion(
                    id: "\(index)-\(c.formatted)",
                    title: item.name ?? item.placemark.title ?? c.formatted,
                    subtitle: item.placemark.title ?? "",
                    coordinate: c,
                    source: .appleMaps
                )
            }
        } catch let error as MKError where error.code == .placemarkNotFound {
            return []
        }
    }
}

/// Google Places (New) search: same names/places as Google Maps. Enabled when `GOOGLE_PLACES_API_KEY` is set.
struct GooglePlacesSearchService: PlaceSearchService {
    let providerName = "Google Places"
    let client: GooglePlacesClient

    func suggestions(for query: String, near: Coordinate?) async throws -> [PlaceSuggestion] {
        try await client.autocomplete(query, near: near)
    }

    func resolve(_ suggestion: PlaceSuggestion) async throws -> SimulatedLocation {
        try await client.placeDetails(id: suggestion.id)
    }
}
