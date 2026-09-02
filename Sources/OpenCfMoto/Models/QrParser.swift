// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - QR Code Parser

import Foundation

public struct QrData: Equatable {
    public let ssid: String
    public let pwd: String
    public let auth: String
    public let mac: String?
    public let name: String?
    public let modelId: String?
    public let action: Int

    public init(ssid: String, pwd: String, auth: String = "wpa2-psk", mac: String? = nil, name: String? = nil, modelId: String? = nil, action: Int = 9) {
        self.ssid = ssid
        self.pwd = pwd
        self.auth = auth
        self.mac = mac
        self.name = name
        self.modelId = modelId
        self.action = action
    }

    /// Parses a MotoPlay / EasyConnect QR URL into structured credentials.
    /// Example URL:
    /// http://www.carbit.com.cn/downsdk/657/658/_sdk?modelid=37416&sn=peTz&action=9&ssid=CFMOTO-f46457&pwd=59a9cddc94&auth=wpa2-psk&mac=6C:09:4A:0F:6C:F8&name=CFMOTO-f46457
    public static func parse(qrString: String) -> QrData? {
        guard let url = URL(string: qrString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }

        var dict = [String: String]()
        for item in queryItems {
            if let value = item.value {
                dict[item.name] = value
            }
        }

        guard let ssid = dict["ssid"], !ssid.isEmpty,
              let pwd = dict["pwd"], !pwd.isEmpty else {
            return nil
        }

        let auth = dict["auth"] ?? "wpa2-psk"
        let mac = dict["mac"]
        let name = dict["name"] ?? ssid
        let modelId = dict["modelid"]
        let action = Int(dict["action"] ?? "9") ?? 9

        return QrData(ssid: ssid, pwd: pwd, auth: auth, mac: mac, name: name, modelId: modelId, action: action)
    }
}
