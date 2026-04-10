// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypeFree",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "TypeFree", targets: ["TypeFree"]),
    ],
    targets: [
        .executableTarget(
            name: "TypeFree",
            path: "Sources/TypeFree",
            linkerSettings: [
                .linkedFramework("Cocoa"),
                .linkedFramework("Carbon"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("Speech"),
            ]
        ),
        .testTarget(
            name: "TypeFreeTests",
            dependencies: ["TypeFree"],
            path: "Tests/TypeFreeTests"
        )
    ]
)
