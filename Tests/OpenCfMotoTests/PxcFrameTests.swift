// SPDX-License-Identifier: AGPL-3.0-or-later

import XCTest
@testable import OpenCfMoto

final class OpenCfMotoTests: XCTestCase {

    func testCmdFrameSerializationAndParsing() throws {
        let originalPayload = "{\"test\":\"hello_moto\"}".data(using: .utf8)!
        let cmd: Int32 = PxcConstants.cmdMdnsRespond
        let frame = PxcCmdFrame(cmd: cmd, payload: originalPayload)

        let serialized = frame.serialize()
        XCTAssertEqual(serialized.count, 16 + originalPayload.count)

        guard let (parsed, consumed) = try PxcCmdFrame.parse(from: serialized) else {
            XCTFail("Failed to parse frame")
            return
        }

        XCTAssertEqual(consumed, serialized.count)
        XCTAssertEqual(parsed.cmd, cmd)
        XCTAssertEqual(parsed.payload, originalPayload)
    }

    func testReqFrameSerializationAndParsing() throws {
        let body = Data([0x01, 0x02, 0x03, 0x04])
        let req = PxcReqFrame(cmdType: PxcConstants.reqRvConfigCapture, token: 1234, body: body)

        let serialized = req.serialize()
        XCTAssertEqual(serialized.count, 8 + body.count)

        guard let (parsed, consumed) = PxcReqFrame.parse(from: serialized) else {
            XCTFail("Failed to parse ReqBase frame")
            return
        }

        XCTAssertEqual(consumed, serialized.count)
        XCTAssertEqual(parsed.cmdType, PxcConstants.reqRvConfigCapture)
        XCTAssertEqual(parsed.token, 1234)
        XCTAssertEqual(parsed.body, body)
    }

    func testQrCodeParsing() {
        let qrUrl = "http://www.carbit.com.cn/downsdk/657/658/_sdk?modelid=37416&sn=peTz&action=9&ssid=CFMOTO-f46457&pwd=59a9cddc94&auth=wpa2-psk&mac=6C:09:4A:0F:6C:F8&name=CFMOTO-f46457"
        let qr = QrData.parse(qrString: qrUrl)

        XCTAssertNotNil(qr)
        XCTAssertEqual(qr?.ssid, "CFMOTO-f46457")
        XCTAssertEqual(qr?.pwd, "59a9cddc94")
        XCTAssertEqual(qr?.modelId, "37416")
    }

    func testGpxParser() {
        let gpxXml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1">
          <trk>
            <name>Ruta Sierra</name>
            <trkseg>
              <trkpt lat="40.4168" lon="-3.7038"><ele>650</ele></trkpt>
              <trkpt lat="40.4170" lon="-3.7040"><ele>655</ele></trkpt>
            </trkseg>
          </trk>
        </gpx>
        """

        let track = GpxParser.parse(gpxString: gpxXml)
        XCTAssertNotNil(track)
        XCTAssertEqual(track?.name, "Ruta Sierra")
        XCTAssertEqual(track?.waypoints.count, 2)
        XCTAssertGreaterThan(track?.totalDistanceMeters ?? 0, 0)
    }
}
