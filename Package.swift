// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.
import PackageDescription

let package = Package(
    name: "Backtrace",
    platforms: [
        .iOS(.v10),
        .macOS(.v10_11),
        .tvOS(.v11)
    ],
    products: [
        .library(name: "Backtrace", targets: ["Backtrace"]),
    ],
    dependencies: [
        .package(url: "https://github.com/microsoft/plcrashreporter.git", from: "1.11.0"),
        .package(url: "https://github.com/Quick/Nimble.git", from: "10.0.0"),
        .package(url: "https://github.com/Quick/Quick.git", from: "5.0.1")
    ],
    targets: [
        .target(
            name: "Backtrace",
            dependencies: [
            .product(name: "CrashReporter", package: "plcrashreporter")
            ],
            path: "Sources"
        ),
        .testTarget(
            name: "Backtrace-Tests",
            dependencies: ["Backtrace", "Quick", "Nimble"],
            path: "Tests",
            resources: [
                    .process("Resources")
                ]
        ),
    ]
)
