#!/usr/bin/env python3
import socket
import time
import argparse
import threading
from dataset_reader import CsvReplayReader

sent_packets = {}  # Store {seq: send_time} to calculate travel time
stop_event = threading.Event()
verbose = True  # Global verbose flag

def receive_udp(listen_port, listen_ip=None):
    """Listen for incoming UDP packets and calculate travel time."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bind_addr = listen_ip if listen_ip else "0.0.0.0"
    sock.bind((bind_addr, listen_port))
    if verbose:
        print(f"[LISTEN] Started listening on {bind_addr}:{listen_port}")
    
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
                    if verbose:
                        print(f"[RECEIVED #{seq}] from {addr} | Travel time: {travel_time:.2f}ms")
                    del sent_packets[seq]  # Remove from tracking
                else:
                    if verbose:
                        print(f"[RECEIVED #{seq}] from {addr} | (no matching sent packet)")
            except ValueError:
                if verbose:
                    print(f"[RECEIVED] from {addr}: {message}")
        except socket.timeout:
            continue
        except Exception as e:
            if not stop_event.is_set():
                if verbose:
                    print(f"[ERROR] Receive error: {e}")
            break
    
    sock.close()
    if verbose:
        print(f"[LISTEN] Stopped listening on port {listen_port}")

def send_udp_from_csv(ip, port, csv_path, iface=None, src_ip=None, listen_port=None, 
                       time_scale=1.0, replay_real_timing=True):
    """Send UDP packets from CSV file with transmission rules."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # Option A: bind to specific interface (requires root)
    if iface:
        # SO_BINDTODEVICE expects a bytes string (no trailing \0 needed on Linux here)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, iface.encode())
        if verbose:
            print(f"[INFO] Binding socket to interface: {iface}")

    # Option B: bind to specific source IP (e.g. 12.1.1.x on oaitun_ue1)
    if src_ip:
        sock.bind((src_ip, 0))
        if verbose:
            print(f"[INFO] Binding socket to source IP: {src_ip}")

    # Start listening thread if listen_port is specified
    if listen_port:
        listen_thread = threading.Thread(target=receive_udp, args=(listen_port, src_ip), daemon=True)
        listen_thread.start()
        time.sleep(0.5)  # Give receiver thread time to start

    if verbose:
        print(f"[INFO] Sending UDP to {ip}:{port}")
        print(f"[INFO] CSV file: {csv_path}")
        print(f"[INFO] Time scale: {time_scale}x")
        if replay_real_timing:
            print(f"[INFO] Timing: replaying CSV 'Time' column (scaled)")
        else:
            print(f"[INFO] Timing: no replay (sending as fast as possible)")
        if listen_port:
            print(f"[INFO] Bidirectional mode: listening on port {listen_port}")

    # Load CSV data
    try:
        reader = CsvReplayReader(csv_path, time_scale=time_scale, verbose=verbose)
    except Exception as e:
        if verbose:
            print(f"[ERROR] Failed to load CSV: {e}")
        sock.close()
        return

    sent_count = 0
    start_wall = time.perf_counter()

    try:
        for csv_row in reader:
            if stop_event.is_set():
                break

            # Check transmission rule from sender.py
            if not csv_row.should_transmit:
                if verbose:
                    print(f"[SKIP row {csv_row.row_index}] Transmission flag is False")
                continue

            # Schedule based on real-time counter and CSV 'Time' (if available)
            if replay_real_timing and csv_row.relative_time is not None:
                target_wall = start_wall + csv_row.relative_time
                now = time.perf_counter()
                sleep_secs = target_wall - now
                if sleep_secs > 0:
                    time.sleep(sleep_secs)

            # Send payload from CSV
            message = csv_row.payload
            sock.sendto(message.encode("utf-8"), (ip, port))
            sent_count += 1
            if verbose:
                print(f"[SENT #{sent_count}] row {csv_row.row_index}: {message}")

    except KeyboardInterrupt:
        if verbose:
            print("\n[INFO] Stopped by user.")
        stop_event.set()
    except Exception as e:
        if verbose:
            print(f"[ERROR] {e}")
    finally:
        sock.close()
        if verbose:
            print(f"[INFO] Total sent: {sent_count}")


def send_udp_periodic(ip, port, interval, iface=None, src_ip=None, listen_port=None):
    """Legacy function: Send periodic UDP packets with incrementing sequence numbers."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    # Option A: bind to specific interface (requires root)
    if iface:
        # SO_BINDTODEVICE expects a bytes string (no trailing \0 needed on Linux here)
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BINDTODEVICE, iface.encode())
        if verbose:
            print(f"[INFO] Binding socket to interface: {iface}")

    # Option B: bind to specific source IP (e.g. 12.1.1.x on oaitun_ue1)
    if src_ip:
        sock.bind((src_ip, 0))
        if verbose:
            print(f"[INFO] Binding socket to source IP: {src_ip}")

    # Start listening thread if listen_port is specified
    if listen_port:
        listen_thread = threading.Thread(target=receive_udp, args=(listen_port, src_ip), daemon=True)
        listen_thread.start()
        time.sleep(0.5)  # Give receiver thread time to start

    if verbose:
        print(f"[INFO] Sending UDP to {ip}:{port} every {interval} sec")
        if listen_port:
            print(f"[INFO] Bidirectional mode: listening on port {listen_port}")
        print(f"[INFO] Payload: incrementing sequence number (receiver should echo back)")

    seq = 0

    while True:
        try:
            seq += 1
            send_time = time.time()
            # Send incrementing sequence number as payload
            message = str(seq)
            sock.sendto(message.encode("utf-8"), (ip, port))
            sent_packets[seq] = send_time
            if verbose:
                print(f"[SENT #{seq}]")
            time.sleep(interval)
        except KeyboardInterrupt:
            if verbose:
                print("\n[INFO] Stopped by user.")
            stop_event.set()
            break
        except Exception as e:
            if verbose:
                print(f"[ERROR] {e}")
            time.sleep(interval)

def main():
    parser = argparse.ArgumentParser(
        description="Send UDP packets from CSV file or with periodic sequence numbers."
    )
    parser.add_argument("--ip", required=True, help="Target IP address")
    parser.add_argument("--port", type=int, required=True, help="Target UDP port")
    parser.add_argument("--csv", help="Path to CSV file (if provided, reads from CSV; otherwise periodic mode)")
    parser.add_argument("--interval", type=float, default=1.0, help="Interval in seconds between packets (periodic mode only)")
    parser.add_argument("--time-scale", type=float, default=1.0, help="Time scale for CSV replay (1.0=real-time)")
    parser.add_argument("--no-replay-timing", action="store_true", help="Send CSV data as fast as possible (no timing replay)")
    parser.add_argument("--iface", help="Interface to send from (e.g. oaitun_ue1)")
    parser.add_argument("--src-ip", help="Source IP to bind (e.g. 12.1.1.2)")
    parser.add_argument("--listen-port", type=int, required=True, help="Port to listen for responses")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")

    args = parser.parse_args()
    
    # Set global verbose flag
    global verbose
    verbose = args.verbose

    if args.csv:
        # CSV mode: send from file with transmission rules
        send_udp_from_csv(
            args.ip, args.port, args.csv,
            iface=args.iface, src_ip=args.src_ip, listen_port=args.listen_port,
            time_scale=args.time_scale, replay_real_timing=not args.no_replay_timing
        )
    else:
        # Periodic mode: send incrementing sequence numbers
        send_udp_periodic(
            args.ip, args.port, args.interval,
            iface=args.iface, src_ip=args.src_ip, listen_port=args.listen_port
        )

if __name__ == "__main__":
    main()
