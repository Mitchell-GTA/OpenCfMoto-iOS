// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - QR Scanner View

import SwiftUI
import AVFoundation
#if canImport(NetworkExtension)
import NetworkExtension
#endif

public struct QRScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    public var onCodeScanned: (QrData) -> Void

    @State private var scannedCode: String = ""
    @State private var manualInput: String = ""
    @State private var parsedData: QrData?
    @State private var isConnectingWifi = false
    @State private var statusMessage = "Apunta la cámara al código QR en la pantalla de la moto (MotoPlay / EasyConnect)"

    public init(onCodeScanned: @escaping (QrData) -> Void) {
        self.onCodeScanned = onCodeScanned
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.09, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 20) {
                    // Camera / Scanner View
                    ZStack {
                        #if os(iOS) && !targetEnvironment(simulator)
                        CameraPreview(scannedCode: $scannedCode)
                            .frame(maxWidth: .infinity, maxHeight: 320)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.cyan, lineWidth: 3)
                            )
                        #else
                        VStack(spacing: 12) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            Text("Simulador o macOS (Cámara no disponible)")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .cornerRadius(20)
                        #endif
                    }
                    .padding(.horizontal)

                    // Scanned Info Card
                    if let data = parsedData {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.green)
                                Text("Moto Identificada")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }

                            Divider().background(Color.gray.opacity(0.3))

                            HStack {
                                Text("SSID Wi-Fi:").foregroundColor(.gray)
                                Spacer()
                                Text(data.ssid).fontWeight(.semibold).foregroundColor(.white)
                            }

                            HStack {
                                Text("Contraseña:").foregroundColor(.gray)
                                Spacer()
                                Text(data.pwd).fontWeight(.semibold).foregroundColor(.white)
                            }

                            if let model = data.modelId {
                                HStack {
                                    Text("Modelo ID:").foregroundColor(.gray)
                                    Spacer()
                                    Text(model).foregroundColor(.cyan)
                                }
                            }

                            Button(action: {
                                connectAndFinish(data: data)
                            }) {
                                HStack {
                                    if isConnectingWifi {
                                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .black))
                                    } else {
                                        Image(systemName: "wifi")
                                    }
                                    Text(isConnectingWifi ? "Conectando al Wi-Fi..." : "Conectar a la Moto")
                                }
                                .font(.headline)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.cyan)
                                .cornerRadius(12)
                            }
                            .padding(.top, 6)
                        }
                        .padding()
                        .background(Color(red: 0.14, green: 0.16, blue: 0.22))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    } else {
                        // Manual / Test Input for Simulator or testing
                        VStack(alignment: .leading, spacing: 10) {
                            Text("O introduce URL del QR manualmente:")
                                .font(.caption)
                                .foregroundColor(.gray)

                            HStack {
                                TextField("http://www.carbit.com.cn/...", text: $manualInput)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .padding(10)
                                    .background(Color(red: 0.15, green: 0.17, blue: 0.23))
                                    .cornerRadius(8)
                                    .foregroundColor(.white)

                                Button("Probar") {
                                    handleQrString(manualInput)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }

                            Button("Cargar QR de Prueba (CFMoto 675SR)") {
                                let testQr = "http://www.carbit.com.cn/downsdk/657/658/_sdk?modelid=37416&sn=peTz&action=9&ssid=CFMOTO-f46457&pwd=59a9cddc94&auth=wpa2-psk&mac=6C:09:4A:0F:6C:F8&name=CFMOTO-675SR"
                                manualInput = testQr
                                handleQrString(testQr)
                            }
                            .font(.caption)
                            .foregroundColor(.cyan)
                        }
                        .padding()
                        .background(Color(red: 0.12, green: 0.14, blue: 0.18))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }

                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Escanear Moto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancelar") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .onChange(of: scannedCode) { newCode in
                handleQrString(newCode)
            }
        }
    }

    private func handleQrString(_ str: String) {
        if let data = QrData.parse(qrString: str) {
            self.parsedData = data
        }
    }

    private func connectAndFinish(data: QrData) {
        isConnectingWifi = true

        #if os(iOS) && canImport(NetworkExtension)
        let hotspotConfig = NEHotspotConfiguration(ssid: data.ssid, passphrase: data.pwd, isWEP: false)
        hotspotConfig.joinOnce = false

        NEHotspotConfigurationManager.shared.apply(hotspotConfig) { error in
            DispatchQueue.main.async {
                self.isConnectingWifi = false
                if let error = error {
                    print("[WIFI] Connection error: \(error.localizedDescription)")
                }
                self.onCodeScanned(data)
                self.presentationMode.wrappedValue.dismiss()
            }
        }
        #else
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isConnectingWifi = false
            self.onCodeScanned(data)
            self.presentationMode.wrappedValue.dismiss()
        }
        #endif
    }
}

#if os(iOS) && !targetEnvironment(simulator)
struct CameraPreview: UIViewControllerRepresentable {
    @Binding var scannedCode: String

    func makeUIViewController(context: Context) -> ScannerViewController {
        let vc = ScannerViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(scannedCode: $scannedCode)
    }

    class Coordinator: NSObject, ScannerViewControllerDelegate {
        @Binding var scannedCode: String

        init(scannedCode: Binding<String>) {
            _scannedCode = scannedCode
        }

        func didFindCode(_ code: String) {
            scannedCode = code
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func didFindCode(_ code: String)
}

class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: ScannerViewControllerDelegate?
    private var captureSession: AVCaptureSession?

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return }

        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [.qr]
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.layer.bounds
        view.layer.addSublayer(previewLayer)

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        self.captureSession = session
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
           let stringValue = metadataObject.stringValue {
            delegate?.didFindCode(stringValue)
        }
    }
}
#endif
