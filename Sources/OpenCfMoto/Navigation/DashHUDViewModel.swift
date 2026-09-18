// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Navigation & HUD Coordinator

import Foundation
import CoreLocation
import Combine

public final class DashHUDViewModel: NSObject, ObservableObject, CLLocationManagerDelegate, PxcServerDelegate {
    @Published public var isConnected = false
    @Published public var isStreaming = false
    @Published public var currentSpeedKmh: Int = 0
    @Published public var currentHeading: Double = 0.0
    @Published public var speedLimit: Int? = 90
    @Published public var nextManeuver: String = "Siga recto"
    @Published public var distanceToTurn: String = "3.2 km"
    @Published public var streetName: String = "Carretera Principal"
    @Published public var connectionStateDescription: String = "Desconectado"
    @Published public var activeBikeProfile: BikeProfile = .cfdl16Landscape

    private let locationManager = CLLocationManager()
    public let pxcServer: PxcServer
    private var renderer: VirtualDisplayRenderer
    private var encoder: VideoToolboxEncoder
    private var renderTimer: Timer?

    public init(bikeProfile: BikeProfile = .cfdl16Landscape) {
        self.activeBikeProfile = bikeProfile
        self.pxcServer = PxcServer()
        self.renderer = VirtualDisplayRenderer(
            width: bikeProfile.dimensions.width,
            height: bikeProfile.dimensions.height
        )
        self.encoder = VideoToolboxEncoder(
            width: Int32(bikeProfile.dimensions.width),
            height: Int32(bikeProfile.dimensions.height),
            fps: 25,
            bitrate: 2_500_000
        )
        super.init()

        self.pxcServer.delegate = self
        setupLocationManager()
    }

    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        #if os(iOS)
        locationManager.pausesLocationUpdatesAutomatically = false
        #endif
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Actions

    public func startNavigationSession(qrUrlString: String? = nil, gatewayIp: String = "192.168.0.1") {
        if let qrStr = qrUrlString, let qr = QrData.parse(qrString: qrStr) {
            print("[DASH-VM] Scanned QR with SSID: \(qr.ssid)")
        }

        encoder.start()
        pxcServer.start(bikeGatewayIp: gatewayIp)
        #if os(iOS)
        if Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes") != nil {
            locationManager.allowsBackgroundLocationUpdates = true
        }
        #endif
        locationManager.startUpdatingLocation()
        #if os(iOS)
        locationManager.startUpdatingHeading()
        #endif

        startRenderLoop()
    }

    public func stopNavigationSession() {
        renderTimer?.invalidate()
        renderTimer = nil
        locationManager.stopUpdatingLocation()
        #if os(iOS)
        locationManager.stopUpdatingHeading()
        locationManager.allowsBackgroundLocationUpdates = false
        #endif
        pxcServer.stop()
        encoder.stop()
        isStreaming = false
        isConnected = false
    }

    // MARK: - Render Loop (25 FPS)

    private func startRenderLoop() {
        renderTimer?.invalidate()
        renderTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 25.0, repeats: true) { [weak self] _ in
            self?.renderCurrentFrame()
        }
    }

    private func renderCurrentFrame() {
        guard let pixelBuffer = renderer.renderHUD(
            speedKmh: currentSpeedKmh,
            speedLimit: speedLimit,
            nextManeuver: nextManeuver,
            distanceToTurn: distanceToTurn,
            streetName: streetName,
            heading: currentHeading
        ) else { return }

        encoder.encode(pixelBuffer: pixelBuffer)
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        // Speed is in m/s, convert to km/h
        let speedMps = max(0, location.speed)
        DispatchQueue.main.async {
            self.currentSpeedKmh = Int(speedMps * 3.6)
        }
    }

    #if os(iOS)
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async {
            self.currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        }
    }
    #endif

    // MARK: - PxcServerDelegate

    public func pxcServer(_ server: PxcServer, didUpdateState state: PxcServer.State) {
        DispatchQueue.main.async {
            switch state {
            case .idle:
                self.isConnected = false
                self.isStreaming = false
                self.connectionStateDescription = "Inactivo"
            case .probing(let ip):
                self.connectionStateDescription = "Sondeando moto en \(ip)..."
            case .listening:
                self.connectionStateDescription = "Esperando conexión de la moto..."
            case .connected(let name):
                self.isConnected = true
                self.connectionStateDescription = "Conectado a \(name)"
            case .streaming:
                self.isStreaming = true
                self.connectionStateDescription = "Transmitiendo HUD a la moto"
            case .error(let msg):
                self.connectionStateDescription = "Error: \(msg)"
            }
        }
    }

    public func pxcServer(_ server: PxcServer, didReceiveTouch action: Int, x: Int, y: Int) {
        print("[TOUCH] MotoPlay Touch: action=\(action) x=\(x) y=\(y)")
    }

    public func pxcServerDidRequestNextFrame(_ server: PxcServer) -> Data? {
        return encoder.pollFrame()
    }
}
