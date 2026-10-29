// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "LocationSimCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "LocationSimCore", targets: ["LocationSimCore"])
    ],
    targets: [
        .target(name: "LocationSimCore"),
        .testTarget(name: "LocationSimCoreTests", dependencies: ["LocationSimCore"])
    ]
)
