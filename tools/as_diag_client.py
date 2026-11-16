#!/usr/bin/env python3
"""Minimal client for the UnrealAngelScript in-game debug/LSP protocol (game port 27099).

Wire format (from Hazelight vscode-unreal-angelscript language-server/src/unreal-buffers.ts):
  [uint32le len][int8 type][payload]   len = 1 + payload size
MessageType: 0=Diagnostics, 1=RequestDebugDatabase, 2=DebugDatabase, 40=DebugDatabaseFinished, ...
Diagnostics payload: string path, int32 count, then count x (string msg, int32 line, int32 char, int32 isError, int32 isInfo)
string: int32 n; n<0 -> utf16le (-n chars), n>0 -> utf8 (n bytes); trailing NUL included in count.
"""
import socket, struct, sys, time, json

HOST, PORT = "127.0.0.1", 27099

def read_string(buf, off):
    n = struct.unpack_from("<i", buf, off)[0]; off += 4
    ucs2 = n < 0
    if ucs2: n = -n
    if ucs2:
        raw = buf[off:off + n*2]; off += n*2
        s = raw.decode("utf-16-le", errors="replace")
    else:
        raw = buf[off:off + n]; off += n
        s = raw.decode("utf-8", errors="replace")
    return (s[:-1] if s.endswith("\x00") else s), off

class Reader:
    def __init__(self): self.buf = b""
    def feed(self, data): self.buf += data
    def next_msg(self):
        while len(self.buf) >= 5:
            ln = struct.unpack_from("<I", self.buf, 0)[0]
            mtype = struct.unpack_from("<b", self.buf, 4)[0]
            if len(self.buf) - 4 < ln:
                return None  # incomplete
            payload = self.buf[5:4 + ln]
            self.buf = self.buf[4 + ln:]
            return mtype, payload
        return None

def main(timeout_s):
    s = socket.create_connection((HOST, PORT), timeout=10)
    print(f"connected to {HOST}:{PORT}", flush=True)
    time.sleep(1.0)
    s.sendall(struct.pack("<Ib", 1, 1))  # RequestDebugDatabase
    print("sent RequestDebugDatabase", flush=True)
    r = Reader()
    s.settimeout(5)
    deadline = time.time() + timeout_s
    seen_diag = seen_db = False
    while time.time() < deadline:
        try:
            data = s.recv(65536)
            if not data:
                print("connection closed by game", flush=True); break
            r.feed(data)
        except socket.timeout:
            continue
        while True:
            msg = r.next_msg()
            if msg is None: break
            mtype, payload = msg
            if mtype == 0:  # Diagnostics
                seen_diag = True
                off = 0
                path, off = read_string(payload, off)
                count = struct.unpack_from("<i", payload, off)[0]; off += 4
                print(f"\n=== DIAGNOSTICS for {path} ({count}) ===", flush=True)
                for _ in range(count):
                    message, off = read_string(payload, off)
                    line, char, is_err, is_info = struct.unpack_from("<iiii", payload, off); off += 16
                    sev = "ERROR" if is_err else ("info" if is_info else "warn")
                    print(f"  [{sev}] {path}:{line}:{char}: {message}", flush=True)
            elif mtype == 2:
                seen_db = True
                off = 0
                js, off = read_string(payload, off)
                print(f"(debug database: {len(js)} bytes json)", flush=True)
            elif mtype == 40:
                print("(debug database finished)", flush=True)
            else:
                print(f"(msg type {mtype}, {len(payload)} bytes)", flush=True)
        if seen_diag and seen_db:
            break
    s.close()

if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 60.0)
