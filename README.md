# Location Simulator (iPhone & iPad)

SwiftUI app to pick any location — by **name** (Apple Maps, or Google Places for Google Maps names), by **dropping a pin** on the map, or by pasting **coordinates / a Google Maps link** — and export it as a **GPX** file that Xcode (or the helper script) uses to simulate that location on a real iPhone/iPad or the iOS Simulator.

> **Why GPX instead of changing the GPS from inside the app?** iOS has no public API that lets an app change the location seen by the rest of the system (only jailbreak tweaks can, and the App Store rejects them). Apple's supported way is developer location simulation (Xcode / `simctl` / the developer services used by `pymobiledevice3`). This app is the front end for that: it finds the exact coordinate and produces the file/commands.

## Features
- Search by place name/address: Apple Maps (no key) or **Google Places API (New)** when `GOOGLE_PLACES_API_KEY` is set (provider switch in the search bar).
- Tap the map to drop a pin (reverse-geocoded name).
- Paste `lat, lon`, Google Maps URLs (`/place/…!3d…!4d…`, `@lat,lon`, `?q=`, `?query=`) or `maps.app.goo.gl` short links.
- Accuracy: coordinates written with 6 decimals (≈0.1 m). Optional **GPS jitter** keeps every point within a radius of 1–20 m (hard-capped at 20 m).
- Export GPX (share sheet: AirDrop, Files, …), copy coordinates / GPX / `simctl` / `pymobiledevice3` commands.
- History of recent locations. Adaptive layout: bottom card on iPhone, side panel on iPad.

## Quick start
```bash
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # optional: Google key + team ID
make open                                                    # generates and opens LocationSimulator.xcodeproj
```
Requirements: Xcode 15+ (iOS 17 SDK), iOS/iPadOS 17+.

## Apply a location
| Target | How |
| --- | --- |
| Physical device (any app sees it) | Replace `GPX/CurrentLocation.gpx` with the exported file, run the app from Xcode on the device. Switch any time via **Debug ▸ Simulate Location**. |
| iOS Simulator | `scripts/simulate-location.sh simulator 19.432608 -99.133209` (or `--gpx file.gpx`) |
| Physical device, no Xcode session (iOS 17+) | `sudo pymobiledevice3 remote tunneld` then `scripts/simulate-location.sh device --gpx file.gpx` |

Full workflow: [docs/WORKFLOW.md](docs/WORKFLOW.md). Test plan & cases: [docs/TEST_CASES.md](docs/TEST_CASES.md).

## Project layout
```
App/                      SwiftUI app (views, view model, Apple/Google search, history, export)
Packages/LocationSimCore/ Platform-independent core: geo math, GPX, link parsing, Google Places client (+ tests, run on Linux too)
Tests/                    App unit tests and XCUITests (iPhone + iPad)
GPX/CurrentLocation.gpx   Default location applied by the scheme when running from Xcode
scripts/                  simulate-location.sh, pick-simulator.sh
project.yml               XcodeGen spec (project file is generated, not committed)
```

## Tests
```bash
make core-test     # core package (macOS or Linux)
make test-iphone   # unit + UI tests on an iPhone simulator
make test-ipad     # unit + UI tests on an iPad simulator
```
CI (`.github/workflows/ci.yml`) runs all three on every push/PR.
