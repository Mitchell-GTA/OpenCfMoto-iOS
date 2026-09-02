// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Main Dashboard View

import SwiftUI

public struct MainDashboardView: View {
    @ObservedObject public var viewModel: DashHUDViewModel
    @State private var isShowingScanner = false
    @State private var isMockMode = false

    public init(viewModel: DashHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Connection Status Banner
                        ConnectionStatusCard(
                            stateText: viewModel.connectionStateDescription,
                            isConnected: viewModel.isConnected,
                            isStreaming: viewModel.isStreaming,
                            bikeName: viewModel.activeBikeProfile.name
                        )
                        .padding(.horizontal)

                        // 2. Live Motorcycle HUD Preview
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Vista en Pantalla de la Moto")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Spacer()
                                if viewModel.isStreaming {
                                    Label("En Vivo", systemImage: "antenna.radiowaves.left.and.right")
                                        .font(.caption.bold())
                                        .foregroundColor(.green)
                                }
                            }

                            LiveDashPreviewView(
                                speedKmh: viewModel.currentSpeedKmh,
                                speedLimit: viewModel.speedLimit,
                                nextManeuver: viewModel.nextManeuver,
                                distanceToTurn: viewModel.distanceToTurn,
                                streetName: viewModel.streetName,
                                heading: viewModel.currentHeading,
                                isStreaming: viewModel.isStreaming,
                                isPortrait: viewModel.activeBikeProfile.dimensions.isPortrait
                            )
                        }
                        .padding()
                        .background(Color(red: 0.11, green: 0.13, blue: 0.17))
                        .cornerRadius(18)
                        .padding(.horizontal)

                        // 3. Primary Control Buttons
                        VStack(spacing: 12) {
                            if !viewModel.isStreaming && !viewModel.isConnected {
                                // Scan QR Button
                                Button(action: { isShowingScanner = true }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "qrcode.viewfinder")
                                            .font(.title3)
                                        Text("Escanear QR de la Moto")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.cyan)
                                    .foregroundColor(.black)
                                    .cornerRadius(14)
                                }

                                // Connect to Mock Emulator Button (for testing)
                                Button(action: {
                                    isMockMode = true
                                    viewModel.startNavigationSession(gatewayIp: "127.0.0.1")
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "laptopcomputer.and.iphone")
                                        Text("Probar con Emulador Mock (PC)")
                                            .fontWeight(.semibold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color(red: 0.16, green: 0.19, blue: 0.26))
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                }
                            } else {
                                // Stop Projection Button
                                Button(action: { viewModel.stopNavigationSession() }) {
                                    HStack(spacing: 10) {
                                        Image(systemName: "stop.circle.fill")
                                            .font(.title3)
                                        Text("Detener Transmisión")
                                            .fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(14)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // 4. Quick Simulator / Demo Controls
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Simulador de Telemetría (Demo)")
                                .font(.caption.bold())
                                .foregroundColor(.gray)

                            HStack(spacing: 12) {
                                Button("Velocidad +10") {
                                    viewModel.currentSpeedKmh += 10
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.cyan)
                                .cornerRadius(8)

                                Button("Velocidad -10") {
                                    viewModel.currentSpeedKmh = max(0, viewModel.currentSpeedKmh - 10)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.cyan)
                                .cornerRadius(8)

                                Button("Giro 90°") {
                                    viewModel.currentHeading = (viewModel.currentHeading + 90).truncatingRemainder(dividingBy: 360)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.cyan)
                                .cornerRadius(8)
                            }
                        }
                        .padding()
                        .background(Color(red: 0.11, green: 0.13, blue: 0.17))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("OpenCfMoto")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $isShowingScanner) {
                QRScannerView { qrData in
                    viewModel.startNavigationSession(qrUrlString: nil, gatewayIp: "192.168.0.1")
                }
            }
        }
    }
}

struct ConnectionStatusCard: View {
    let stateText: String
    let isConnected: Bool
    let isStreaming: Bool
    let bikeName: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isStreaming ? Color.green.opacity(0.2) : (isConnected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2)))
                    .frame(width: 50, height: 50)

                Image(systemName: isStreaming ? "wifi.circle.fill" : "antenna.radiowaves.left.and.right")
                    .font(.system(size: 26))
                    .foregroundColor(isStreaming ? .green : (isConnected ? .cyan : .gray))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(stateText)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(bikeName)
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
        .padding()
        .background(Color(red: 0.13, green: 0.15, blue: 0.20))
        .cornerRadius(16)
    }
}
