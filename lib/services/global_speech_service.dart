import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class GlobalSpeechService extends ChangeNotifier {
  static final GlobalSpeechService _instance = GlobalSpeechService._internal();
  factory GlobalSpeechService() => _instance;
  GlobalSpeechService._internal();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isInitialized = false;
  String _currentText = '';
  String _currentLanguage = 'hi_IN';
  double _confidence = 0.0;
  
  // Computer sync settings
  bool _syncEnabled = false;
  String _computerUrl = 'http://192.168.4.231:8080';
  bool _isConnected = false;

  bool get isListening => _isListening;
  String get currentText => _currentText;
  double get confidence => _confidence;
  bool get syncEnabled => _syncEnabled;
  bool get isConnected => _isConnected;
  String get currentLanguage => _currentLanguage;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    _speech = stt.SpeechToText();
    await _loadSettings();
    
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _isInitialized = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
        onError: (error) {
          _isListening = false;
          notifyListeners();
        },
      );
    }
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _syncEnabled = prefs.getBool('sync_enabled') ?? false;
    _computerUrl = prefs.getString('computer_url') ?? 'http://192.168.4.231:8080';
    _currentLanguage = prefs.getString('speech_language') ?? 'hi_IN';
    notifyListeners();
  }

  Future<void> toggleLanguage() async {
    _currentLanguage = _currentLanguage == 'hi_IN' ? 'en_US' : 'hi_IN';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('speech_language', _currentLanguage);
    notifyListeners();
  }

  Future<void> toggleListening() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_isListening) {
      await _speech.stop();
      _isListening = false;
    } else {
      _isListening = true;
      await _speech.listen(
        onResult: (result) {
          _currentText = result.recognizedWords;
          _confidence = result.confidence;
          notifyListeners();
          
          // Send to computer if sync enabled AND final result
          if (_syncEnabled && result.finalResult) {
            _sendToComputer(_currentText);
          }
        },
        localeId: _currentLanguage,
        listenMode: stt.ListenMode.confirmation,
      );
    }
    notifyListeners();
  }

  Future<void> _sendToComputer(String text) async {
    if (!_syncEnabled || text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_computerUrl/receive_text'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true', // Bypass Ngrok warning
        },
        body: jsonEncode({
          'text': text,
          'language': _currentLanguage,
          'confidence': _confidence,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 3));

      _isConnected = response.statusCode == 200;
    } catch (e) {
      _isConnected = false;
    }
    notifyListeners();
  }

  void clearText() {
    _currentText = '';
    _confidence = 0.0;
    notifyListeners();
  }

  Future<void> updateSettings({
    bool? syncEnabled,
    String? computerUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    if (syncEnabled != null) {
      _syncEnabled = syncEnabled;
      await prefs.setBool('sync_enabled', syncEnabled);
    }
    
    if (computerUrl != null) {
      _computerUrl = computerUrl;
      await prefs.setString('computer_url', computerUrl);
    }
    
    notifyListeners();
  }

  void dispose() {
    _speech.stop();
    super.dispose();
  }
}
