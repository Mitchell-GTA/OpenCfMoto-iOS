#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later
# Mock CFMoto / MotoPlay Dashboard Emulator for Protocol Testing

import socket
import struct
import json
import time
import threading
import sys

PROBE_PORT = 10930
PHONE_PORT_PXC_CTRL = 10922
PHONE_PORT_MEDIA_CTRL = 10921
PHONE_PORT_MEDIA_DATA = 10920

CMD_MDNS_RESPOND = 0x70000010
CMD_MDNS_RESPOND_ACK = 0x70000011
CMD_CHANNEL_CAR_CTRL = 0x10000
CMD_CLIENT_INFO = 0x10010
CMD_CLIENT_INFO_REPLY = 0x10011
CMD_CHECK_SN = 0x103e0
CMD_CHECK_SN_ACK = 0x103e1
CMD_CHECK_SN_RESULT = 0x201c0
CMD_HEARTBEAT = 0x70000000

def pack_cmd_frame(cmd: int, payload: bytes = b'') -> bytes:
    total_len = 16 + len(payload)
    magic = cmd ^ total_len
    header = struct.pack('<iiii', cmd, total_len, magic, 0)
    return header + payload

def unpack_cmd_frame(data: bytes):
    if len(data) < 16:
        return None, 0
    cmd, total_len, magic, _ = struct.unpack('<iiii', data[:16])
    if (cmd ^ total_len) != magic:
        raise ValueError(f"Invalid magic: cmd={hex(cmd)} total_len={total_len} magic={hex(magic)}")
    if len(data) < total_len:
        return None, 0
    payload = data[16:total_len]
    return (cmd, payload), total_len

def pack_req_frame(cmd_type: int, token: int = 0, body: bytes = b'') -> bytes:
    header = struct.pack('<hhi', cmd_type, len(body), token)
    return header + body

def unpack_req_frame(data: bytes):
    if len(data) < 8:
        return None, 0
    cmd_type, cmd_len, token = struct.unpack('<hhi', data[:8])
    total_len = 8 + cmd_len
    if len(data) < total_len:
        return None, 0
    body = data[8:total_len]
    return (cmd_type, token, body), total_len

def run_mock_dashboard(host_ip="0.0.0.0"):
    print(f"==================================================")
    print(f"🏍️ MotoPlay / CFMoto Dashboard Emulator Running")
    print(f"Listening for phone probe on port {PROBE_PORT}...")
    print(f"==================================================")

    probe_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    probe_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    probe_sock.bind((host_ip, PROBE_PORT))
    probe_sock.listen(1)

    while True:
        client_sock, client_addr = probe_sock.accept()
        phone_ip = client_addr[0]
        print(f"\n[PROBE] Phone connected from {phone_ip}:{client_addr[1]}")

        data = client_sock.recv(1024)
        frame_tuple, _ = unpack_cmd_frame(data)
        if frame_tuple:
            cmd, payload = frame_tuple
            print(f"[PROBE] Received cmd={hex(cmd)} payload={payload.decode('utf-8', errors='ignore')}")
            ack = pack_cmd_frame(CMD_MDNS_RESPOND_ACK, b'{"status":true}')
            client_sock.sendall(ack)
            print(f"[PROBE] Sent Probe Ack. Closing probe socket.")
        client_sock.close()

        time.sleep(0.5)
        threading.Thread(target=drive_dash_connection, args=(phone_ip,), daemon=True).start()

def drive_dash_connection(phone_ip):
    print(f"\n[DASH] Connecting back to phone at {phone_ip} on ports 10922, 10921, 10920...")

    # 1. Port 10922 - PXC Control
    ctrl_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        ctrl_sock.connect((phone_ip, PHONE_PORT_PXC_CTRL))
        print(f"[:10922] Connected to phone PXC control")

        ctrl_sock.sendall(pack_cmd_frame(CMD_CHANNEL_CAR_CTRL))
        resp = ctrl_sock.recv(1024)
        print(f"[:10922] CAR_CTRL Ack received")

        client_info = json.dumps({
            "HUID": "CFMOTO-6GUV-TEST-DASH",
            "HUName": "CFMoto 675SR MotoPlay",
            "channel": "CFMOTO_675",
            "flavor": 65540,
            "socketTimeoutPeriodWifi": 9
        }).encode('utf-8')
        ctrl_sock.sendall(pack_cmd_frame(CMD_CLIENT_INFO, client_info))
        resp = ctrl_sock.recv(2048)
        print(f"[:10922] Received CLIENT_INFO reply from phone!")

        sn_req = json.dumps({"client_set": "easy_conn", "sn": "SN-TEST-123456"}).encode('utf-8')
        ctrl_sock.sendall(pack_cmd_frame(CMD_CHECK_SN, sn_req))
        resp = ctrl_sock.recv(1024)
        print(f"[:10922] CHECK_SN ack received from phone")

    except Exception as e:
        print(f"[:10922] Control socket error: {e}")
        return

    # 2. Port 10921 - Media Control
    media_ctrl_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        media_ctrl_sock.connect((phone_ip, PHONE_PORT_MEDIA_CTRL))
        print(f"[:10921] Connected to phone media control")

        cfg_body = struct.pack('<hhii', 800, 384, 25, 2)
        media_ctrl_sock.sendall(pack_req_frame(16, 1, cfg_body))
        resp = media_ctrl_sock.recv(1024)
        print(f"[:10921] RLY_CONFIG_CAPTURE(17) received from phone")

        media_ctrl_sock.sendall(pack_req_frame(112, 2, b''))
        resp = media_ctrl_sock.recv(1024)
        print(f"[:10921] RLY_RV_DATA_START(113) received from phone")

    except Exception as e:
        print(f"[:10921] Media control socket error: {e}")

    # 3. Port 10920 - Media Data (Pulling Frames)
    media_data_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    try:
        media_data_sock.connect((phone_ip, PHONE_PORT_MEDIA_DATA))
        print(f"[:10920] Connected to phone media data stream. Pulling video frames...")

        frames_received = 0
        while frames_received < 50:
            media_data_sock.sendall(pack_req_frame(114, frames_received, b''))

            size_header = media_data_sock.recv(4)
            if not size_header or len(size_header) < 4:
                break
            frame_size = struct.unpack('<i', size_header)[0]

            frame_data = b''
            while len(frame_data) < frame_size:
                chunk = media_data_sock.recv(min(4096, frame_size - len(frame_data)))
                if not chunk:
                    break
                frame_data += chunk

            frames_received += 1
            if frames_received == 1 or frames_received % 10 == 0:
                print(f"[:10920] 📺 Received H.264 Frame #{frames_received} ({len(frame_data)} bytes)")

            time.sleep(0.04)

        print(f"[:10920] Successfully pulled {frames_received} H.264 frames from iOS app!")

    except Exception as e:
        print(f"[:10920] Media data socket error: {e}")

if __name__ == '__main__':
    run_mock_dashboard()
