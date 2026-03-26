// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlapMyMac",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        .executableTarget(
            name: "SlapMyMac",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            exclude: ["Resources/Info.plist", "Resources/SlapMyMac.entitlements"],
            resources: [
                .copy("Resources/Sounds")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "SlapMyMacTests",
            dependencies: ["SlapMyMac"]
        ),
    ]
)
