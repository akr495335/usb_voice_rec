#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Simple Voice Typer with GUI Buttons
Hotkey issues ke liye - Button se control karein
"""

import sys
import os
import io

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import json
import threading
import time
import tkinter as tk
from tkinter import ttk
import speech_recognition as sr
import pyautogui
import pyperclip

# Configuration
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')

class SimpleVoiceTyper:
    def __init__(self):
        self.recognizer = sr.Recognizer()
        self.microphone = sr.Microphone()
        self.is_recording = False
        
        # Load config
        self.load_config()
        
        # Adjust recognizer
        self.recognizer.energy_threshold = 4000
        self.recognizer.dynamic_energy_threshold = True
        self.recognizer.pause_threshold = 0.8
        
        # Create GUI
        self.create_gui()
        
        print("✅ Simple Voice Typer Started!")
        print(f"📢 Current Language: {self.config['language']}")
    
    def load_config(self):
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                self.config = json.load(f)
        except:
            self.config = {
                'language': 'en-US',
                'auto_send': True,
                'show_notifications': True
            }
            self.save_config()
    
    def save_config(self):
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
    
    def create_gui(self):
        """Create main GUI window"""
        self.root = tk.Tk()
        self.root.title("Voice Typer")
        self.root.geometry("400x300")
        self.root.configure(bg='#2c3e50')
        
        # Title
        title = tk.Label(
            self.root,
            text="🎤 Voice Typer",
            font=('Arial', 20, 'bold'),
            bg='#2c3e50',
            fg='white'
        )
        title.pack(pady=20)
        
        # Language display
        self.lang_label = tk.Label(
            self.root,
            text=f"Language: {self.config['language']}",
            font=('Arial', 12),
            bg='#2c3e50',
            fg='#ecf0f1'
        )
        self.lang_label.pack(pady=10)
        
        # Status label
        self.status_label = tk.Label(
            self.root,
            text="Ready",
            font=('Arial', 14, 'bold'),
            bg='#2c3e50',
            fg='#2ecc71'
        )
        self.status_label.pack(pady=10)
        
        # Record button
        self.record_btn = tk.Button(
            self.root,
            text="🎤 START RECORDING",
            font=('Arial', 14, 'bold'),
            bg='#27ae60',
            fg='white',
            activebackground='#229954',
            command=self.toggle_recording,
            width=20,
            height=2
        )
        self.record_btn.pack(pady=10)
        
        # Language toggle button
        lang_btn = tk.Button(
            self.root,
            text="🌐 Toggle Language",
            font=('Arial', 11),
            bg='#3498db',
            fg='white',
            activebackground='#2980b9',
            command=self.toggle_language,
            width=20
        )
        lang_btn.pack(pady=5)
        
        # Instructions
        instructions = tk.Label(
            self.root,
            text="1. Click START RECORDING\n2. Speak into microphone\n3. Click STOP RECORDING\n4. Text will type automatically!",
            font=('Arial', 9),
            bg='#2c3e50',
            fg='#bdc3c7',
            justify='left'
        )
        instructions.pack(pady=10)
        
        # Keep window on top
        self.root.attributes('-topmost', True)
    
    def toggle_language(self):
        """Toggle between Hindi and English"""
        if self.config['language'] == 'en-US':
            self.config['language'] = 'hi-IN'
        else:
            self.config['language'] = 'en-US'
        
        self.save_config()
        self.lang_label.config(text=f"Language: {self.config['language']}")
        self.update_status(f"Language: {self.config['language']}", '#3498db')
        print(f"🌐 Language changed to: {self.config['language']}")
    
    def toggle_recording(self):
        """Start or stop recording"""
        if not self.is_recording:
            self.start_recording()
        else:
            self.stop_recording()
    
    def start_recording(self):
        """Start voice recording"""
        if self.is_recording:
            return
        
        self.is_recording = True
        self.record_btn.config(
            text="⏹️ STOP RECORDING",
            bg='#e74c3c',
            activebackground='#c0392b'
        )
        self.update_status("🎤 Recording...", '#e74c3c')
        
        print("\n🎤 Recording started... Speak now!")
        
        # Start recording in separate thread
        threading.Thread(target=self.record_and_type, daemon=True).start()
    
    def stop_recording(self):
        """Stop voice recording"""
        if not self.is_recording:
            return
        
        self.is_recording = False
        self.record_btn.config(
            text="🎤 START RECORDING",
            bg='#27ae60',
            activebackground='#229954'
        )
        print("⏹️ Recording stopped!")
    
    def record_and_type(self):
        """Record audio and convert to text"""
        try:
            with self.microphone as source:
                self.update_status("🔊 Adjusting for noise...", '#f39c12')
                print("🔊 Adjusting for ambient noise...")
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                self.update_status("✅ Listening...", '#2ecc71')
                print("✅ Listening...")
                
                # Listen for audio
                audio = self.recognizer.listen(source, timeout=10, phrase_time_limit=15)
            
            # Stop recording
            self.is_recording = False
            self.root.after(0, lambda: self.record_btn.config(
                text="🎤 START RECORDING",
                bg='#27ae60',
                activebackground='#229954'
            ))
            
            self.update_status("🔄 Processing...", '#9b59b6')
            print("🔄 Processing speech...")
            
            # Recognize speech
            try:
                text = self.recognizer.recognize_google(
                    audio,
                    language=self.config['language']
                )
                
                print(f"✅ Recognized: {text}")
                self.update_status(f"✅ Recognized: {text[:30]}...", '#2ecc71')
                
                # Type the text
                self.type_text(text)
                
                # Reset status after 3 seconds
                self.root.after(3000, lambda: self.update_status("Ready", '#2ecc71'))
                
            except sr.UnknownValueError:
                print("❌ Could not understand audio")
                self.update_status("❌ Could not understand", '#e74c3c')
                self.root.after(3000, lambda: self.update_status("Ready", '#2ecc71'))
                
            except sr.RequestError as e:
                print(f"❌ Error: {e}")
                self.update_status("❌ API Error - Check Internet", '#e74c3c')
                self.root.after(3000, lambda: self.update_status("Ready", '#2ecc71'))
        
        except Exception as e:
            print(f"❌ Error: {e}")
            self.update_status(f"❌ Error: {str(e)[:30]}", '#e74c3c')
            self.is_recording = False
            self.root.after(0, lambda: self.record_btn.config(
                text="🎤 START RECORDING",
                bg='#27ae60',
                activebackground='#229954'
            ))
            self.root.after(3000, lambda: self.update_status("Ready", '#2ecc71'))
    
    def type_text(self, text):
        """Type text at cursor position"""
        try:
            time.sleep(0.3)
            
            # For Hindi or Unicode, use clipboard
            if self.config['language'] == 'hi-IN' or any(ord(c) > 127 for c in text):
                pyperclip.copy(text)
                print("📋 Copied to clipboard...")
                time.sleep(0.1)
                pyautogui.hotkey('ctrl', 'v')
                print("⌨️ Pasted!")
            else:
                # For English, direct typing
                pyautogui.write(text, interval=0.01)
                print("⌨️ Typed!")
            
            print(f"{'='*50}\n")
            
        except Exception as e:
            print(f"❌ Error typing: {e}")
    
    def update_status(self, message, color):
        """Update status label"""
        self.root.after(0, lambda: self.status_label.config(text=message, fg=color))
    
    def run(self):
        """Run the application"""
        print("\n" + "="*60)
        print("   ✨ SIMPLE VOICE TYPER (GUI VERSION) ✨")
        print("="*60)
        print("\n📱 HOW TO USE:")
        print("   1. Click 'START RECORDING' button")
        print("   2. Speak into your microphone")
        print("   3. Click 'STOP RECORDING' button")
        print("   4. Text will be typed automatically!")
        print("\n🌐 Click 'Toggle Language' to switch Hindi/English")
        print("="*60 + "\n")
        
        self.root.mainloop()

def main():
    try:
        app = SimpleVoiceTyper()
        app.run()
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
