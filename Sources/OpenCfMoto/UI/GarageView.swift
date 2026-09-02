// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Garage & Bike Profiles View

import SwiftUI

public struct GarageView: View {
    @ObservedObject public var viewModel: DashHUDViewModel

    public init(viewModel: DashHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header Banner
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tu Garaje de Motos")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Text("Selecciona el perfil de tu moto para adaptar la resolución, orientación y controles de la pantalla.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top)

                        // Bike Presets List
                        VStack(spacing: 14) {
                            ForEach(BikeProfile.allPresets) { profile in
                                BikeProfileCard(
                                    profile: profile,
                                    isSelected: viewModel.activeBikeProfile.id == profile.id,
                                    onSelect: {
                                        viewModel.activeBikeProfile = profile
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)

                        // Hardware & Transmission Settings
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Parámetros de Transmisión PXC")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Text("Resolución de Salida:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("\(viewModel.activeBikeProfile.dimensions.width) x \(viewModel.activeBikeProfile.dimensions.height) px")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }

                            HStack {
                                Text("Tasa de Refresco:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("25 FPS")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }

                            HStack {
                                Text("Códec de Compresión:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text("H.264 Baseline (VideoToolbox)")
                                    .fontWeight(.semibold)
                                    .foregroundColor(.cyan)
                            }

                            HStack {
                                Text("Pantalla Táctil:")
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(viewModel.activeBikeProfile.supportsTouch ? "Soportada (Multi-touch)" : "Control por Manillar")
                                    .fontWeight(.semibold)
                                    .foregroundColor(viewModel.activeBikeProfile.supportsTouch ? .green : .orange)
                            }
                        }
                        .padding()
                        .background(Color(red: 0.11, green: 0.13, blue: 0.17))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Garaje")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}

struct BikeProfileCard: View {
    let profile: BikeProfile
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: "motorcycle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(isSelected ? .black : .cyan)
                    .frame(width: 52, height: 52)
                    .background(isSelected ? Color.cyan : Color.cyan.opacity(0.15))
                    .cornerRadius(14)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        Text("\(profile.dimensions.width)x\(profile.dimensions.height)")
                            .font(.caption.bold())
                            .foregroundColor(.cyan)

                        Text("•")
                            .foregroundColor(.gray)

                        Text(profile.dimensions.isPortrait ? "Vertical" : "Horizontal")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(red: 0.13, green: 0.15, blue: 0.20))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
