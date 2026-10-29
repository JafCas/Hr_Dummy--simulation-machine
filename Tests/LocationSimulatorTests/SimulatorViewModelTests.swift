import LocationSimCore
import XCTest
@testable import LocationSimulator

final class StubTransport: HTTPTransport, @unchecked Sendable {
    var finalURL: URL
    init(finalURL: URL) { self.finalURL = finalURL }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        (Data(), HTTPURLResponse(url: finalURL, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

struct StubError: LocalizedError {
    var errorDescription: String? { "Network down" }
}

@MainActor
final class SimulatorViewModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var copied: [String] = []
    private let zocalo = Coordinate(latitude: 19.432608, longitude: -99.133209)

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: "tests-\(UUID().uuidString)")
        copied = []
    }

    private func makeViewModel(
        search: MockSearchService = MockSearchService(),
        geocoder: MockReverseGeocoder = MockReverseGeocoder(),
        resolverURL: URL = URL(string: "https://www.google.com/maps/@48.8583701,2.2944813,17z")!,
        debounce: Duration = .zero
    ) -> SimulatorViewModel {
        SimulatorViewModel(
            providers: [search],
            geocoder: geocoder,
            historyStore: HistoryStore(defaults: defaults),
            linkResolver: GoogleMapsLinkResolver(transport: StubTransport(finalURL: resolverURL)),
            copyHandler: { [weak self] in self?.copied.append($0) },
            debounce: debounce
        )
    }

    // MARK: Search

    func testSearchPopulatesSuggestions() async {
        let vm = makeViewModel()
        await vm.search("zoc")
        XCTAssertEqual(vm.suggestions.map(\.title), ["Zócalo"])
        XCTAssertNil(vm.searchError)
        XCTAssertFalse(vm.isSearching)
    }

    func testSearchWithNoResultsShowsMessage() async {
        let vm = makeViewModel(search: MockSearchService(results: []))
        await vm.search("nowhere")
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertEqual(vm.searchError, "No results for “nowhere”.")
    }

