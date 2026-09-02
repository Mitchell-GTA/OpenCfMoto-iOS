// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Binary Framing (CmdBaseHead & ReqBase)

import Foundation

/// 16-byte CmdBaseHead frame used on the PXC control socket (Port 10922 and Probe on 10930).
/// Layout (Little-Endian):
///   [0..3]   Int32 cmdType
///   [4..7]   Int32 totalLen (= 16 + payload.count)
///   [8..11]  Int32 magic   (= cmdType XOR totalLen)
///   [12..15] Int32 reserved (= 0)
///   [16..]   payload bytes
public struct PxcCmdFrame {
    public let cmd: Int32
    public let payload: Data

    public init(cmd: Int32, payload: Data = Data()) {
        self.cmd = cmd
        self.payload = payload
    }

    public init(cmd: Int32, jsonString: String) {
        self.cmd = cmd
        self.payload = jsonString.data(using: .utf8) ?? Data()
    }

    public var hexCmd: String {
        return String(format: "0x%08X", UInt32(bitPattern: cmd))
    }

    /// Encodes the frame into raw bytes ready for socket transmission
    public func serialize() -> Data {
        var data = Data(capacity: 16 + payload.count)
        let totalLen = Int32(16 + payload.count)
        let magic = cmd ^ totalLen
        let reserved: Int32 = 0

        var cmdLE = cmd.littleEndian
        var totalLenLE = totalLen.littleEndian
        var magicLE = magic.littleEndian
        var reservedLE = reserved.littleEndian

        data.append(UnsafeBufferPointer(start: &cmdLE, count: 1))
        data.append(UnsafeBufferPointer(start: &totalLenLE, count: 1))
        data.append(UnsafeBufferPointer(start: &magicLE, count: 1))
        data.append(UnsafeBufferPointer(start: &reservedLE, count: 1))
        if !payload.isEmpty {
            data.append(payload)
        }
        return data
    }

    /// Deserializes a CmdBaseHead frame from an input buffer.
    /// Returns the parsed frame and the number of consumed bytes, or nil if more bytes are needed.
    public static func parse(from buffer: Data) throws -> (frame: PxcCmdFrame, consumedBytes: Int)? {
        guard buffer.count >= 16 else { return nil }

        let cmd = buffer.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int32.self) }.littleEndian
        let totalLen = buffer.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }.littleEndian
        let magic = buffer.withUnsafeBytes { $0.load(fromByteOffset: 8, as: Int32.self) }.littleEndian

        guard (cmd ^ totalLen) == magic else {
            throw PxcFrameError.invalidMagic(expected: cmd ^ totalLen, actual: magic)
        }

        let payloadLen = Int(totalLen - 16)
        guard payloadLen >= 0 else {
            throw PxcFrameError.invalidLength(totalLen)
        }

        guard buffer.count >= Int(totalLen) else {
            return nil // Incomplete frame, wait for more data
        }

        let payload = buffer.subdata(in: 16..<Int(totalLen))
        return (PxcCmdFrame(cmd: cmd, payload: payload), Int(totalLen))
    }
}

/// 8-byte ReqBase frame used on the media control socket (Port 10921) and media data (Port 10920).
/// Layout (Little-Endian):
///   [0..1] Int16 cmdType
///   [2..3] UInt16 cmdLen (= body.count)
///   [4..7] Int32 token
///   [8..]  body bytes
public struct PxcReqFrame {
    public let cmdType: Int16
    public let token: Int32
    public let body: Data

    public init(cmdType: Int16, token: Int32 = 0, body: Data = Data()) {
        self.cmdType = cmdType
        self.token = token
        self.body = body
    }

    public func serialize() -> Data {
        var data = Data(capacity: 8 + body.count)
        var cmdTypeLE = cmdType.littleEndian
        var cmdLenLE = UInt16(body.count).littleEndian
        var tokenLE = token.littleEndian

        data.append(UnsafeBufferPointer(start: &cmdTypeLE, count: 1))
        data.append(UnsafeBufferPointer(start: &cmdLenLE, count: 1))
        data.append(UnsafeBufferPointer(start: &tokenLE, count: 1))
        if !body.isEmpty {
            data.append(body)
        }
        return data
    }

    public static func parse(from buffer: Data) -> (frame: PxcReqFrame, consumedBytes: Int)? {
        guard buffer.count >= 8 else { return nil }

        let cmdType = buffer.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Int16.self) }.littleEndian
        let cmdLen = Int(buffer.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }.littleEndian)
        let token = buffer.withUnsafeBytes { $0.load(fromByteOffset: 4, as: Int32.self) }.littleEndian

        let totalLen = 8 + cmdLen
        guard buffer.count >= totalLen else {
            return nil // Incomplete frame
        }

        let body = cmdLen > 0 ? buffer.subdata(in: 8..<totalLen) : Data()
        return (PxcReqFrame(cmdType: cmdType, token: token, body: body), totalLen)
    }
}

public enum PxcFrameError: Error, LocalizedError {
    case invalidMagic(expected: Int32, actual: Int32)
    case invalidLength(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidMagic(let expected, let actual):
            return "PXC Frame Magic check failed! Expected \(String(format: "0x%08X", expected)), got \(String(format: "0x%08X", actual))"
        case .invalidLength(let len):
            return "PXC Frame invalid total length: \(len)"
        }
    }
}
