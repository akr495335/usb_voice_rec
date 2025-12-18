#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Windows Desktop Voice Typer
USB Microphone se bolo -> Computer me type ho jayega!
Hindi aur English dono support karta hai
"""

import sys
import os
import io

# Fix Windows console encoding for Unicode characters
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')
import json
import threading
import time
import tkinter as tk
from tkinter import messagebox
import speech_recognition as sr
import pyautogui
import pyperclip
from pystray import Icon, Menu, MenuItem
from PIL import Image
import keyboard

# Configuration file path
CONFIG_FILE = os.path.join(os.path.dirname(__file__), 'config.json')
ICON_FILE = os.path.join(os.path.dirname(__file__), 'icon.png')

class VoiceTyperApp:
    def __init__(self):
        self.recognizer = sr.Recognizer()
        self.microphone = sr.Microphone()
        self.is_recording = False
        self.recording_thread = None
        self.indicator_window = None
        
        # Load configuration
        self.load_config()
        
        # Language settings
        self.languages = {
            'en-US': 'English',
            'hi-IN': 'हिंदी'
        }
        
        # Adjust recognizer settings for better accuracy
        self.recognizer.energy_threshold = 4000
        self.recognizer.dynamic_energy_threshold = True
        self.recognizer.pause_threshold = 0.8
        
        # Setup system tray icon
        self.setup_tray_icon()
        
        # Register global hotkeys
        self.register_hotkeys()
        
        print("✅ Voice Typer Started!")
        print(f"📢 Current Language: {self.languages[self.config['language']]}")
        print(f"⌨️  Hotkey to Record: {self.config['hotkey_record']}")
        print(f"🌐 Hotkey to Toggle Language: {self.config['hotkey_language_toggle']}")
    
    def load_config(self):
        """Load configuration from JSON file"""
        try:
            with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
                self.config = json.load(f)
        except FileNotFoundError:
            # Default configuration
            self.config = {
                'language': 'en-US',
                'hotkey_record': 'ctrl+shift+space',
                'hotkey_language_toggle': 'ctrl+shift+l',
                'auto_send': True,
                'show_notifications': True
            }
            self.save_config()
    
    def save_config(self):
        """Save configuration to JSON file"""
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(self.config, f, indent=2, ensure_ascii=False)
    
    def toggle_language(self):
        """Toggle between Hindi and English"""
        if self.config['language'] == 'en-US':
            self.config['language'] = 'hi-IN'
        else:
            self.config['language'] = 'en-US'
        
        self.save_config()
        lang_name = self.languages[self.config['language']]
        print(f"🌐 Language changed to: {lang_name}")
        
        if self.config['show_notifications']:
            self.show_notification(f"Language: {lang_name}")
        
        # Update tray icon menu
        self.update_tray_menu()
    
    def show_notification(self, message):
        """Show a temporary notification window"""
        notification = tk.Tk()
        notification.title("Voice Typer")
        notification.attributes('-topmost', True)
        notification.geometry("250x80+{}+{}".format(
            notification.winfo_screenwidth() - 270,
            notification.winfo_screenheight() - 120
        ))
        
        label = tk.Label(notification, text=message, font=('Arial', 12, 'bold'))
        label.pack(expand=True)
        
        notification.after(2000, notification.destroy)
        notification.mainloop()
    
    def show_recording_indicator(self):
        """Show visual indicator when recording"""
        self.indicator_window = tk.Tk()
        self.indicator_window.title("Recording...")
        self.indicator_window.attributes('-topmost', True)
        self.indicator_window.configure(bg='#ff4444')
        
        # Position at top-right corner
        window_width = 200
        window_height = 60
        screen_width = self.indicator_window.winfo_screenwidth()
        x_position = screen_width - window_width - 20
        y_position = 20
        
        self.indicator_window.geometry(f"{window_width}x{window_height}+{x_position}+{y_position}")
        
        # Recording label
        label = tk.Label(
            self.indicator_window,
            text="🎤 Recording...",
            font=('Arial', 14, 'bold'),
            bg='#ff4444',
            fg='white'
        )
        label.pack(expand=True)
        
        # Pulsing effect
        def pulse():
            if self.is_recording and self.indicator_window:
                current_bg = self.indicator_window.cget('bg')
                new_bg = '#ff6666' if current_bg == '#ff4444' else '#ff4444'
                self.indicator_window.configure(bg=new_bg)
                label.configure(bg=new_bg)
                self.indicator_window.after(500, pulse)
        
        pulse()
        self.indicator_window.mainloop()
    
    def hide_recording_indicator(self):
        """Hide recording indicator"""
        if self.indicator_window:
            try:
                self.indicator_window.destroy()
                self.indicator_window = None
            except:
                pass
    
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
        print("\n🎤 Recording started... Speak now!")
        
        # Show indicator in separate thread
        indicator_thread = threading.Thread(target=self.show_recording_indicator, daemon=True)
        indicator_thread.start()
        
        # Start recording in separate thread
        self.recording_thread = threading.Thread(target=self.record_and_type, daemon=True)
        self.recording_thread.start()
    
    def stop_recording(self):
        """Stop voice recording"""
        if not self.is_recording:
            return
        
        self.is_recording = False
        print("⏹️  Recording stopped!")
        self.hide_recording_indicator()
    
    def record_and_type(self):
        """Record audio and convert to text, then type it"""
        try:
            with self.microphone as source:
                # Adjust for ambient noise
                print("🔊 Adjusting for ambient noise... Please wait.")
                self.recognizer.adjust_for_ambient_noise(source, duration=0.5)
                
                print("✅ Listening...")
                # Listen for audio
                audio = self.recognizer.listen(source, timeout=10, phrase_time_limit=15)
            
            # Stop recording after audio is captured
            self.is_recording = False
            self.hide_recording_indicator()
            
            print("🔄 Processing speech...")
            
            # Recognize speech using Google Speech Recognition
            try:
                text = self.recognizer.recognize_google(
                    audio,
                    language=self.config['language']
                )
                
                print(f"✅ Recognized: {text}")
                
                # Type the text at cursor position
                self.type_text(text)
                
            except sr.UnknownValueError:
                print("❌ Could not understand audio")
                if self.config['show_notifications']:
                    threading.Thread(
                        target=self.show_notification,
                        args=("Could not understand audio",),
                        daemon=True
                    ).start()
            except sr.RequestError as e:
                print(f"❌ Error with speech recognition service: {e}")
                if self.config['show_notifications']:
                    threading.Thread(
                        target=self.show_notification,
                        args=("Speech recognition error",),
                        daemon=True
                    ).start()
        
        except Exception as e:
            print(f"❌ Error during recording: {e}")
            self.is_recording = False
            self.hide_recording_indicator()
    
    def type_text(self, text):
        """Type text at current cursor position"""
        try:
            # Small delay to ensure cursor is ready
            time.sleep(0.2)
            
            # For Hindi and special characters, use clipboard method
            if self.config['language'] == 'hi-IN' or any(ord(c) > 127 for c in text):
                # Copy to clipboard
                pyperclip.copy(text)
                print("📋 Copied to clipboard...")
                
                # Paste using Ctrl+V
                time.sleep(0.1)
                pyautogui.hotkey('ctrl', 'v')
                print("⌨️  Pasted!")
            else:
                # For English, direct typing is faster
                pyautogui.write(text, interval=0.01)
                print("⌨️  Typed!")
            
            print(f"{'='*50}\n")
            
        except Exception as e:
            print(f"❌ Error typing text: {e}")
    
    def register_hotkeys(self):
        """Register global hotkeys"""
        try:
            # Register recording hotkey
            keyboard.add_hotkey(
                self.config['hotkey_record'],
                self.toggle_recording,
                suppress=False
            )
            
            # Register language toggle hotkey
            keyboard.add_hotkey(
                self.config['hotkey_language_toggle'],
                self.toggle_language,
                suppress=False
            )
            
            print("✅ Hotkeys registered successfully!")
        except Exception as e:
            print(f"❌ Error registering hotkeys: {e}")
    
    def setup_tray_icon(self):
        """Setup system tray icon"""
        try:
            # Load icon image
            if os.path.exists(ICON_FILE):
                icon_image = Image.open(ICON_FILE)
            else:
                # Create a simple icon if file doesn't exist
                icon_image = Image.new('RGB', (64, 64), color='blue')
            
            # Create menu
            self.tray_menu = self.create_tray_menu()
            
            # Create icon
            self.tray_icon = Icon(
                "VoiceTyper",
                icon_image,
                "Voice Typer - " + self.languages[self.config['language']],
                self.tray_menu
            )
            
            # Run icon in separate thread
            icon_thread = threading.Thread(target=self.tray_icon.run, daemon=True)
            icon_thread.start()
            
        except Exception as e:
            print(f"❌ Error setting up tray icon: {e}")
    
    def create_tray_menu(self):
        """Create system tray menu"""
        current_lang = self.languages[self.config['language']]
        
        return Menu(
            MenuItem(f"Current: {current_lang}", lambda: None, enabled=False),
            MenuItem("Toggle Language (Ctrl+Shift+L)", self.toggle_language),
            MenuItem("About", self.show_about),
            MenuItem("Exit", self.exit_app)
        )
    
    def update_tray_menu(self):
        """Update tray menu when language changes"""
        try:
            self.tray_icon.menu = self.create_tray_menu()
            current_lang = self.languages[self.config['language']]
            self.tray_icon.title = "Voice Typer - " + current_lang
        except Exception as e:
            print(f"Error updating tray menu: {e}")
    
    def show_about(self):
        """Show about dialog"""
        about_text = """
