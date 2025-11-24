#!/usr/bin/env python3
import socket
import argparse
import signal
import threading

stop_event = threading.Event()
verbose = True

def _signal_handler(sig, frame):
    """Handle shutdown signals."""
    if verbose:
        print("\n[EDGE] Shutdown signal received")
    stop_event.set()

def receive_udp(listen_port, listen_ip=None):
    """Listen for incoming UDP packets and print received payload."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    bind_addr = listen_ip if listen_ip else "0.0.0.0"
    sock.bind((bind_addr, listen_port))
    
    if verbose:
        print(f"[LISTEN] Started listening on {bind_addr}:{listen_port}")
    
    try:
        while not stop_event.is_set():
            try:
                sock.settimeout(1.0)
                data, addr = sock.recvfrom(1024)
                message = data.decode('utf-8')
                
                # Extract payload from message (format: "seq:payload")
                parts = message.split(':', 1)
                if len(parts) == 2:
                    payload = parts[1]
                else:
                    payload = message
                
                src_ip, src_port = addr
                if verbose:
                    print(f"[RECEIVED] from {src_ip}:{src_port} | Payload: {payload}")
                    
            except socket.timeout:
                continue
            except Exception as e:
                if not stop_event.is_set():
                    if verbose:
                        print(f"[ERROR] Receive error: {e}")
                break
    
    except KeyboardInterrupt:
        if verbose:
            print("\n[LISTEN] Interrupted by user")
    finally:
        sock.close()
        if verbose:
            print(f"[LISTEN] Stopped listening on port {listen_port}")
            print("[EDGE] Edge node shutting down")

def main():
    parser = argparse.ArgumentParser(
        description="Edge node: Listen for incoming UDP packets and print payload."
    )
    parser.add_argument("--listen-port", type=int, required=True, help="Port to listen on for incoming UDP packets")
    parser.add_argument("--listen-ip", help="IP address to listen on (default: 0.0.0.0)")
    parser.add_argument("--verbose", action="store_true", help="Enable verbose output")

    args = parser.parse_args()
    
    # Set global verbose flag
    global verbose
    verbose = args.verbose

    if verbose:
        print("[EDGE] Starting edge node for packet capture...")
        print(f"[EDGE] Listen port: {args.listen_port}")
        print(f"[EDGE] Listen IP: {args.listen_ip if args.listen_ip else '0.0.0.0'}")
    
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)
    
    # Start listening for UDP packets
    try:
        receive_udp(args.listen_port, args.listen_ip)
    except KeyboardInterrupt:
        if verbose:
            print("\n[EDGE] Keyboard interrupt received")
    except Exception as e:
        if verbose:
            print(f"[EDGE ERROR] Fatal error: {e}")
        raise

if __name__ == "__main__":
    main()

