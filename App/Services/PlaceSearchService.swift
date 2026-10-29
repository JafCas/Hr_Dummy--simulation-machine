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
        guard let near else { return Self.interleave(try await search(query, region: nil), []) }
        // A regional search alone hides well-known places elsewhere (e.g. "Palacio de Bellas Artes" from San Francisco
        // returns SF's Palace of Fine Arts), so also run an unbiased search and interleave both.
        let region = MKCoordinateRegion(center: near.clCoordinate, latitudinalMeters: 50_000, longitudinalMeters: 50_000)
        async let nearby = search(query, region: region)
        async let global = search(query, region: nil)
        return Self.interleave(try await nearby, try await global)
    }

    /// Alternates both lists, dropping results within 50 m of one already kept.
    static func interleave(_ first: [PlaceSuggestion], _ second: [PlaceSuggestion]) -> [PlaceSuggestion] {
        var merged: [PlaceSuggestion] = []
        for index in 0..<max(first.count, second.count) {
            for list in [first, second] where index < list.count {
                let candidate = list[index]
                let isDuplicate = merged.contains { kept in
                    guard let a = kept.coordinate, let b = candidate.coordinate else { return kept.id == candidate.id }
                    return GeoMath.distance(a, b) < 50
                }
                if !isDuplicate { merged.append(candidate) }
            }
        }
        return merged
    }

    private func search(_ query: String, region: MKCoordinateRegion?) async throws -> [PlaceSuggestion] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let region { request.region = region }
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.map { item in
                let c = Coordinate(item.placemark.coordinate)
                return PlaceSuggestion(
                    id: c.formatted,
                    title: item.name ?? item.placemark.title ?? c.formatted,
                    subtitle: (item.placemark.title ?? "").replacingOccurrences(of: "\n", with: ", "),
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
