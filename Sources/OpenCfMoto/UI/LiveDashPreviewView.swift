// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Live Dash Preview Component

import SwiftUI

public struct LiveDashPreviewView: View {
    public let speedKmh: Int
    public let speedLimit: Int?
    public let nextManeuver: String
    public let distanceToTurn: String
    public let streetName: String
    public let heading: Double
    public let isStreaming: Bool
    public let isPortrait: Bool

    public init(
        speedKmh: Int,
        speedLimit: Int? = 90,
        nextManeuver: String = "Siga recto",
        distanceToTurn: String = "3.2 km",
        streetName: String = "Carretera Principal",
        heading: Double = 45.0,
        isStreaming: Bool = false,
        isPortrait: Bool = false
    ) {
        self.speedKmh = speedKmh
        self.speedLimit = speedLimit
        self.nextManeuver = nextManeuver
        self.distanceToTurn = distanceToTurn
        self.streetName = streetName
        self.heading = heading
        self.isStreaming = isStreaming
        self.isPortrait = isPortrait
    }

    public var body: some View {
        ZStack {
            // Background
            Color(red: 0.06, green: 0.07, blue: 0.10)

            VStack(spacing: 12) {
                // 1. Navigation Banner (Turn-by-turn)
                HStack(spacing: 14) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.cyan)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(nextManeuver)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)

                        Text("\(distanceToTurn) • \(streetName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    // Streaming Indicator Dot
                    Circle()
                        .fill(isStreaming ? Color.green : Color.orange)
                        .frame(width: 10, height: 10)
                }
                .padding(12)
                .background(Color(red: 0.12, green: 0.15, blue: 0.22))
                .cornerRadius(14)

                Spacer()

                // 2. Center / Bottom Telemetry (Speed + Limit + Compass)
                HStack(alignment: .bottom) {
                    // Speedometer
                    HStack(alignment: .lastTextBaseline, spacing: 6) {
                        Text("\(speedKmh)")
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        Text("KM/H")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.gray)
                    }

                    // Speed Limit Sign
                    if let limit = speedLimit {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 44, height: 44)
                            Circle()
                                .stroke(Color.red, lineWidth: 3.5)
                                .frame(width: 44, height: 44)
                            Text("\(limit)")
                                .font(.system(size: 16, weight: .black))
                                .foregroundColor(.black)
                        }
                        .padding(.leading, 8)
                    }

                    Spacer()

                    // Compass Heading
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "location.north.fill")
                                .rotationEffect(.degrees(heading))
                                .foregroundColor(.green)
                            Text("\(Int(heading))°")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Text("Rumbo")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(14)
        }
        .aspectRatio(isPortrait ? (800.0 / 951.0) : (800.0 / 384.0), contentMode: .fit)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isStreaming ? Color.cyan.opacity(0.8) : Color.gray.opacity(0.4), lineWidth: 2)
        )
    }
}
