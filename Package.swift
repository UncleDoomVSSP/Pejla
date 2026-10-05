// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pejla",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Pejla", targets: ["Pejla"]),
        .library(name: "PejlaCore", targets: ["PejlaCore"]),
    ],
    targets: [
        .target(
            name: "PejlaCore",
            path: "Sources/PejlaCore"
        ),
        .executableTarget(
            name: "Pejla",
            dependencies: ["PejlaCore"],
            path: "Sources/Pejla"
        ),
        .testTarget(
            name: "PejlaCoreTests",
            dependencies: ["PejlaCore"],
            path: "Tests/PejlaCoreTests"
        ),
    ]
)
