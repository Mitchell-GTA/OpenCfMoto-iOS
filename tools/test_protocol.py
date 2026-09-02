#!/usr/bin/env python3
# SPDX-License-Identifier: AGPL-3.0-or-later

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mock_dashboard import pack_cmd_frame, unpack_cmd_frame, pack_req_frame, unpack_req_frame, CMD_MDNS_RESPOND

def test_cmd_framing():
    payload = b'{"status": true}'
    packed = pack_cmd_frame(CMD_MDNS_RESPOND, payload)
    assert len(packed) == 16 + len(payload)

    frame, consumed = unpack_cmd_frame(packed)
    assert consumed == len(packed)
    cmd, received_payload = frame
    assert cmd == CMD_MDNS_RESPOND
    assert received_payload == payload
    print("✅ CmdBaseHead framing test passed!")

def test_req_framing():
    body = b'\x01\x02\x03\x04'
    packed = pack_req_frame(16, 1234, body)
    assert len(packed) == 8 + len(body)

    (cmd_type, token, received_body), consumed = unpack_req_frame(packed)
    assert consumed == len(packed)
    assert cmd_type == 16
    assert token == 1234
    assert received_body == body
    print("✅ ReqBase framing test passed!")

if __name__ == '__main__':
    test_cmd_framing()
    test_req_framing()
    print("🎉 All mock dashboard protocol tests passed successfully!")
