import Foundation
import LocationSimCore

/// Deterministic, offline services used by UI tests (`-uiTesting`) and unit tests.
struct MockSearchService: PlaceSearchService {
    static let fixtures = [
        PlaceSuggestion(id: "zocalo", title: "Zócalo", subtitle: "Centro Histórico, Ciudad de México", coordinate: Coordinate(latitude: 19.432608, longitude: -99.133209), source: .appleMaps),
        PlaceSuggestion(id: "angel", title: "Ángel de la Independencia", subtitle: "Paseo de la Reforma, Ciudad de México", coordinate: Coordinate(latitude: 19.427025, longitude: -99.167665), source: .appleMaps),
        PlaceSuggestion(id: "eiffel", title: "Tour Eiffel", subtitle: "Champ de Mars, Paris", coordinate: Coordinate(latitude: 48.858370, longitude: 2.294481), source: .appleMaps)
    ]

    var providerName = "Mock"
    var results: [PlaceSuggestion]? = nil
    var error: Error? = nil

    func suggestions(for query: String, near: Coordinate?) async throws -> [PlaceSuggestion] {
        if let error { throw error }
        if let results { return results }
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
        return Self.fixtures.filter {
            $0.title.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil).contains(q)
        }
    }
}

struct MockReverseGeocoder: ReverseGeocoding {
    var result: PlaceDescription? = nil

    func describe(_ coordinate: Coordinate) async -> PlaceDescription? { result }
}
