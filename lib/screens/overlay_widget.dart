import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _computerUrl = 'http://192.168.1.100:8000'; // Default, will update

  @override
  void initState() {
    super.initState();
    _loadSettings();
    // Listen for messages from main app if needed
    FlutterOverlayWindow.overlayListener.listen((event) {
        if (event is String) {
           // Handle updates
        }
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _computerUrl = prefs.getString('computer_url') ?? _computerUrl;
    });
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
           if (status == 'notListening') {
             setState(() => _isListening = false);
           }
        },
        onError: (error) => setState(() => _isListening = false),
      );
      
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            if (result.finalResult) {
               _sendToComputer(result.recognizedWords);
            }
          },
          listenMode: stt.ListenMode.confirmation,
        );
      }
    }
  }

  Future<void> _sendToComputer(String text) async {
    try {
      await http.post(
        Uri.parse('$_computerUrl/receive_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
    } catch (e) {
      print("Error sending: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Magic Typer",
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
              SizedBox(height: 5),
              GestureDetector(
                onTap: _toggleListening,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: _isListening ? Colors.red : Colors.deepPurple,
                  child: Icon(
                    _isListening ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              SizedBox(height: 5),
              GestureDetector(
                onTap: () async {
                   await FlutterOverlayWindow.closeOverlay();
                },
                child: Text(
                  "Close",
                  style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
