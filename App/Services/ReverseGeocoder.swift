import CoreLocation
import LocationSimCore

struct PlaceDescription: Equatable, Sendable {
    var name: String
    var subtitle: String?
}

protocol ReverseGeocoding: Sendable {
    func describe(_ coordinate: Coordinate) async -> PlaceDescription?
}

final class CLReverseGeocoder: ReverseGeocoding, @unchecked Sendable {
    private let geocoder = CLGeocoder()

    func describe(_ coordinate: Coordinate) async -> PlaceDescription? {
        geocoder.cancelGeocode()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await geocoder.reverseGeocodeLocation(location).first else { return nil }
        let name = placemark.name ?? placemark.thoroughfare ?? placemark.locality ?? "Dropped Pin"
        let subtitle = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .joined(separator: ", ")
        return PlaceDescription(name: name, subtitle: subtitle.isEmpty ? nil : subtitle)
    }
}
