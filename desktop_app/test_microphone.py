#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Microphone Test Script
Yeh script batayega ki kaun se microphones available hain
"""

import sys
import io

# Fix Windows console encoding
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import speech_recognition as sr

def test_microphones():
    """Test all available microphones"""
    print("\n" + "="*60)
    print("   🎤 MICROPHONE DETECTION TEST")
    print("="*60 + "\n")
    
    # List all microphones
    print("📋 Available Microphones:\n")
    mic_list = sr.Microphone.list_microphone_names()
    
    if not mic_list:
        print("❌ No microphones found!")
        print("\n💡 Solutions:")
        print("   1. Check if microphone is properly connected")
        print("   2. Check Windows Sound Settings")
        print("   3. Try using WO Mic app (mobile as microphone)")
        return
    
    for i, mic_name in enumerate(mic_list):
        print(f"   [{i}] {mic_name}")
    
    print("\n" + "="*60)
    print("✅ Default Microphone Test")
    print("="*60 + "\n")
    
    recognizer = sr.Recognizer()
    
    try:
        with sr.Microphone() as source:
            print("🔊 Adjusting for ambient noise... Please wait.")
            recognizer.adjust_for_ambient_noise(source, duration=1)
            
            print("\n✅ Microphone is working!")
            print("🎤 Speak something for 3 seconds to test...")
            print("   (Starting in 2 seconds...)\n")
            
            import time
            time.sleep(2)
            
            print("🎙️  LISTENING NOW... SPEAK!")
            audio = recognizer.listen(source, timeout=5, phrase_time_limit=5)
            
            print("🔄 Processing...")
            
            # Try to recognize
            try:
                text = recognizer.recognize_google(audio, language='en-US')
                print(f"\n✅ SUCCESS! Recognized: '{text}'")
                print("\n🎉 Your microphone is working perfectly!")
                
            except sr.UnknownValueError:
                print("\n⚠️  Could not understand audio")
                print("   But microphone is working! Just speak more clearly.")
                
            except sr.RequestError as e:
                print(f"\n❌ Error with Google Speech API: {e}")
                print("   Check your internet connection!")
                
    except Exception as e:
        print(f"\n❌ Error: {e}")
        print("\n💡 Possible Solutions:")
        print("   1. Check microphone permissions in Windows Settings")
        print("   2. Make sure microphone is not being used by another app")
        print("   3. Try using a different microphone")
    
    print("\n" + "="*60 + "\n")

if __name__ == '__main__':
    test_microphones()
    input("\nPress Enter to exit...")
