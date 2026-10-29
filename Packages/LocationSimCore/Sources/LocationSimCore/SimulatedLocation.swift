import Foundation

public struct SimulatedLocation: Codable, Hashable, Identifiable, Sendable {
    public enum Source: String, Codable, Sendable, CaseIterable {
        case appleMaps
        case googlePlaces
        case mapPin
        case coordinates
        case googleMapsLink
    }

    public var id: UUID
    public var name: String
    public var subtitle: String?
    public var coordinate: Coordinate
    public var source: Source
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        subtitle: String? = nil,
        coordinate: Coordinate,
        source: Source,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.source = source
        self.createdAt = createdAt
    }

    /// File-system safe name used for exported GPX files.
    public var fileName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let base = name
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let trimmed = String(base.prefix(60))
        return (trimmed.isEmpty ? "SimulatedLocation" : trimmed) + ".gpx"
    }
}

public struct PlaceSuggestion: Hashable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var subtitle: String
    /// Present when the provider already returns coordinates (Apple Maps); nil when a details lookup is needed (Google Places).
    public var coordinate: Coordinate?
    public var source: SimulatedLocation.Source

    public init(id: String, title: String, subtitle: String, coordinate: Coordinate?, source: SimulatedLocation.Source) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.source = source
    }
}
