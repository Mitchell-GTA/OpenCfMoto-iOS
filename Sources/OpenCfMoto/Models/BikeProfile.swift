// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Bike Profile Models

import Foundation

public struct BikeDimensions: Codable, Equatable {
    public let width: Int
    public let height: Int

    public var isPortrait: Bool {
        return height > width
    }

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

public struct BikeProfile: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let dimensions: BikeDimensions
    public let supportsTouch: Bool
    public let modelKeywords: [String]

    public init(id: String, name: String, dimensions: BikeDimensions, supportsTouch: Bool, modelKeywords: [String]) {
        self.id = id
        self.name = name
        self.dimensions = dimensions
        self.supportsTouch = supportsTouch
        self.modelKeywords = modelKeywords
    }

    // Common Bike Presets
    public static let cfdl16Landscape = BikeProfile(
        id: "cfdl16",
        name: "CFMoto 675SR / 450SR / 800NK Standard (Landscape)",
        dimensions: BikeDimensions(width: 800, height: 384),
        supportsTouch: false,
        modelKeywords: ["675", "450sr", "800nk", "cfdl16"]
    )

    public static let cfdl26Portrait = BikeProfile(
        id: "cfdl26",
        name: "CFMoto 1000 MT-X / 800NK Advanced (Portrait Touch)",
        dimensions: BikeDimensions(width: 800, height: 951),
        supportsTouch: true,
        modelKeywords: ["1000mt", "mt-x", "cfdl26", "advanced"]
    )

    public static let mt800Explore = BikeProfile(
        id: "mt800",
        name: "CFMoto 800MT Explore / Ibex 800 (Wide Touch)",
        dimensions: BikeDimensions(width: 1280, height: 576),
        supportsTouch: true,
        modelKeywords: ["800mt", "ibex", "explore"]
    )

    public static let vogeDs900 = BikeProfile(
        id: "voge900",
        name: "Voge DS900X / DS800 Rally",
        dimensions: BikeDimensions(width: 800, height: 480),
        supportsTouch: true,
        modelKeywords: ["voge", "ds900", "ds800"]
    )

    public static let allPresets: [BikeProfile] = [
        cfdl16Landscape,
        cfdl26Portrait,
        mt800Explore,
        vogeDs900
    ]

    public static func match(modelName: String) -> BikeProfile {
        let lower = modelName.lowercased()
        for preset in allPresets {
            for kw in preset.modelKeywords {
                if lower.contains(kw) {
                    return preset
                }
            }
        }
        return cfdl16Landscape // Default fallback
    }
}
