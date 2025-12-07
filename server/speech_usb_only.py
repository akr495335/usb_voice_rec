#!/usr/bin/env python3
"""
Speech to Text MAGIC TYPER - USB Mode
Simple server that receives text and pastes it
"""

import sys
import time
import pyperclip
import pyautogui
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

PORT = 8080
latest_text = ""  # Store latest text for web display

class MagicTyperHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        """Handle CORS preflight"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        """Handle GET requests"""
        if self.path == '/ping':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode())
        elif self.path == '/get_latest_text':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'text': latest_text}).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        """Handle text from mobile"""
        global latest_text
        
        if self.path == '/receive_text':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            text = data.get('text', '')
            
            print(f"\nReceived: {text}")
            latest_text = text  # Store for web display
            
            if text:
                # 1. Copy
                pyperclip.copy(text)
                
                # 2. Beep
                sys.stdout.write('\a')
                sys.stdout.flush()
                
                # 3. Paste
                pyautogui.hotkey('ctrl', 'v')
                print("PASTED!")
            
            # Response
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            response = {'status': 'success'}
            self.wfile.write(json.dumps(response).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    print("=" * 60)
    print("MAGIC TYPER - USB MODE")
    print("=" * 60)
    print(f"Server running on http://localhost:{PORT}")
    print(f"Use this URL in your mobile app")
    print("=" * 60)
    
    server = HTTPServer(('0.0.0.0', PORT), MagicTyperHandler)
    server.serve_forever()

