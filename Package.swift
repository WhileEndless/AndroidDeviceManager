// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "AndroidDeviceManager",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(
            name: "AndroidDeviceManager",
            targets: ["AndroidDeviceManager"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "AndroidDeviceManager",
            dependencies: [],
            path: "Sources"
        ),
        .testTarget(
            name: "AndroidDeviceManagerTests",
            dependencies: ["AndroidDeviceManager"],
            path: "Tests"
        )
    ]
)