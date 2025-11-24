#!/usr/bin/env python3
import socket
import time
import argparse
import threading
from datetime import datetime

sent_packets = {}  # Store {seq: send_time} to calculate travel time
stop_event = threading.Event()
print_lock = threading.Lock()  # Lock for thread-safe printing

def log_msg(level, msg):
    """Thread-safe logging with timestamp and consistent formatting."""
    with print_lock:
        timestamp = datetime.now().strftime("%H:%M:%S.%f")[:-3]  # HH:MM:SS.mmm
        print(f"[{timestamp}] [{level:8s}] {msg}")

def receive_udp(listen_port, listen_ip=None):
    """Listen for incoming UDP packets and calculate travel time."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bind_addr = listen_ip if listen_ip else "0.0.0.0"
    sock.bind((bind_addr, listen_port))
    log_msg("LISTEN", f"Started listening on {bind_addr}:{listen_port}")
    
    while not stop_event.is_set():
        try:
            sock.settimeout(1.0)
            data, addr = sock.recvfrom(1024)
            recv_time = time.time()
            message = data.decode('utf-8')
            
            # Try to extract sequence number from payload
            try:
                seq = int(message)
                if seq in sent_packets:
                    send_time = sent_packets[seq]
                    travel_time = (recv_time - send_time) * 1000  # Convert to milliseconds
                    log_msg("RECEIVED", f"Seq #{seq:4d} from {str(addr):30s} | RTT: {travel_time:7.2f}ms")
                    del sent_packets[seq]  # Remove from tracking
                else:
                    log_msg("RECEIVED", f"Seq #{seq:4d} from {str(addr):30s} | (no matching sent packet)")
            except ValueError:
                log_msg("RECEIVED", f"from {addr}: {message}")
        except socket.timeout:
            continue
        except Exception as e:
            if not stop_event.is_set():
                log_msg("ERROR", f"Receive error: {e}")
            break
    
    sock.close()
    log_msg("LISTEN", f"Stopped listening on port {listen_port}")

def send_udp_periodic(ip, port, interval, iface=None, src_ip=None, listen_port=None):
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # Option A: bind to specific interface (requires root)
    if iface:
        # SO_BINDTODEVICE expects a bytes string (no trailing \0 needed on Linux here)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, iface.encode())
        log_msg("INFO", f"Binding socket to interface: {iface}")

    # Option B: bind to specific source IP (e.g. 12.1.1.x on oaitun_ue1)
    if src_ip:
        sock.bind((src_ip, 0))
        log_msg("INFO", f"Binding socket to source IP: {src_ip}")

    # Start listening thread if listen_port is specified
    if listen_port:
        listen_thread = threading.Thread(target=receive_udp, args=(listen_port, src_ip), daemon=True)
        listen_thread.start()
        time.sleep(0.5)  # Give receiver thread time to start

    log_msg("INFO", f"Sending UDP to {ip}:{port} every {interval}s")
    if listen_port:
        log_msg("INFO", f"Bidirectional mode: listening on port {listen_port}")
    log_msg("INFO", f"Payload: incrementing sequence number (receiver should echo back)")

    seq = 0

    while True:
        try:
            seq += 1
            send_time = time.time()
            # Send incrementing sequence number as payload
            message = str(seq)
            sock.sendto(message.encode("utf-8"), (ip, port))
            sent_packets[seq] = send_time
            log_msg("SENT", f"Seq #{seq:4d} to {ip}:{port}")
            time.sleep(interval)
        except KeyboardInterrupt:
            log_msg("INFO", "Stopped by user.")
            stop_event.set()
            break
        except Exception as e:
            log_msg("ERROR", f"{e}")
            time.sleep(interval)

def main():
    parser = argparse.ArgumentParser(description="Send UDP packets with incrementing sequence numbers and listen for responses.")
    parser.add_argument("--ip", required=True, help="Target IP address")
    parser.add_argument("--port", type=int, required=True, help="Target UDP port")
    parser.add_argument("--interval", type=float, default=1.0, help="Interval in seconds between packets")
    parser.add_argument("--iface", help="Interface to send from (e.g. oaitun_ue1)")
    parser.add_argument("--src-ip", help="Source IP to bind (e.g. 12.1.1.2)")
    parser.add_argument("--listen-port", type=int, required=True, help="Port to listen for responses")

    args = parser.parse_args()
    send_udp_periodic(args.ip, args.port, args.interval,
                      iface=args.iface, src_ip=args.src_ip, listen_port=args.listen_port)

if __name__ == "__main__":
    main()
