// swift-tools-version: 5.9
// SPDX-License-Identifier: AGPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "OpenCfMoto",
    platforms: [
        .iOS(.v15),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "OpenCfMoto",
            targets: ["OpenCfMoto"]  
        ),
    ],
    dependencies: [
        // MapLibre or Mapbox can be added here as dependencies when bundling full vector tiles
    ],
    targets: [
        .target(
            name: "OpenCfMoto",
            dependencies: [],
            path: "Sources/OpenCfMoto"
        ),
        .testTarget(
            name: "OpenCfMotoTests",
            dependencies: ["OpenCfMoto"],
            path: "Tests/OpenCfMotoTests"
        ),
    ]
)
