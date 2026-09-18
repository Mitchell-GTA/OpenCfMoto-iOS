// swift-tools-version: 5.5
// SPDX-License-Identifier: AGPL-3.0-or-later

import PackageDescription

let package = Package(
    name: "OpenCfMoto",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OpenCfMoto",
            targets: ["OpenCfMoto"]  
        ),
        .executable(
            name: "OpenCfMotoApp",
            targets: ["OpenCfMotoApp"]
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
        .executableTarget(
            name: "OpenCfMotoApp",
            dependencies: ["OpenCfMoto"],
            path: "Sources/OpenCfMotoApp"
        ),
        .testTarget(
            name: "OpenCfMotoTests",
            dependencies: ["OpenCfMoto"],
            path: "Tests/OpenCfMotoTests"
        ),
    ]
)
