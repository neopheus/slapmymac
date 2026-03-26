// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlapMyMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SlapMyMac",
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
