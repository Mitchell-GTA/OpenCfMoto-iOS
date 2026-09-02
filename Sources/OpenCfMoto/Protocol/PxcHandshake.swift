// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - PXC Handshake Manager

import Foundation
import Security
import CryptoKit
#if canImport(UIKit)
import UIKit
#endif

public final class PxcHandshake {
    public typealias Logger = (String) -> Void
    private let log: Logger

    public let phoneUuid = UUID().uuidString
    public private(set) var carHuid: String?
    public private(set) var carHuName: String?
    public private(set) var currentProfile: BikeProfile = .cfdl16Landscape

    // RSA Key generation for HUID signing
    private var rsaPrivateKey: SecKey?
    private var rsaPublicKeyBase64: String = ""

    public var onChannelSelected: ((String) -> Void)?
    public var onDimensionsNegotiated: ((Int, Int) -> Void)?

    public init(logger: @escaping Logger = { print($0) }) {
        self.log = logger
        generateRsaKeyPair()
    }

    private func generateRsaKeyPair() {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: 1024,
            kSecAttrIsPermanent as String: false
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            log("[AUTH] Failed to generate RSA key: \(String(describing: error))")
            return
        }
        self.rsaPrivateKey = privateKey

        if let publicKey = SecKeyCopyPublicKey(privateKey),
           let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? {
            self.rsaPublicKeyBase64 = keyData.base64EncodedString()
        }
    }

    private func signHuid(_ huid: String) -> String {
        guard let privateKey = rsaPrivateKey,
              let data = huid.data(using: .utf8) else { return "" }

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureDigestPKCS1v15SHA256,
            (data as CFData),
            &error
        ) as Data? else {
            // Fallback to SHA1 if SHA256 fails
            if let sig1 = SecKeyCreateSignature(privateKey, .rsaSignatureDigestPKCS1v15SHA1, (data as CFData), &error) as Data? {
                return sig1.base64EncodedString()
            }
            return ""
        }
        return signature.base64EncodedString()
    }

    /// Handles an incoming CmdBaseHead frame on port 10922 or 10930
    public func handleControlFrame(tag: String, frame: PxcCmdFrame) -> [PxcCmdFrame] {
        var replies = [PxcCmdFrame]()

        switch frame.cmd {
        case PxcConstants.cmdChannelCarCtrl:
            log("[\(tag)] Bike selected CAR_CTRL (0x10000) -> Ack 0x10001")
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdChannelCarCtrl + 1))
            onChannelSelected?("CAR_CTRL")

        case PxcConstants.cmdChannelCarData:
            log("[\(tag)] Bike selected CAR_DATA (0x20000) -> Ack 0x20001")
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdChannelCarData + 1))
            onChannelSelected?("CAR_DATA")

        case PxcConstants.cmdClientInfo:
            if let jsonString = String(data: frame.payload, encoding: .utf8) {
                log("[\(tag)] *** CLIENT_INFO received *** \(jsonString)")
                handleClientInfo(jsonString: jsonString)
                let replyPayload = buildClientInfoReply()
                replies.append(PxcCmdFrame(cmd: PxcConstants.cmdClientInfoReply, jsonString: replyPayload))
            }

        case PxcConstants.cmdQuerySpeed:
            log("[\(tag)] QUERY_SPEED -> Ack 0x10691")
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdQuerySpeedReply))

        case PxcConstants.cmdCheckSn:
            log("[\(tag)] CHECK_SN received -> Ack 0x103e1 and send CHECK_SN_RESULT")
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdCheckSnAck))

            var sn = ""
            if let json = try? JSONSerialization.jsonObject(with: frame.payload) as? [String: Any],
               let extractedSn = json["sn"] as? String {
                sn = extractedSn
            }
            let resultDict: [String: Any] = [
                "isOk": true,
                "errCode": 0,
                "errMsg": "",
                "id": sn,
                "client_set": "easy_conn"
            ]
            if let resultData = try? JSONSerialization.data(withJSONObject: resultDict),
               let resultStr = String(data: resultData, encoding: .utf8) {
                replies.append(PxcCmdFrame(cmd: PxcConstants.cmdCheckSnResult, jsonString: resultStr))
            }

        case PxcConstants.cmdHeartbeat:
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdHeartbeatAck))

        case PxcConstants.cmdHuTimeSync:
            // Reply with formatted current time string
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS000000"
            let timeStr = formatter.string(from: Date())
            log("[\(tag)] HU_TIME_SYNC -> Syncing dash clock to: \(timeStr)")
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdHuTimeSyncAck, jsonString: timeStr))

        case PxcConstants.cmdHuQueryTime:
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdHuQueryTimeAck))

        case PxcConstants.cmdLogReport:
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdLogReportAck))

        case PxcConstants.cmdSockServerInfo:
            replies.append(PxcCmdFrame(cmd: PxcConstants.cmdSockServerInfoAck))

        default:
            log("[\(tag)] Unhandled cmd=\(frame.hexCmd) len=\(frame.payload.count)")
        }

        return replies
    }

    private func handleClientInfo(jsonString: String) {
        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        self.carHuid = json["HUID"] as? String ?? json["huid"] as? String
        self.carHuName = json["HUName"] as? String

        if let huName = self.carHuName {
            self.currentProfile = BikeProfile.match(modelName: huName)
            log("[HANDSHAKE] Selected profile: \(currentProfile.name) (\(currentProfile.dimensions.width)x\(currentProfile.dimensions.height))")
        }
    }

    private func buildClientInfoReply() -> String {
        let signedHuid = signHuid(carHuid ?? "UNKNOWN_HUID")

        #if canImport(UIKit)
        let osVersion = UIDevice.current.systemVersion
        #else
        let osVersion = "18.0"
        #endif

        let replyDict: [String: Any] = [
            "pxcVersion": "1.0.2",
            "phoneUUID": phoneUuid,
            "phoneBrand": "Apple",
            "phoneModel": "iPhone",
            "phoneOsVersion": osVersion,
            "phoneOs": "iOS",
            "package": "com.cfmoto.cfmotointernational",
            "versionCode": 126,
            "token": 0,
            "pubkey": rsaPublicKeyBase64,
            "encryptedHUID": signedHuid,
            "bluetoothName": "OpenCfMoto-iOS",
            "supportH264IFrame": true,
            "supportFunction": 0,
            "appVersionFingerPrint": "126"
        ]

        if let data = try? JSONSerialization.data(withJSONObject: replyDict),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "{}"
    }
}
