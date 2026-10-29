# Test plan & test cases

Three layers. Automated layers run in CI on every push/PR (`core` on Linux; `ios` on iPhone and iPad simulators).

| Layer | Where | Runs |
| --- | --- | --- |
| Core unit tests | `Packages/LocationSimCore/Tests` | `make core-test` (macOS/Linux) |
| App unit tests | `Tests/LocationSimulatorTests` | `make test-iphone` / `make test-ipad` |
| UI tests (XCUITest, offline mocks via `-uiTesting`) | `Tests/LocationSimulatorUITests` | `make test-iphone` / `make test-ipad` |
| Manual device tests | this document, section 4 | Before each release, on a real iPhone **and** iPad |

## 1. Core unit tests (`LocationSimCore`)
| ID | Test | Verifies |
| --- | --- | --- |
| TC-CORE-01 | `GeoMathTests.testOneDegreeOfLatitude` | Haversine: 1° lat ≈ 111 195 m |
| TC-CORE-02 | `testKnownCityDistance`, `testDistanceToSelfIsZero` | Real-world distance (Zócalo ▸ Ángel ≈ 3.66 km), zero distance |
| TC-CORE-03 | `testDestinationRoundTrip` | Point 20 m away in 8 bearings measures 20 m ± 1 cm |
| TC-CORE-04 | `testDestinationWrapsAntimeridian` | Longitude normalised across ±180° |
| TC-CORE-05 | `testRandomPointsStayWithin20Meters` | 10 000 jitter points all ≤ 20 m |
| TC-CORE-06 | `testRandomPointsAreUniformOverArea` | ~25 % of points inside r/2 (uniform over area, not clustered at center) |
| TC-CORE-07 | `testClampAccuracy`, `testZeroRadiusReturnsCenter` | Radius clamped to 0…20 m, NaN safe |
| TC-CORE-08 | `testCoordinateValidity` | Lat/lon range validation, 6-decimal formatting |
| TC-CORE-09 | `GPXTests.testStaticDocumentHasSingleWaypointWithSixDecimals` | Xcode-compatible GPX, one `<wpt>`, no `<time>` |
| TC-CORE-10 | `testNameIsXMLEscaped` | `& < > "` escaped |
| TC-CORE-11 | `testRoundTripPreservesCoordinateWithinCentimeters` | Build ▸ parse error < 0.2 m |
| TC-CORE-12 | `testJitterDocumentStaysWithinAccuracyRadius`, `testJitterRadiusIsClampedTo20Meters` | Jitter GPX: N timestamped points, 5 s apart, all ≤ 20 m even if 5 000 m requested |
| TC-CORE-13 | `testZeroRadiusIgnoresJitter`, `testParserRejectsGarbage` | Edge cases |
| TC-CORE-14 | `testFileNameIsSanitized` | `Zócalo <CDMX> & "Centro"` ▸ `Zocalo-CDMX-Centro.gpx` |
| TC-CORE-15 | `CoordinateInputParserTests.testPlainCoordinates` | `lat, lon` / space / `;` separators |
| TC-CORE-16 | `testRejectsInvalidInput` | Text, out-of-range values, non-Maps URLs rejected |
| TC-CORE-17 | `testGoogleMapsPlaceURLPrefersPinOverViewport` | `!3d!4d` (exact pin) beats `@lat,lon` (viewport) |
| TC-CORE-18 | `testGoogleMapsViewportURL`, `testGoogleMapsQueryURLs` | `@`, `q=`, `query=` (percent-encoded), `destination=`, `ll=` |
| TC-CORE-19 | `testShortLinksNeedResolution` | `maps.app.goo.gl`, `goo.gl/maps` detected |
| TC-CORE-20 | `GooglePlacesClientTests.testAutocompleteRequestAndDecoding` | POST `places:autocomplete`, API key + iOS bundle headers, language, location bias, query predictions ignored |
| TC-CORE-21 | `testPlaceDetailsDecoding` | GET `places/{id}` with field mask, name/address/location decoded |
| TC-CORE-22 | `testHTTPErrorSurfacesGoogleMessage`, `testMissingKeyFailsWithoutNetwork`, `testDetailsWithoutLocationThrows` | Error handling |
| TC-CORE-23 | `testShortLinkResolverUsesFinalRedirectURL`, `testShortLinkResolverFallsBackToHTMLBody` | Short link resolution |
| TC-CORE-24 | `SimulationCommandsTests.testCommands` | `simctl` / `pymobiledevice3` / helper commands |

## 2. App unit tests (`SimulatorViewModelTests`)
| ID | Test | Verifies |
| --- | --- | --- |
| TC-APP-01 | `testSearchPopulatesSuggestions` | Search results shown |
| TC-APP-02 | `testSearchWithNoResultsShowsMessage`, `testSearchErrorIsSurfaced` | Empty and error states |
| TC-APP-03 | `testShortQueryClearsSuggestions`, `testDebouncedQueryTriggersSearch` | < 2 chars clears; typing triggers debounced search |
| TC-APP-04 | `testSelectingSuggestionSetsSelectionAndClearsSearch` | Selection, search reset, history entry |
| TC-APP-05 | `testDropPinUsesReverseGeocodedName`, `testDropPinKeepsPlaceholderWhenGeocodingFails`, `testDropPinIgnoresInvalidCoordinate` | Map pin flow |
| TC-APP-06 | `testManualCoordinates`, `testGoogleMapsLink`, `testGoogleMapsShortLinkIsResolved`, `testInvalidManualInputReturnsError` | Manual entry flow |
| TC-APP-07 | `testStaticGPXIsExact`, `testJitterGPXStaysWithin20Meters`, `testNoGPXWithoutSelection` | Export content and the 20 m guarantee |
| TC-APP-08 | `testExportWritesGPXFile` | File written with sanitized name |
| TC-APP-09 | `testCopyUsesHandlerAndShowsToast` | Copy actions |
| TC-APP-10 | `testHistoryPersistsAcrossLaunches`, `testHistoryDeduplicatesSameSpotAndCaps` | Persistence, de-dup, cap 25, clear |

