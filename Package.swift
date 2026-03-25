// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SlapMyMac",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "SlapMyMac",
            exclude: ["Resources/Info.plist"],
            resources: [
                .copy("Resources/Sounds")
            ],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .testTarget(
            name: "SlapMyMacTests",
            dependencies: ["SlapMyMac"]
        ),
    ]
)
