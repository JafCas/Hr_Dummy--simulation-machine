import XCTest

/// Runs against offline mock services (launch argument `-uiTesting`) on iPhone and iPad simulators.
final class LocationSimulatorUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func enterManually(_ text: String) {
        app.buttons["coordinateEntryButton"].tap()
        let input = app.textFields["coordinateInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(text)
        app.buttons["applyCoordinateButton"].tap()
    }

    private func assertSelection(name: String? = nil, coordinate: String? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let nameLabel = app.staticTexts["selectedName"]
        XCTAssertTrue(nameLabel.waitForExistence(timeout: 5), "selection panel not shown", file: file, line: line)
        if let name { XCTAssertEqual(nameLabel.label, name, file: file, line: line) }
        if let coordinate { XCTAssertEqual(app.staticTexts["selectedCoordinate"].label, coordinate, file: file, line: line) }
    }

    // TC-UI-01
    func testSearchByNameAndSelect() {
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Zoc")
        let first = app.buttons["searchResult_0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        assertSelection(name: "Zócalo", coordinate: "19.432608, -99.133209")
        XCTAssertTrue(app.buttons["exportButton"].isEnabled)
    }

    // TC-UI-02
    func testSearchWithoutResultsShowsMessage() {
        let field = app.textFields["searchField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("qwertyuiop")
        XCTAssertTrue(app.staticTexts["searchError"].waitForExistence(timeout: 5))
    }

    // TC-UI-03
    func testTapOnMapDropsPin() {
        let map = element("map")
        XCTAssertTrue(map.waitForExistence(timeout: 5))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5)).tap()
        assertSelection(name: "Dropped Pin")
        XCTAssertFalse(app.staticTexts["selectedCoordinate"].label.isEmpty)
    }

    // TC-UI-04
    func testManualCoordinateEntry() {
        enterManually("48.858370, 2.294481")
        assertSelection(name: "Custom Coordinates", coordinate: "48.858370, 2.294481")
    }

    // TC-UI-05
    func testGoogleMapsLinkEntry() {
        enterManually("https://www.google.com/maps/place/Zocalo/@19.43,-99.13,17z/data=!3d19.432608!4d-99.133209")
        assertSelection(name: "Google Maps Link", coordinate: "19.432608, -99.133209")
    }

    // TC-UI-06
    func testInvalidCoordinateShowsError() {
        enterManually("not a place")
        XCTAssertTrue(app.staticTexts["coordinateError"].waitForExistence(timeout: 5))
    }

    // TC-UI-07
    func testJitterRadiusIsLimitedTo20Meters() {
        enterManually("19.432608, -99.133209")
        assertSelection()
        let toggle = app.switches["jitterToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        let slider = app.sliders["accuracySlider"]
        XCTAssertTrue(slider.waitForExistence(timeout: 5))
        slider.adjust(toNormalizedSliderPosition: 1.0)
        XCTAssertEqual(app.staticTexts["accuracyLabel"].label, "Radius: 20 m")
    }

    // TC-UI-08
    func testExportOpensShareSheet() {
        enterManually("19.432608, -99.133209")
        assertSelection()
        app.buttons["exportButton"].tap()
        let shareSheet = app.otherElements["ActivityListView"]
        let copyAction = app.buttons["Copy"]
        let appeared = shareSheet.waitForExistence(timeout: 8) || copyAction.exists || app.cells["Save to Files"].exists
        XCTAssertTrue(appeared, "share sheet did not appear")
    }

    // TC-UI-09
    func testHistoryRecordsAndRestoresSelection() {
        enterManually("48.858370, 2.294481")
        assertSelection()
        app.buttons["clearSelectionButton"].tap()
        app.buttons["historyButton"].tap()
        let row = app.buttons["historyRow"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        assertSelection(coordinate: "48.858370, 2.294481")
    }
}
