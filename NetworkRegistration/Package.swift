// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NetworkRegistration",
    platforms: [.iOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "NetworkRegistration",
            targets: ["NetworkRegistration"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hmlongco/Factory.git", from: "3.1.0"),
        .package(path: "../NetworkKit")
    ],
    targets: [
        .target(
            name: "NetworkRegistration", dependencies: ["NetworkKit", .product(name: "FactoryKit", package: "Factory")]),

    ]
)
