import Foundation
import LocationSimCore

enum AppEnvironment {
    static var isUITesting: Bool { ProcessInfo.processInfo.arguments.contains("-uiTesting") }

    static var googlePlacesAPIKey: String? {
        let key = (Bundle.main.object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return key.isEmpty || key.hasPrefix("$(") ? nil : key
    }

    @MainActor
    static func makeViewModel() -> SimulatorViewModel {
        if isUITesting {
            let defaults = UserDefaults(suiteName: "LocationSimulatorUITests")!
            defaults.removePersistentDomain(forName: "LocationSimulatorUITests")
            return SimulatorViewModel(
                providers: [MockSearchService()],
                geocoder: MockReverseGeocoder(),
                historyStore: HistoryStore(defaults: defaults),
                debounce: .milliseconds(100)
            )
        }

        var providers: [PlaceSearchService] = [AppleMapsSearchService()]
        if let key = googlePlacesAPIKey {
            let client = GooglePlacesClient(
                apiKey: key,
                bundleIdentifier: Bundle.main.bundleIdentifier,
                languageCode: Locale.current.language.languageCode?.identifier
            )
            providers.insert(GooglePlacesSearchService(client: client), at: 0)
        }
        return SimulatorViewModel(providers: providers, geocoder: CLReverseGeocoder(), historyStore: HistoryStore())
    }
}
