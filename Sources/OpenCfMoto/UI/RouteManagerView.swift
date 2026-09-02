// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Route & GPX Manager View

import SwiftUI
import UniformTypeIdentifiers

public struct RouteManagerView: View {
    @ObservedObject public var viewModel: DashHUDViewModel
    @State private var importedTracks: [GpxTrack] = []
    @State private var selectedTrack: GpxTrack?
    @State private var isShowingFilePicker = false
    @State private var destinationQuery = ""

    public init(viewModel: DashHUDViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 1. Search / Set Destination Box
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Navegar a Destino")
                                .font(.headline)
                                .foregroundColor(.white)

                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)

                                TextField("Buscar ciudad, puerto o dirección...", text: $destinationQuery)
                                    .foregroundColor(.white)

                                if !destinationQuery.isEmpty {
                                    Button(action: {
                                        viewModel.streetName = destinationQuery
                                        viewModel.nextManeuver = "En 500m gire a la derecha"
                                        viewModel.distanceToTurn = "500 m"
                                        destinationQuery = ""
                                    }) {
                                        Text("Fijar")
                                            .fontWeight(.bold)
                                            .foregroundColor(.cyan)
                                    }
                                }
                            }
                            .padding(12)
                            .background(Color(red: 0.14, green: 0.16, blue: 0.22))
                            .cornerRadius(12)
                        }
                        .padding()
                        .background(Color(red: 0.11, green: 0.13, blue: 0.17))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // 2. GPX Track Library
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Rutas GPX Guardadas")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Spacer()

                                Button(action: { isShowingFilePicker = true }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus.circle.fill")
                                        Text("Importar GPX")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(.cyan)
                                }
                            }

                            if importedTracks.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "map")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.6))
                                    Text("No hay rutas importadas aún")
                                        .foregroundColor(.gray)
                                        .font(.subheadline)

                                    Button("Cargar Rutas de Demostración") {
                                        loadDemoRoutes()
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.cyan.opacity(0.15))
                                    .foregroundColor(.cyan)
                                    .cornerRadius(20)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 24)
                            } else {
                                ForEach(importedTracks) { track in
                                    TrackCardView(
                                        track: track,
                                        isSelected: selectedTrack?.id == track.id,
                                        onSelect: {
                                            selectedTrack = track
                                            viewModel.streetName = track.name
                                            viewModel.nextManeuver = "Siga el track GPX"
                                            viewModel.distanceToTurn = "\(String(format: "%.1f", track.totalDistanceMeters / 1000.0)) km"
                                        }
                                    )
                                }
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
            .navigationTitle("Rutas y GPX")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.xml, UTType(filenameExtension: "gpx") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first, url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        if let data = try? Data(contentsOf: url),
                           let track = GpxParser.parse(data: data) {
                            importedTracks.append(track)
                        }
                    }
                case .failure(let error):
                    print("Error importing file: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadDemoRoutes() {
        let demo1 = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1">
          <trk>
            <name>Ruta Sierra de Guadarrama</name>
            <trkseg>
              <trkpt lat="40.7589" lon="-4.0046"><ele>1100</ele></trkpt>
              <trkpt lat="40.7720" lon="-3.9850"><ele>1350</ele></trkpt>
              <trkpt lat="40.7950" lon="-3.9620"><ele>1600</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """

        let demo2 = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1">
          <trk>
            <name>Paso de Montaña Transpirenaica</name>
            <trkseg>
              <trkpt lat="42.5063" lon="1.5218"><ele>1020</ele></trkpt>
              <trkpt lat="42.5400" lon="1.5500"><ele>1850</ele></trkpt>
              <trkpt lat="42.5800" lon="1.6000"><ele>2200</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """

        if let t1 = GpxParser.parse(gpxString: demo1) { importedTracks.append(t1) }
        if let t2 = GpxParser.parse(gpxString: demo2) { importedTracks.append(t2) }
    }
}

struct TrackCardView: View {
    let track: GpxTrack
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    Label("\(String(format: "%.1f", track.totalDistanceMeters / 1000.0)) km", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    Label("\(track.waypoints.count) waypoints", systemImage: "mappin.and.ellipse")
                }
                .font(.caption)
                .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onSelect) {
                Text(isSelected ? "Activa" : "Proyectar")
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(isSelected ? Color.green : Color.cyan)
                    .foregroundColor(isSelected ? .white : .black)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(red: 0.15, green: 0.17, blue: 0.23))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.green : Color.clear, lineWidth: 2)
        )
    }
}
