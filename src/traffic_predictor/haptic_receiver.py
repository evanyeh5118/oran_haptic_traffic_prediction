#!/usr/bin/env python3
import socket
import argparse
import threading

def receive_and_echo(listen_port, response_ip, response_port, listen_ip=None, iface=None):
    """Listen for incoming UDP packets in format series_num:payload and echo the series number back."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    
    # Allow port to be reused even if in TIME_WAIT state (SO_REUSEPORT for UDP)
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    except (AttributeError, OSError):
        pass  # SO_REUSEPORT may not be available on all systems
    
    # Option A: bind to specific interface (requires root)
    if iface:
        # SO_BINDTODEVICE expects a bytes string (no trailing \0 needed on Linux here)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, iface.encode())
        print(f"[INFO] Binding socket to interface: {iface}")
    
    bind_addr = listen_ip if listen_ip else "0.0.0.0"
    sock.bind((bind_addr, listen_port))
    
    print(f"[INFO] Receiver listening on {bind_addr}:{listen_port}")
    print(f"[INFO] Will echo responses to {response_ip}:{response_port}")
    
    received_count = 0
    echoed_count = 0
    
    try:
        while True:
            try:
                data, addr = sock.recvfrom(1024)
                received_count += 1
                message = data.decode('utf-8').strip()
                
                try:
                    # Parse message format: series_num:payload
                    parts = message.split(':', 1)
                    if len(parts) == 2:
                        series_num = parts[0]
                        payload = parts[1]
                        # Echo the series number back to the sender
                        response = series_num
                        sock.sendto(response.encode('utf-8'), (response_ip, response_port))
                        echoed_count += 1
                        print(f"[ECHO #{series_num}] from {addr} | payload: {payload} -> to {response_ip}:{response_port}")
                    else:
                        print(f"[WARNING] Invalid message format from {addr}: {message} (expected series_num:payload)")
                except ValueError:
                    print(f"[WARNING] Failed to parse message from {addr}: {message}")
            except Exception as e:
                print(f"[ERROR] Error receiving/echoing: {e}")
    except KeyboardInterrupt:
        print(f"\n[INFO] Stopped by user.")
        print(f"[STATS] Total received: {received_count}, Total echoed: {echoed_count}")
    finally:
        sock.close()
        print(f"[INFO] Receiver stopped.")

def main():
    parser = argparse.ArgumentParser(description="UDP receiver that parses series_num:payload format and echoes the series number back to sender.")
    parser.add_argument("--listen-port", type=int, required=True, help="Port to listen for incoming packets")
    parser.add_argument("--response-ip", required=True, help="IP address to send echo responses to")
    parser.add_argument("--response-port", type=int, required=True, help="Port to send echo responses to")
    parser.add_argument("--listen-ip", help="IP address to bind to (default: 0.0.0.0)")
    parser.add_argument("--iface", help="Interface to bind to (e.g. oaitun_dn)")

    args = parser.parse_args()
    receive_and_echo(args.listen_port, args.response_ip, args.response_port, 
                     listen_ip=args.listen_ip, iface=args.iface)

if __name__ == "__main__":
    main()

