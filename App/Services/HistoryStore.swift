import Foundation
import LocationSimCore

final class HistoryStore {
    private let defaults: UserDefaults
    private let key = "history.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [SimulatedLocation] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SimulatedLocation].self, from: data)) ?? []
    }

    func save(_ locations: [SimulatedLocation]) {
        defaults.set(try? JSONEncoder().encode(locations), forKey: key)
    }
}
