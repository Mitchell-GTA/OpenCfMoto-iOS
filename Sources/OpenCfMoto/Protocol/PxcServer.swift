// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - PXC Multi-Port TCP Server

import Foundation
import Network

public protocol PxcServerDelegate: AnyObject {
    func pxcServer(_ server: PxcServer, didUpdateState state: PxcServer.State)
    func pxcServer(_ server: PxcServer, didReceiveTouch action: Int, x: Int, y: Int)
    func pxcServerDidRequestNextFrame(_ server: PxcServer) -> Data?
}

public final class PxcServer {
    public enum State: Equatable {
        case idle
        case probing(String)
        case listening
        case connected(bikeName: String)
        case streaming
        case error(String)
    }

    public typealias Logger = (String) -> Void
    private let log: Logger

    public weak var delegate: PxcServerDelegate?
    public let handshake: PxcHandshake

    private var listeners = [NWListener]()
    private var activeConnections = [NWConnection]()
    private var ctrlChannels = [NWConnection]()
    private var heartbeatTimer: Timer?

    private var isRunning = false
    public private(set) var state: State = .idle {
        didSet {
            delegate?.pxcServer(self, didUpdateState: state)
        }
    }

    public private(set) var negotiatedWidth: Int = 800
    public private(set) var negotiatedHeight: Int = 384
    public private(set) var framesSent: Int = 0

    public init(logger: @escaping Logger = { print($0) }) {
        self.log = logger
        self.handshake = PxcHandshake(logger: logger)
    }

    // MARK: - Lifecycle

    public func start(bikeGatewayIp: String = "192.168.0.1") {
        guard !isRunning else { return }
        isRunning = true
        framesSent = 0

        log("[PXC-SERVER] Starting TCP listeners on ports 10920, 10921, 10922...")
        startListeners()

        // Probe bike to announce our IP so the bike connects back
        probeBike(gatewayIp: bikeGatewayIp)
    }

    public func stop() {
        isRunning = false
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil

        for conn in activeConnections {
            conn.cancel()
        }
        activeConnections.removeAll()
        ctrlChannels.removeAll()

        for listener in listeners {
            listener.cancel()
        }
        listeners.removeAll()

        state = .idle
        log("[PXC-SERVER] Stopped.")
    }

    // MARK: - TCP Listeners (Ports 10920, 10921, 10922)