Windows Desktop Voice Typer
Version 1.0

USB Microphone se bolo -> Computer me type ho jayega!

Hotkeys:
• Ctrl+Shift+Space - Start/Stop Recording
• Ctrl+Shift+L - Toggle Language

Supported Languages:
• English
• हिंदी (Hindi)
        """
        
        root = tk.Tk()
        root.withdraw()
        messagebox.showinfo("About Voice Typer", about_text)
        root.destroy()
    
    def exit_app(self):
        """Exit the application"""
        print("\n👋 Exiting Voice Typer...")
        try:
            keyboard.unhook_all()
            if self.tray_icon:
                self.tray_icon.stop()
        except:
            pass
        os._exit(0)
    
    def run(self):
        """Run the application"""
        print("\n" + "="*60)
        print("   ✨ WINDOWS DESKTOP VOICE TYPER ✨")
        print("="*60)
        print("\n📱 HOW TO USE:")
        print(f"   1. Press {self.config['hotkey_record']} to start recording")
        print("   2. Speak into your USB microphone")
        print(f"   3. Press {self.config['hotkey_record']} again to stop")
        print("   4. Text will be typed at cursor position!")
        print(f"\n🌐 Press {self.config['hotkey_language_toggle']} to toggle language")
        print("="*60 + "\n")
        
        # Keep the main thread alive
        try:
            keyboard.wait()
        except KeyboardInterrupt:
            self.exit_app()

def main():
    """Main entry point"""
    try:
        app = VoiceTyperApp()
        app.run()
    except Exception as e:
        print(f"❌ Fatal error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == '__main__':
    main()
