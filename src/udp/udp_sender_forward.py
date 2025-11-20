#!/usr/bin/env python3
import socket
import time
import argparse

def send_udp_periodic(ip, port, payload, interval, iface=None, src_ip=None):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # Option A: bind to specific interface (requires root)
    if iface:
        # SO_BINDTODEVICE expects a bytes string (no trailing \0 needed on Linux here)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, iface.encode())
        print(f"[INFO] Binding socket to interface: {iface}")

    # Option B: bind to specific source IP (e.g. 12.1.1.x on oaitun_ue1)
    if src_ip:
        sock.bind((src_ip, 0))
        print(f"[INFO] Binding socket to source IP: {src_ip}")

    data = payload.encode("utf-8")
    print(f"[INFO] Sending UDP to {ip}:{port} every {interval} sec. Payload='{payload}'")

    while True:
        try:
            sock.sendto(data, (ip, port))
            print(f"[SENT] {payload}")
            time.sleep(interval)
        except KeyboardInterrupt:
            print("\n[INFO] Stopped by user.")
            break
        except Exception as e:
            print(f"[ERROR] {e}")
            time.sleep(interval)

def main():
    parser = argparse.ArgumentParser(description="Send UDP packet periodically.")
    parser.add_argument("--ip", required=True, help="Target IP address")
    parser.add_argument("--port", type=int, required=True, help="Target UDP port")
    parser.add_argument("--payload", default="hello", help="UDP payload string")
    parser.add_argument("--interval", type=float, default=1.0, help="Interval in seconds")
    parser.add_argument("--iface", help="Interface to send from (e.g. oaitun_ue1)")
    parser.add_argument("--src-ip", help="Source IP to bind (e.g. 12.1.1.2)")

    args = parser.parse_args()
    send_udp_periodic(args.ip, args.port, args.payload, args.interval,
                      iface=args.iface, src_ip=args.src_ip)

if __name__ == "__main__":
    main()
