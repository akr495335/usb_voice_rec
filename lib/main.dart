import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Voice Typer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const VoiceTyperScreen(),
    );
  }
}

class VoiceTyperScreen extends StatefulWidget {
  const VoiceTyperScreen({super.key});

  @override
  State<VoiceTyperScreen> createState() => _VoiceTyperScreenState();
}

class _VoiceTyperScreenState extends State<VoiceTyperScreen> with WidgetsBindingObserver {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = '';
  String _status = 'Ready';
  bool _isHindi = true; // true = Hindi, false = English
  bool _isConnected = false;
  bool _isMinimizedMode = true; // Default: start in minimized mode
  Timer? _connectionCheckTimer;
  final String _serverUrl = 'http://127.0.0.1:8080';

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    WidgetsBinding.instance.addObserver(this);
    _startConnectionCheck();
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep speech recognition running even when app is in background
    if (state == AppLifecycleState.paused && _isListening) {
      print('App in background but listening continues');
    }
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  void _startConnectionCheck() {
    _checkConnection(); // Check immediately
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _checkConnection();
    });
  }

  Future<void> _checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_serverUrl/ping'),
      ).timeout(const Duration(seconds: 1));
      
      setState(() {
        _isConnected = response.statusCode == 200;
      });
    } catch (e) {
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        _status = 'Stopped';
      });
    } else {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'notListening') {
            setState(() {
              _isListening = false;
              _status = 'Ready';
            });
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
            _status = 'Error';
          });
        },
      );

      if (available) {
        setState(() {
          _isListening = true;
          _status = 'Listening...';
        });
        
        _speech.listen(
          onResult: (result) {
            setState(() => _text = result.recognizedWords);
            
            if (result.finalResult) {
              _sendToPC(result.recognizedWords);
            }
          },
          listenMode: stt.ListenMode.confirmation,
          localeId: _isHindi ? 'hi_IN' : 'en_US', // Set language
        );
      } else {
        setState(() => _status = 'Not available');
      }
    }
  }

  Future<void> _sendToPC(String text) async {
    try {
      await http.post(
        Uri.parse('$_serverUrl/receive_text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      ).timeout(const Duration(seconds: 2));
      setState(() => _status = 'Sent to PC!');
    } catch (e) {
      setState(() => _status = 'Connection failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _isMinimizedMode
            ? _buildMinimizedView()
            : _buildFullView(),
      ),
    );
  }

  // Minimized view - only Speak button
  Widget _buildMinimizedView() {
    return Stack(
      children: [
        // Mic Button at bottom
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : Colors.deepPurple).withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
        ),
        
        // Expand button in top-right corner
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isMinimizedMode = false;
              });
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Full view - all UI elements
  Widget _buildFullView() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top bar with status and language button
          Row(
            children: [
              // Status
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: _isListening ? Colors.red.withOpacity(0.2) : Colors.white10,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(
                      color: _isListening ? Colors.red : Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Connection indicator
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _isConnected ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (_isConnected ? Colors.green : Colors.red).withOpacity(0.6),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _isListening ? Colors.red : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 15),
              
              // Language toggle button (E/H)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isHindi = !_isHindi;
                    _status = _isHindi ? 'Hindi Mode' : 'English Mode';
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isHindi ? Colors.orange : Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isHindi ? Colors.orangeAccent : Colors.blueAccent,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (_isHindi ? Colors.orange : Colors.blue).withOpacity(0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _isHindi ? 'H' : 'E',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 15),
              
              // Minimize button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isMinimizedMode = true;
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white30,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.fullscreen_exit,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 30),
          
          // Text Display - grows with content
          _text.isNotEmpty
              ? Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 100,
                    maxHeight: 500,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _text,
                      style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                  ),
                )
              : Container(
                  width: double.infinity,
                  height: 100,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      'Tap mic to start...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white38,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
          
          const Spacer(),
          
          const SizedBox(height: 30),
          
          // Mic Button at bottom - centered
          Center(
            child: GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _isListening ? Colors.red : Colors.deepPurple,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : Colors.deepPurple).withOpacity(0.6),
                      blurRadius: 30,
                      spreadRadius: 5,
                    )
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
