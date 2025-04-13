import asyncio
import websockets
import pyautogui
import socket
import threading
from zeroconf import ServiceInfo, Zeroconf

# ✅ Safely get local Wi-Fi IP (NOT 127.0.0.1)
def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("8.8.8.8", 80))  # doesn't actually send data
        local_ip = s.getsockname()[0]
        return local_ip
    except Exception:
        return "127.0.0.1"  # Fallback
    finally:
        s.close()

# 🎯 Handles incoming WebSocket commands
async def control_volume(websocket, path):
    client_ip = websocket.remote_address[0]
    print(f"📱 Client connected from {client_ip}")
    try:
        async for msg in websocket:
            print(f"🔊 Command: {msg}")
            actions = {
                "volume_up": "volumeup",
                "volume_down": "volumedown",
                "mute": "volumemute",
                "play_pause": "playpause",
                "previous_track": "prevtrack",
                "next_track": "nexttrack",
            }
            if msg in actions:
                pyautogui.press(actions[msg])
                await websocket.send(f"✅ Executed: {msg}")
            else:
                await websocket.send(f"❌ Unknown command: {msg}")
    except websockets.ConnectionClosed:
        print(f"❌ Client {client_ip} disconnected")

# 🧠 mDNS registration (optional, for devices that support it)
def register_mdns_service(port: int):
    def _run_mdns():
        try:
            ip = get_local_ip()
            desc = {'path': '/'}
            info = ServiceInfo(
                "_ws._tcp.local.",
                "ClockControl._ws._tcp.local.",
                addresses=[socket.inet_aton(ip)],
                port=port,
                properties=desc,
                server=f"{socket.gethostname()}.local.",
            )
            zeroconf = Zeroconf()
            zeroconf.register_service(info)
            print(f"🌐 mDNS registered as ClockControl._ws._tcp.local. → {ip}:{port}")
        except Exception as e:
            print(f"⚠️ mDNS registration failed: {e}")
    
    # Run in separate thread to avoid blocking
    threading.Thread(target=_run_mdns, daemon=True).start()

# 🚀 Main entrypoint
async def main():
    port = 8765
    local_ip = get_local_ip()
    
    # Try to register mDNS service
    try:
        register_mdns_service(port)
    except Exception as e:
        print(f"⚠️ mDNS registration error (not critical): {e}")
    
    print(f"📋 Your PC's IP address is: {local_ip}")
    print(f"📱 Enter this IP address in your mobile app")
    
    async with websockets.serve(control_volume, "0.0.0.0", port):
        print(f"🧠 WebSocket server running at ws://{local_ip}:{port}")
        await asyncio.Future()  # keep server running forever

# 🟢 Launch server
if __name__ == "__main__":
    print("🔄 Starting WebSocket server for remote control...")
    asyncio.run(main())