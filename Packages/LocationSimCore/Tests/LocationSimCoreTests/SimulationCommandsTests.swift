import XCTest
@testable import LocationSimCore

final class SimulationCommandsTests: XCTestCase {
    let c = Coordinate(latitude: 19.432608, longitude: -99.133209)

    func testCommands() {
        XCTAssertEqual(SimulationCommands.simulator(c), "xcrun simctl location booted set 19.432608,-99.133209")
        XCTAssertEqual(SimulationCommands.physicalDevice(c), "pymobiledevice3 developer dvt simulate-location set -- 19.432608 -99.133209")
        XCTAssertEqual(SimulationCommands.helperScript(c, target: "device"), "./scripts/simulate-location.sh device 19.432608 -99.133209")
    }
}