    private func startListeners() {
        let ports: [UInt16] = [
            PxcConstants.portPxcCtrl,    // 10922
            PxcConstants.portMediaCtrl,  // 10921
            PxcConstants.portMediaData   // 10920
        ]

        for port in ports {
            do {
                guard let nwPort = NWEndpoint.Port(rawValue: port) else { continue }
                let params = NWParameters.tcp
                params.allowLocalEndpointReuse = true
                let listener = try NWListener(using: params, on: nwPort)

                listener.newConnectionHandler = { [weak self] connection in
                    self?.handleNewConnection(connection, onPort: port)
                }

                listener.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        self?.log("[:\(port)] Server listener READY")
                    case .failed(let err):
                        self?.log("[:\(port)] Listener failed: \(err)")
                    default:
                        break
                    }
                }

                listener.start(queue: .global(qos: .userInteractive))
                listeners.append(listener)
            } catch {
                log("[:\(port)] Failed to create listener: \(error)")
            }
        }

        state = .listening
    }

    private func handleNewConnection(_ connection: NWConnection, onPort port: UInt16) {
        log("[:\(port)] <<< Inbound bike connection from \(connection.endpoint)")
        activeConnections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.startReceiveLoop(connection, port: port)
            case .cancelled, .failed:
                self?.activeConnections.removeAll(where: { $0 === connection })
                self?.ctrlChannels.removeAll(where: { $0 === connection })
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInteractive))
    }

    // MARK: - Receive Loops

    private func startReceiveLoop(_ connection: NWConnection, port: UInt16) {
        var receiveBuffer = Data()

        func readNext() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
                guard let self = self, self.isRunning else { return }

                if let data = data, !data.isEmpty {
                    receiveBuffer.append(data)
                    self.processBuffer(&receiveBuffer, port: port, connection: connection)
                }

                if isComplete || error != nil {
                    self.log("[:\(port)] Socket closed or error: \(String(describing: error))")
                    return
                }

                readNext()
            }
        }

        readNext()
    }

    private func processBuffer(_ buffer: inout Data, port: UInt16, connection: NWConnection) {
        if port == PxcConstants.portPxcCtrl {
            // Port 10922: 16-byte CmdBaseHead framing
            while buffer.count >= 16 {
                do {
                    guard let (frame, consumed) = try PxcCmdFrame.parse(from: buffer) else { break }
                    buffer.removeFirst(consumed)

                    let replies = handshake.handleControlFrame(tag: ":10922", frame: frame)
                    for reply in replies {
                        sendCmdFrame(reply, on: connection)
                    }

                    if frame.cmd == PxcConstants.cmdChannelCarCtrl || frame.cmd == PxcConstants.cmdChannelCarData {
                        ctrlChannels.append(connection)
                        startHeartbeatTimerIfNeeded()
                    }

                    if frame.cmd == PxcConstants.cmdClientInfo {
                        state = .connected(bikeName: handshake.carHuName ?? "MotoPlay Dash")
                    }
                } catch {
                    log("[:10922] Frame parse error: \(error)")
                    buffer.removeAll()
                    break
                }
            }
        } else {
            // Ports 10921 & 10920: 8-byte ReqBase framing
            while buffer.count >= 8 {
                guard let (req, consumed) = PxcReqFrame.parse(from: buffer) else { break }
                buffer.removeFirst(consumed)
                handleMediaRequest(req, port: port, connection: connection)
            }
        }
    }

    // MARK: - Media Request Handling (Ports 10921 / 10920)

    private func handleMediaRequest(_ req: PxcReqFrame, port: UInt16, connection: NWConnection) {
        let tag = ":\(port)"
        switch req.cmdType {
        case PxcConstants.reqRvConfigCapture:
            // Parse requested dims
            var w = 800
            var h = 384
            if req.body.count >= 4 {
                w = Int(req.body.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }.littleEndian)
                h = Int(req.body.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }.littleEndian)
            }
            log("[\(tag)] REQ_CONFIG_CAPTURE bike requested: \(w)x\(h)")

            // Align to 16 pixels
            negotiatedWidth = (w > 0) ? (w & ~15) : 800
            negotiatedHeight = (h > 0) ? (h & ~15) : 384

            // Reply RLY_CONFIG_CAPTURE (17): encoder(i32=2) | w(s16) | h(s16) | ext(byte=0)
            var rlyBody = Data(capacity: 9)
            var enc = Int32(2).littleEndian
            var nw = Int16(negotiatedWidth).littleEndian
            var nh = Int16(negotiatedHeight).littleEndian
            var ext: UInt8 = 0

            withUnsafeBytes(of: &enc) { rlyBody.append(contentsOf: $0) }
            withUnsafeBytes(of: &nw) { rlyBody.append(contentsOf: $0) }
            withUnsafeBytes(of: &nh) { rlyBody.append(contentsOf: $0) }
            rlyBody.append(&ext, count: 1)

            sendReqFrame(PxcReqFrame(cmdType: PxcConstants.rlyRvConfigCapture, token: req.token, body: rlyBody), on: connection)
            log("[\(tag)] -> RLY_CONFIG_CAPTURE(17) negotiated \(negotiatedWidth)x\(negotiatedHeight)")

        case PxcConstants.reqGetVersion:
            var vBody = Data(capacity: 8)
            var v = Int32(3).littleEndian
            var sub = Int32(1).littleEndian
            withUnsafeBytes(of: &v) { vBody.append(contentsOf: $0) }
            withUnsafeBytes(of: &sub) { vBody.append(contentsOf: $0) }
            sendReqFrame(PxcReqFrame(cmdType: PxcConstants.rlyGetVersion, token: req.token, body: vBody), on: connection)

        case PxcConstants.reqHeartbeat:
            sendReqFrame(PxcReqFrame(cmdType: PxcConstants.rlyHeartbeat, token: req.token), on: connection)

        case PxcConstants.reqConfigCaptureExtend:
            let okJson = "{\"state\":0}".data(using: .utf8) ?? Data()
            sendReqFrame(PxcReqFrame(cmdType: PxcConstants.rlyConfigCaptureExtend, token: req.token, body: okJson), on: connection)

        case PxcConstants.reqRvDataStart:
            log("[\(tag)] REQ_RV_DATA_START -> Starting stream!")
            sendReqFrame(PxcReqFrame(cmdType: PxcConstants.rlyRvDataStart, token: req.token), on: connection)
            state = .streaming

        case PxcConstants.reqRvDataNext:
            // Bike pulls the next raw H.264 frame on port 10920!
            if let frameData = delegate?.pxcServerDidRequestNextFrame(self) {
                sendRawH264Frame(frameData, on: connection)
                framesSent += 1
                if framesSent == 1 {
                    log("[\(tag)] *** First H.264 frame successfully delivered to dash! ***")
                }
            }

        case PxcConstants.reqTouch:
            if req.body.count >= 8 {
                let action = Int(req.body.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }.littleEndian)
                let x = Int(req.body.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }.littleEndian)
                let y = Int(req.body.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }.littleEndian)
                delegate?.pxcServer(self, didReceiveTouch: action, x: x, y: y)
            }

        default:
            break
        }
    }

    // MARK: - Sending Helpers

    private func sendCmdFrame(_ frame: PxcCmdFrame, on connection: NWConnection) {
        let raw = frame.serialize()
        connection.send(content: raw, completion: .contentProcessed { _ in })
    }

    private func sendReqFrame(_ frame: PxcReqFrame, on connection: NWConnection) {
        let raw = frame.serialize()
        connection.send(content: raw, completion: .contentProcessed { _ in })
    }

    /// Sends a raw H.264 access unit on the data socket: [size int32 LE][frame_bytes]
    private func sendRawH264Frame(_ frame: Data, on connection: NWConnection) {
        var sizeData = Data(capacity: 4)
        var sizeLE = Int32(frame.count).littleEndian
        withUnsafeBytes(of: &sizeLE) { sizeData.append(contentsOf: $0) }

        var payload = Data(capacity: 4 + frame.count)
        payload.append(sizeData)
        payload.append(frame)

        connection.send(content: payload, completion: .contentProcessed { _ in })
    }

    // MARK: - Outbound Probe (Port 10930)

    private func probeBike(gatewayIp: String) {
        guard let host = NWEndpoint.Host(gatewayIp) as NWEndpoint.Host?,
              let port = NWEndpoint.Port(rawValue: PxcConstants.portBikeProbe) else { return }

        state = .probing(gatewayIp)
        log("[PROBE] Sending ECP_PXC_MDNS_RESPOND (0x70000010) to \(gatewayIp):10930...")

        let connection = NWConnection(host: host, port: port, using: .tcp)
        let jsonProbe = "{\"phoneType\":\"iOS\",\"packageName\":\"dev.zanderp.opencfmoto\"}"
        let probeFrame = PxcCmdFrame(cmd: PxcConstants.cmdMdnsRespond, jsonString: jsonProbe)

        connection.stateUpdateHandler = { [weak self] connState in
            guard let self = self else { return }
            switch connState {
            case .ready:
                connection.send(content: probeFrame.serialize(), completion: .contentProcessed { _ in
                    // Read probe ack
                    connection.receive(minimumIncompleteLength: 16, maximumLength: 1024) { data, _, _, _ in
                        if let data = data,
                           let (ackFrame, _) = try? PxcCmdFrame.parse(from: data) {
                            let body = String(data: ackFrame.payload, encoding: .utf8) ?? ""
                            self.log("[PROBE] <- Bike Ack cmd=\(ackFrame.hexCmd) \(body)")
                            if body.contains("true") {
                                self.log("[PROBE] *** Probe Accepted! Waiting for bike to connect back... ***")
                            }
                        }
                        connection.cancel()
                    }
                })
            case .failed(let err):
                self.log("[PROBE] Probe failed: \(err)")
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInteractive))
    }

    // MARK: - Proactive Heartbeats

    private func startHeartbeatTimerIfNeeded() {
        guard heartbeatTimer == nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                self?.sendHeartbeats()
            }
        }
    }

    private func sendHeartbeats() {
        let hb = PxcCmdFrame(cmd: PxcConstants.cmdHeartbeat)
        for ch in ctrlChannels {
            sendCmdFrame(hb, on: ch)
        }
    }
}
