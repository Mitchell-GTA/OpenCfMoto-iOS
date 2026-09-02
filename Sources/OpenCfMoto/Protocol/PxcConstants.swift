// SPDX-License-Identifier: AGPL-3.0-or-later
// OpenCfMoto for iOS - Protocol Constants

import Foundation

public enum PxcConstants {
    // Standard Ports
    public static let portMediaData: UInt16 = 10920  // Data stream socket (pulls H.264 frames)
    public static let portMediaCtrl: UInt16 = 10921  // Media control socket (ReqBase framing)
    public static let portPxcCtrl: UInt16   = 10922  // PXC control socket (CmdBaseHead framing)
    public static let portBikeProbe: UInt16 = 10930  // Bike probe listening port

    // Channel Selection Commands (Port 10922)
    public static let cmdChannelCarCtrl: Int32 = 0x10000  // Bike opens CAR_CTRL -> Ack 0x10001
    public static let cmdChannelCarData: Int32 = 0x20000  // Bike opens CAR_DATA -> Ack 0x20001

    // PXC Control Plane Commands (CmdBaseHead 16-byte framing)
    public static let cmdMdnsRespond: Int32        = 0x70000010 // Phone -> Bike probe on :10930
    public static let cmdMdnsRespondAck: Int32     = 0x70000011 // Bike -> Phone probe ack
    public static let cmdHeartbeat: Int32          = 0x70000000 // Keepalive request
    public static let cmdHeartbeatAck: Int32       = 0x70000001 // Keepalive response
    public static let cmdClientInfo: Int32         = 0x10010    // Bike sends device info (JSON)
    public static let cmdClientInfoReply: Int32    = 0x10011    // Phone sends client info & auth (JSON)
    public static let cmdQuerySpeed: Int32         = 0x10690    // Bike queries speed -> Ack 0x10691
    public static let cmdQuerySpeedReply: Int32    = 0x10691
    public static let cmdCheckSn: Int32            = 0x103e0    // Bike serial number check -> Ack 0x103e1
    public static let cmdCheckSnAck: Int32         = 0x103e1
    public static let cmdCheckSnResult: Int32      = 0x201c0    // Phone sends SN verification result
    public static let cmdCheckSnResultAck: Int32   = 0x201c1

    // Extended Handshake Commands (CFDL26 / MT-X / Newer Bikes)
    public static let cmdLogReport: Int32          = 0x10780
    public static let cmdLogReportAck: Int32       = 0x10781
    public static let cmdOtaFtpInfo: Int32         = 0x103a0
    public static let cmdMediaFeatureCfg: Int32    = 0x10020
    public static let cmdSockServerInfo: Int32     = 0x104a0
    public static let cmdSockServerInfoAck: Int32  = 0x104a1
    public static let cmdHuTimeSync: Int32         = 0x10600
    public static let cmdHuTimeSyncAck: Int32      = 0x10601
    public static let cmdHuQueryTime: Int32        = 0x10450
    public static let cmdHuQueryTimeAck: Int32     = 0x10451

    // Media Plane Commands (ReqBase 8-byte framing on ports 10921 / 10920)
    public static let reqRvConfigCapture: Int16    = 16  // Bike sends canvas dims (w, h, fps)
    public static let rlyRvConfigCapture: Int16    = 17  // Phone replies with negotiated w, h, encoder
    public static let reqGetVersion: Int16         = 48  // Version request
    public static let rlyGetVersion: Int16         = 49  // Version reply (v=3, sub=1)
    public static let reqHeartbeat: Int16          = 64  // Media heartbeat -> Ack 65
    public static let rlyHeartbeat: Int16          = 65
    public static let reqConfigCaptureExtend: Int16 = 96 // Extended config request -> Reply 97
    public static let rlyConfigCaptureExtend: Int16 = 97
    public static let reqRvDataStart: Int16        = 112 // Bike requests video data start -> Reply 113
    public static let rlyRvDataStart: Int16        = 113
    public static let reqRvDataNext: Int16         = 114 // Bike pulls next raw H.264 frame on :10920
    public static let reqTouch: Int16              = 32  // Touchscreen coordinates from bike
}
