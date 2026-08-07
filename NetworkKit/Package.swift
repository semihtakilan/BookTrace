// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NetworkKit",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        .library(name: "NetworkKit", targets: ["NetworkKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.1.0"),
    ],
    targets: [
        .target(
            name: "NetworkKit",
            dependencies: [
                .product(name: "FactoryKit", package: "Factory"),
            ]
        ),
        .testTarget(
            name: "NetworkKitTests",
            dependencies: ["NetworkKit"]
        ),
    ]
)
