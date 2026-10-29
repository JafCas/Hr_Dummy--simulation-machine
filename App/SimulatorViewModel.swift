import Foundation
import LocationSimCore
import MapKit
import SwiftUI

struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
@Observable
final class SimulatorViewModel {
    // Search
    var query = ""
    private(set) var suggestions: [PlaceSuggestion] = []
    private(set) var isSearching = false
    var searchError: String?
    var selectedProviderIndex = 0

    // Selection
    private(set) var selected: SimulatedLocation?
    var jitterEnabled = false
    var accuracyRadius: Double = 10
    var jitterSampleCount = 12

    // Map / UI
    var cameraPosition: MapCameraPosition = .automatic
    var visibleCenter: Coordinate?
    var exportItem: ExportItem?
    private(set) var toastMessage: String?
    private(set) var history: [SimulatedLocation] = []

    let providers: [PlaceSearchService]
    private let geocoder: ReverseGeocoding
    private let historyStore: HistoryStore
    private let linkResolver: GoogleMapsLinkResolver
    private let copyHandler: (String) -> Void
    private let debounce: Duration
    private var searchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    static let historyLimit = 25

    init(
        providers: [PlaceSearchService],
        geocoder: ReverseGeocoding,
        historyStore: HistoryStore,
        linkResolver: GoogleMapsLinkResolver = GoogleMapsLinkResolver(),
        copyHandler: @escaping (String) -> Void = { UIPasteboard.general.string = $0 },
        debounce: Duration = .milliseconds(350)
    ) {
        precondition(!providers.isEmpty, "At least one search provider is required")
        self.providers = providers
        self.geocoder = geocoder
        self.historyStore = historyStore
        self.linkResolver = linkResolver
        self.copyHandler = copyHandler
        self.debounce = debounce
        self.history = historyStore.load()
    }

    var provider: PlaceSearchService {
        providers[min(max(selectedProviderIndex, 0), providers.count - 1)]
    }

    // MARK: Search

    func queryChanged() {
        searchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        searchError = nil
        guard q.count >= 2 else {
            suggestions = []
            isSearching = false
            return
        }
        let delay = debounce
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.search(q)
        }
    }

    func search(_ q: String) async {
        isSearching = true
        searchError = nil
        do {
            let results = try await provider.suggestions(for: q, near: visibleCenter)
            guard !Task.isCancelled else { return }
            suggestions = results
            if results.isEmpty { searchError = "No results for “\(q)”." }
        } catch is CancellationError {
        } catch {
            suggestions = []
            searchError = error.localizedDescription
        }
        isSearching = false
    }

    func select(_ suggestion: PlaceSuggestion) async {
        do {
            let location = try await provider.resolve(suggestion)
            setSelection(location, recenter: true)
            query = ""
            suggestions = []
            searchError = nil
        } catch {
            searchError = error.localizedDescription
        }
    }

    // MARK: Map pin

    func dropPin(at coordinate: Coordinate) async {
        guard coordinate.isValid else { return }
        let pin = SimulatedLocation(name: "Dropped Pin", coordinate: coordinate, source: .mapPin)
        setSelection(pin, recenter: false)
        guard let description = await geocoder.describe(coordinate), selected?.id == pin.id else { return }
        var named = pin
        named.name = description.name
        named.subtitle = description.subtitle
        setSelection(named, recenter: false)
    }

    // MARK: Manual coordinates / Google Maps links

    /// Returns an error message, or nil on success.
    func applyManualInput(_ text: String) async -> String? {
        let isLink = text.lowercased().contains("http")
        switch CoordinateInputParser.parse(text) {
        case let .coordinate(c)?:
            select(coordinate: c, isLink: isLink)
            return nil
        case let .shortLink(url)?:
            do {
                guard let c = try await linkResolver.resolve(url) else {
                    return "Couldn't find coordinates in that Google Maps link."
                }
                select(coordinate: c, isLink: true)
                return nil
            } catch {
                return "Couldn't open the link: \(error.localizedDescription)"
            }
        case nil:
            return "Enter “latitude, longitude” (e.g. 19.432608, -99.133209) or a Google Maps link."
        }
    }

    private func select(coordinate: Coordinate, isLink: Bool) {
        let location = SimulatedLocation(
            name: isLink ? "Google Maps Link" : "Custom Coordinates",
            subtitle: coordinate.formatted,
            coordinate: coordinate,
            source: isLink ? .googleMapsLink : .coordinates
        )
        setSelection(location, recenter: true)
    }

    // MARK: Selection & history

    func setSelection(_ location: SimulatedLocation, recenter: Bool) {
        selected = location
        if recenter {
            cameraPosition = .region(MKCoordinateRegion(center: location.coordinate.clCoordinate, latitudinalMeters: 600, longitudinalMeters: 600))
        }
        addToHistory(location)
    }

    func clearSelection() {
        selected = nil
    }

    private func addToHistory(_ location: SimulatedLocation) {
        history.removeAll { $0.id == location.id || GeoMath.distance($0.coordinate, location.coordinate) < 1 }
        history.insert(location, at: 0)
        if history.count > Self.historyLimit { history.removeLast(history.count - Self.historyLimit) }
        historyStore.save(history)
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        historyStore.save(history)
    }

    func clearHistory() {
        history = []
        historyStore.save(history)
    }

    // MARK: Export

    var effectiveAccuracyRadius: Double {
        jitterEnabled ? GeoMath.clampAccuracy(accuracyRadius) : 0
    }

    func gpxDocument() -> String? {
        guard let selected else { return nil }
        return GPXBuilder.document(
            for: selected,
            accuracyRadius: effectiveAccuracyRadius,
            jitterSamples: jitterEnabled ? jitterSampleCount : 1
        )
    }

    func exportGPX() {
        guard let selected, let gpx = gpxDocument() else { return }
        do {
            exportItem = ExportItem(url: try GPXExporter.write(gpx, fileName: selected.fileName))
        } catch {
            showToast("Export failed: \(error.localizedDescription)")
        }
    }

    func copy(_ text: String, label: String) {
        copyHandler(text)
        showToast("\(label) copied")
    }

    func showToast(_ message: String) {
        toastMessage = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toastMessage = nil
        }
    }
}