    func testSearchErrorIsSurfaced() async {
        let vm = makeViewModel(search: MockSearchService(error: StubError()))
        await vm.search("zoc")
        XCTAssertEqual(vm.searchError, "Network down")
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func testShortQueryClearsSuggestions() async {
        let vm = makeViewModel()
        await vm.search("zoc")
        vm.query = "z"
        vm.queryChanged()
        XCTAssertTrue(vm.suggestions.isEmpty)
    }

    func testDebouncedQueryTriggersSearch() async throws {
        let vm = makeViewModel(debounce: .milliseconds(10))
        vm.query = "eiffel"
        vm.queryChanged()
        for _ in 0..<50 where vm.suggestions.isEmpty {
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertEqual(vm.suggestions.first?.title, "Tour Eiffel")
    }

    func testSelectingSuggestionSetsSelectionAndClearsSearch() async {
        let vm = makeViewModel()
        vm.query = "zoc"
        await vm.search("zoc")
        await vm.select(vm.suggestions[0])
        XCTAssertEqual(vm.selected?.name, "Zócalo")
        XCTAssertEqual(vm.selected?.coordinate, zocalo)
        XCTAssertEqual(vm.selected?.source, .appleMaps)
        XCTAssertEqual(vm.query, "")
        XCTAssertTrue(vm.suggestions.isEmpty)
        XCTAssertEqual(vm.history.count, 1)
    }

    // MARK: Map pin

    func testDropPinUsesReverseGeocodedName() async {
        let vm = makeViewModel(geocoder: MockReverseGeocoder(result: PlaceDescription(name: "Plaza de la Constitución", subtitle: "Ciudad de México")))
        await vm.dropPin(at: zocalo)
        XCTAssertEqual(vm.selected?.name, "Plaza de la Constitución")
        XCTAssertEqual(vm.selected?.source, .mapPin)
        XCTAssertEqual(vm.selected?.coordinate, zocalo)
        XCTAssertEqual(vm.history.count, 1, "geocoded name replaces the placeholder history entry")
    }

    func testDropPinKeepsPlaceholderWhenGeocodingFails() async {
        let vm = makeViewModel()
        await vm.dropPin(at: zocalo)
        XCTAssertEqual(vm.selected?.name, "Dropped Pin")
    }

    func testDropPinIgnoresInvalidCoordinate() async {
        let vm = makeViewModel()
        await vm.dropPin(at: Coordinate(latitude: 200, longitude: 0))
        XCTAssertNil(vm.selected)
    }

    // MARK: Manual input

    func testManualCoordinates() async {
        let vm = makeViewModel()
        let error = await vm.applyManualInput("19.432608, -99.133209")
        XCTAssertNil(error)
        XCTAssertEqual(vm.selected?.coordinate, zocalo)
        XCTAssertEqual(vm.selected?.source, .coordinates)
    }

    func testGoogleMapsLink() async {
        let vm = makeViewModel()
        let error = await vm.applyManualInput("https://www.google.com/maps/place/Z%C3%B3calo/@19.43,-99.13,17z/data=!3d19.432608!4d-99.133209")
        XCTAssertNil(error)
        XCTAssertEqual(vm.selected?.coordinate, zocalo)
        XCTAssertEqual(vm.selected?.source, .googleMapsLink)
    }

    func testGoogleMapsShortLinkIsResolved() async {
        let vm = makeViewModel()
        let error = await vm.applyManualInput("https://maps.app.goo.gl/abc123")
        XCTAssertNil(error)
        XCTAssertEqual(vm.selected?.coordinate, Coordinate(latitude: 48.8583701, longitude: 2.2944813))
    }

    func testInvalidManualInputReturnsError() async {
        let vm = makeViewModel()
        let error = await vm.applyManualInput("hello world")
        XCTAssertNotNil(error)
        XCTAssertNil(vm.selected)
    }

    // MARK: GPX / accuracy

    func testStaticGPXIsExact() async throws {
        let vm = makeViewModel()
        _ = await vm.applyManualInput("19.432608, -99.133209")
        let gpx = try XCTUnwrap(vm.gpxDocument())
        let waypoints = GPXParser.waypoints(from: Data(gpx.utf8))
        XCTAssertEqual(waypoints.count, 1)
        XCTAssertLessThan(GeoMath.distance(waypoints[0].coordinate, zocalo), 0.2)
    }

    func testJitterGPXStaysWithin20Meters() async throws {
        let vm = makeViewModel()
        _ = await vm.applyManualInput("19.432608, -99.133209")
        vm.jitterEnabled = true
        vm.accuracyRadius = 500 // must clamp to 20 m
        vm.jitterSampleCount = 100
        XCTAssertEqual(vm.effectiveAccuracyRadius, 20)
        let waypoints = GPXParser.waypoints(from: Data(try XCTUnwrap(vm.gpxDocument()).utf8))
        XCTAssertEqual(waypoints.count, 100)
        for wpt in waypoints {
            XCTAssertLessThanOrEqual(GeoMath.distance(wpt.coordinate, zocalo), 20.2)
        }
    }

    func testNoGPXWithoutSelection() {
        XCTAssertNil(makeViewModel().gpxDocument())
    }

    func testExportWritesGPXFile() async throws {
        let vm = makeViewModel()
        await vm.search("zoc")
        await vm.select(vm.suggestions[0])
        vm.exportGPX()
        let url = try XCTUnwrap(vm.exportItem?.url)
        XCTAssertEqual(url.lastPathComponent, "Zocalo.gpx")
        let contents = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(contents.contains(#"<wpt lat="19.432608" lon="-99.133209">"#))
    }

    func testCopyUsesHandlerAndShowsToast() async {
        let vm = makeViewModel()
        vm.copy("19.432608, -99.133209", label: "Coordinates")
        XCTAssertEqual(copied, ["19.432608, -99.133209"])
        XCTAssertEqual(vm.toastMessage, "Coordinates copied")
    }

    // MARK: History

    func testHistoryPersistsAcrossLaunches() async {
        let vm = makeViewModel()
        _ = await vm.applyManualInput("19.432608, -99.133209")
        let relaunched = makeViewModel()
        XCTAssertEqual(relaunched.history.first?.coordinate, zocalo)
    }

    func testHistoryDeduplicatesSameSpotAndCaps() async {
        let vm = makeViewModel()
        _ = await vm.applyManualInput("19.432608, -99.133209")
        _ = await vm.applyManualInput("19.432608, -99.133209")
        XCTAssertEqual(vm.history.count, 1)
        for i in 0..<40 {
            _ = await vm.applyManualInput("10.\(String(format: "%03d", i)), 20.0")
        }
        XCTAssertEqual(vm.history.count, SimulatorViewModel.historyLimit)
        vm.clearHistory()
        XCTAssertTrue(makeViewModel().history.isEmpty)
    }
}
