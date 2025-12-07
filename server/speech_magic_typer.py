#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Speech to Text MAGIC TYPER
Mobile se bolo -> Computer khud type karega (Auto-Paste)
"""

import sys
import io
from http.server import HTTPServer, BaseHTTPRequestHandler
import json
import socket
import time
import webbrowser

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Import automation libraries
try:
    import pyperclip
    import pyautogui
    MAGIC_AVAILABLE = True
    print("[OK] Automation libraries loaded successfully!")
except ImportError as e:
    MAGIC_AVAILABLE = False
    print(f"[ERROR] Libraries missing: {e}")

# Import ngrok
try:
    from pyngrok import ngrok
    NGROK_AVAILABLE = True
except ImportError:
    NGROK_AVAILABLE = False
    print("[WARN] pyngrok not installed. Public URL won't work.")

# Global variables
latest_text = ""
public_url = ""

class MagicTyperHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            self.send_response(200)
            self.send_header('Content-type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(self.get_html_page().encode('utf-8'))
        elif self.path == '/ping':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path == '/receive_text':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                text = data.get('text', '')
                
                print(f"\n{'='*40}")
                print(f"🎤 RECEIVED: {text}")
                
                if MAGIC_AVAILABLE and text:
                    # 1. Copy to clipboard
                    pyperclip.copy(text)
                    print("📋 Copied to clipboard...")
                    
                    # 2. Beep to alert user (System default sound)
                    print("🔔 Beep!")
                    sys.stdout.write('\a')
                    sys.stdout.flush()
                    
                    # 3. Wait a bit
                    time.sleep(0.2)
                    
                    # 4. Robust Paste (Hold Ctrl -> Press V -> Release Ctrl)
                    print("⌨️  Pasting...")
                    pyautogui.keyDown('ctrl')
                    pyautogui.press('v')
                    pyautogui.keyUp('ctrl')
                    print("✅ DONE!")
                
                print(f"{'='*40}\n")
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(json.dumps({'status': 'success'}).encode())
            
            except Exception as e:
                print(f"Error: {e}")
                self.send_response(500)
                self.end_headers()

    def log_message(self, format, *args):
        pass

    def get_html_page(self):
        return '''
<!DOCTYPE html>
<html>
<head>
    <title>Magic Typer Running</title>
    <style>
        body { font-family: sans-serif; background: #2d3436; color: white; text-align: center; padding: 50px; }
        .status { font-size: 24px; color: #00b894; margin: 20px; }
        .instruction { background: #636e72; padding: 20px; border-radius: 10px; display: inline-block; }
    </style>
</head>
<body>
    <h1>✨ Magic Typer is RUNNING!</h1>
    <div class="status">● Ready to Auto-Type</div>
    <div class="instruction">
        <p>1. Click on Notepad (or where you want to type)</p>
        <p>2. Speak into your mobile</p>
        <p>3. Watch it type automatically!</p>
    </div>
</body>
</html>
'''

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except:
        return "127.0.0.1"

def main():
    PORT = 8080
    local_ip = get_local_ip()
    global public_url
    
    print("\n" + "█"*60)
    print("   ✨ SPEECH TO TEXT MAGIC TYPER (INTERNET MODE) ✨")
    print("█"*60)
    
    # Start Ngrok Tunnel
    if NGROK_AVAILABLE:
        try:
            print("\n🌐 Starting Public Tunnel (Ngrok)...")
            
            # Set Auth Token
            ngrok.set_auth_token("36Vd29nRrMAk4eQ0olYg5acxwLT_6TRr961mhdDtBouZAPZNa")
            
            # Open a HTTP tunnel on the default port 8080
            public_url = ngrok.connect(PORT).public_url
            print(f"✅ PUBLIC URL GENERATED: {public_url}")
            print("   (Use this URL in Mobile App to connect from ANYWHERE)")
        except Exception as e:
            print(f"❌ Ngrok Error: {e}")
            public_url = "Error generating public URL"

    print(f"\n✅ Local IP: {local_ip}")
    print(f"✅ Port: {PORT}")
    
    print("\n📱 MOBILE SETUP:")
    if public_url and "http" in public_url:
        print(f"   👉 URL: {public_url}")
    else:
        print(f"   👉 URL: http://{local_ip}:{PORT} (Local WiFi only)")
        
    print("\n⚡ HOW TO USE:")
    print("   1. Minimize this window")
    print("   2. Click on Notepad (make cursor blink)")
    print("   3. Speak on Mobile")
    print("   4. Text will appear automatically!")
    print("\n" + "█"*60 + "\n")

    # Open browser
    try:
        webbrowser.open(f'http://localhost:{PORT}')
    except:
        pass

    server = HTTPServer(('0.0.0.0', PORT), MagicTyperHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("Stopped.")
        if NGROK_AVAILABLE:
            ngrok.kill()

if __name__ == '__main__':
    main()
