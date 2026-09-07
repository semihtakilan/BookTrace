// swift-tools-version: 6.2
//
//  Package.swift
//  BookTraceShared
//
//  Created by Semih TAKILAN on 07.09.2026.
//

import PackageDescription

let package = Package(
    name: "BookTraceShared",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "BookTraceShared", targets: ["BookTraceShared"])],
    dependencies: [.package(path: "../Models")],
    targets: [.target(name: "BookTraceShared", dependencies: ["Models"])]
)