## 3. UI tests (`LocationSimulatorUITests`, run on iPhone and iPad)
| ID | Test | Steps ▸ Expected |
| --- | --- | --- |
| TC-UI-01 | `testSearchByNameAndSelect` | Type "Zoc" ▸ tap first result ▸ card shows "Zócalo", `19.432608, -99.133209`, Export enabled |
| TC-UI-02 | `testSearchWithoutResultsShowsMessage` | Type gibberish ▸ "No results" message |
| TC-UI-03 | `testTapOnMapDropsPin` | Tap map ▸ card shows "Dropped Pin" with coordinates |
| TC-UI-04 | `testManualCoordinateEntry` | Enter `48.858370, 2.294481` ▸ card shows those coordinates |
| TC-UI-05 | `testGoogleMapsLinkEntry` | Paste Google Maps place URL ▸ coordinates from `!3d!4d` |
| TC-UI-06 | `testInvalidCoordinateShowsError` | Enter text ▸ inline error, sheet stays open |
| TC-UI-07 | `testJitterRadiusIsLimitedTo20Meters` | Enable jitter ▸ slider to max ▸ label "Radius: 20 m" |
| TC-UI-08 | `testExportOpensShareSheet` | Export GPX ▸ system share sheet appears |
| TC-UI-09 | `testHistoryRecordsAndRestoresSelection` | Select ▸ clear ▸ History ▸ tap row ▸ selection restored |

## 4. Manual test cases (real hardware)
Run on one iPhone and one iPad (portrait + landscape, and iPad Split View). "Reference point" = coordinate shown in the app; measure distances with Google Maps' *Measure distance* or `GeoMath.distance`.

| ID | Precondition | Steps | Expected |
| --- | --- | --- | --- |
| TC-M-01 Search (Apple) | No Google key, online | Search "Palacio de Bellas Artes" ▸ select | Pin on the building; coordinate within 20 m of Google Maps' pin for the same place |
| TC-M-02 Search (Google) | Google key configured | Globe ▸ Google Places ▸ search "Museo Soumaya" ▸ select | Same name/address as Google Maps; coordinate equals Google Maps place coordinate (≤ 1 m) |
| TC-M-03 Google error | Invalid key | Search anything with Google Places | Readable error ("Google Places error 403: …"), app does not crash; switching to Apple Maps works |
| TC-M-04 Offline | Airplane mode | Search; paste coordinates; drop pin | Search shows network error; coordinates and pin still work (pin named "Dropped Pin") |
| TC-M-05 Pin placement | — | Zoom to street level ▸ tap a specific corner | Pin exactly where tapped; reverse-geocoded street name |
| TC-M-06 Google Maps share link | Google Maps app | Share ▸ Copy link ▸ paste in app | Short link resolved; coordinate equals the shared place |
| TC-M-07 Export & share | — | Export GPX ▸ AirDrop to Mac; Save to Files | File `<Name>.gpx` received; opens in Xcode; content has 6-decimal `<wpt>` |
| TC-M-08 Device simulation (static) | Device in Developer Mode, Xcode | Replace `GPX/CurrentLocation.gpx` ▸ Run on device ▸ open Apple Maps & Google Maps | Blue dot at target; distance to reference point ≤ 20 m (expected ≈ 0 m) |
| TC-M-09 Device simulation (jitter 20 m) | Jitter on, radius 20, 24 points | Export ▸ load via Debug ▸ Simulate Location ▸ watch Maps 2 min | Dot moves every ~5 s; never leaves the 20 m circle around the reference point |
| TC-M-10 Switch location live | TC-M-08 running | Debug ▸ Simulate Location ▸ another GPX | Device location updates within seconds |
| TC-M-11 Stop simulation | TC-M-08 running | Don't Simulate Location / stop debugging / reboot | Real GPS location returns |
| TC-M-12 Simulator | iOS Simulator booted | `scripts/simulate-location.sh simulator --gpx file.gpx` | Simulator Maps shows target; `clear` restores |
| TC-M-13 pymobiledevice3 | iOS 17+, `tunneld` running | `scripts/simulate-location.sh device --gpx file.gpx` | Device location = target without Xcode; `device clear` restores |
| TC-M-14 iPad layout | iPad | Rotate; use Split View ⅓ width | Side panel in regular width, bottom card in compact width; map remains tappable |
| TC-M-15 Permissions | Fresh install | Launch; deny location | App works fully; only the "my location" button is unavailable |
| TC-M-16 History | — | Select 3 places ▸ kill app ▸ relaunch ▸ History | 3 entries, newest first; swipe to delete; Clear empties |
| TC-M-17 Accessibility | VoiceOver, Dynamic Type XXL | Navigate search ▸ select ▸ export | All controls labelled and reachable; text not truncated in a way that hides coordinates |

## 5. Acceptance criteria
- Runs on iPhone and iPad (iOS/iPadOS 17+), portrait and landscape.
- A location can be chosen by name (Apple Maps or Google Places), by map pin, by coordinates and by Google Maps link.
- The simulated location applied to the device is within **20 m** of the chosen point (exact without jitter; ≤ radius ≤ 20 m with jitter) — TC-CORE-05/12, TC-APP-07, TC-M-08/09.
- All automated suites green in CI on iPhone and iPad simulators.
