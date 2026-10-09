// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "HeiBanMac",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "HeiBanMac", targets: ["HeiBanMac"]),
        .executable(name: "HeiBanTestRunner", targets: ["HeiBanTestRunner"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "HeiBanCore",
            path: "Sources/HeiBanCore"
        ),
        .executableTarget(
            name: "HeiBanMac",
            dependencies: ["HeiBanCore"],
            path: "Sources/HeiBanMac",
            resources: [.copy("Resources/HeiBanLogo.png"), .copy("Resources/HeiBanAppIcon.png"), .copy("Resources/HeiBanUserGuide.html")]
        ),
        .executableTarget(
            name: "HeiBanTestRunner",
            dependencies: ["HeiBanCore"],
            path: "Sources/HeiBanTestRunner"
        )
    ]
)
