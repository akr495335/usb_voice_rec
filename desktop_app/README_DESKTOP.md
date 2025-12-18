# Windows Desktop Voice Typer

## 🎯 Overview
Windows Desktop Voice Typer एक Python-based application है जो USB microphone से voice input लेकर किसी भी application में text type करता है।

## ✨ Features
- 🎤 **USB Microphone Support** - किसी भी USB mic से काम करता है
- 🌐 **Dual Language** - Hindi (हिंदी) और English दोनों support
- ⌨️ **System-wide Typing** - किसी भी application में जहाँ cursor है वहीं type होगा
- 🔥 **Global Hotkeys** - keyboard shortcuts से control करें
- 🖥️ **System Tray** - background में चलता है
- 👁️ **Visual Indicator** - recording होने पर दिखता है

## 📋 Requirements
- Windows 10/11
- Python 3.8 या उससे ऊपर
- USB Microphone
- Internet connection (Google Speech API के लिए)

## 🚀 Installation

### Step 1: Python Install करें
अगर Python installed नहीं है तो [python.org](https://www.python.org/downloads/) से download करें।

### Step 2: Dependencies Install करें
```bash
cd e:\Project\Folder_Master\usb_voice_rec\desktop_app
pip install -r requirements.txt
```

**Important:** अगर `pyaudio` install करने में problem आए तो:
```bash
pip install pipwin
pipwin install pyaudio
```

### Step 3: Application चलाएं
```bash
python voice_typer_app.py
```

## 🎮 How to Use

### Basic Usage
1. Application start करें - System tray में microphone icon दिखेगा
2. किसी भी application में cursor रखें (Notepad, Word, Browser, etc.)
3. **Ctrl+Shift+Space** दबाएं - Recording शुरू होगी
4. Microphone में बोलें
5. फिर से **Ctrl+Shift+Space** दबाएं - Recording बंद होगी
6. Text automatically type हो जाएगा! ✨

### Language Toggle
- **Ctrl+Shift+L** दबाएं - Hindi ↔ English switch होगा
- या System tray icon पर right-click करके "Toggle Language" select करें

### System Tray Menu
System tray में microphone icon पर **right-click** करें:
- **Current Language** - वर्तमान भाषा देखें
- **Toggle Language** - भाषा बदलें
- **About** - Application के बारे में
- **Exit** - Application बंद करें

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Shift+Space` | Start/Stop Recording |
| `Ctrl+Shift+L` | Toggle Language (Hindi ↔ English) |

## 🔧 Configuration

`config.json` file में settings change कर सकते हैं:

```json
{
  "language": "en-US",           // "hi-IN" for Hindi
  "hotkey_record": "ctrl+shift+space",
  "hotkey_language_toggle": "ctrl+shift+l",
  "auto_send": true,
  "show_notifications": true
}
```

## 🌐 Supported Languages

- **English** - `en-US`
- **हिंदी (Hindi)** - `hi-IN`

## 📝 Examples

### English में Type करना
1. Language को English में set करें (Ctrl+Shift+L)
2. Notepad खोलें
3. Ctrl+Shift+Space दबाएं
4. बोलें: "Hello this is a test message"
5. Ctrl+Shift+Space दबाएं
6. Text type हो जाएगा! ✅

### Hindi में Type करना
1. Language को Hindi में set करें (Ctrl+Shift+L)
2. किसी भी application में cursor रखें
3. Ctrl+Shift+Space दबाएं
4. बोलें: "नमस्ते यह एक टेस्ट मैसेज है"
5. Ctrl+Shift+Space दबाएं
6. Hindi text type हो जाएगा! ✅

## 🐛 Troubleshooting

### Microphone Detect नहीं हो रहा
- USB microphone properly connected है check करें
- Windows Settings → Privacy → Microphone में permission दें
- Default microphone set करें (Windows Sound Settings)

### Speech Recognition काम नहीं कर रहा
- Internet connection check करें (Google API चाहिए)
- Clearly बोलें, background noise कम रखें
- Microphone के पास से बोलें

### Hindi Text Type नहीं हो रहा
- Application Unicode support करता है check करें
- Notepad, Word, Browser में काम करेगा
- कुछ old applications में problem हो सकती है

### Hotkeys काम नहीं कर रहे
- Administrator mode में run करें
- किसी और application में same hotkey use नहीं हो रहा check करें

## 💡 Tips
- 🎤 Clear और धीरे बोलें for better accuracy
- 🔇 Background noise कम रखें
- 📶 Stable internet connection रखें
- 🎯 Short sentences बोलें (15 seconds से कम)

## 🆘 Support
Issues या questions के लिए GitHub repository पर issue create करें।

## 📄 License
MIT License

---

**Made with ❤️ for easy voice typing in Hindi and English!**
