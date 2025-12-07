import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';

class OverlayScreen extends StatefulWidget {
  const OverlayScreen({super.key});

  @override
  State<OverlayScreen> createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  final String _serverUrl = 'http://127.0.0.1:8080';

  @override
  void initState() {
    super.initState();
    _speech.initialize();
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            _sendToPC(result.recognizedWords);
          }
        },
        listenMode: stt.ListenMode.confirmation,
      );
    }
  }

  Future<void> _sendToPC(String text) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/receive_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 2));
    } catch (e) {
      print('Send error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: GestureDetector(
          onTap: _toggleListening,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: _isListening ? Colors.red : Colors.deepPurple,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _isListening ? Colors.red.shade300 : Colors.deepPurple.shade300,
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: Colors.white,
              size: 60,
            ),
          ),
        ),
      ),
    );
  }
}
