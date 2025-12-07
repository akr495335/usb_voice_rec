import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tts/services/floating_button_service.dart';

class SpeechToTextScreen extends StatefulWidget {
  const SpeechToTextScreen({Key? key}) : super(key: key);

  @override
  State<SpeechToTextScreen> createState() => _SpeechToTextScreenState();
}

class _SpeechToTextScreenState extends State<SpeechToTextScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _text = '';
  String _currentLanguage = 'hi_IN'; // Default to Hindi
  double _confidence = 0.0;
  List<String> _history = [];
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  
  // Computer sync settings
  bool _syncEnabled = false;
  String _computerUrl = 'http://192.168.1.100:8000'; // Default URL
  bool _isConnected = false;
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeSpeech();
    _loadSettings();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _syncEnabled = prefs.getBool('sync_enabled') ?? false;
      _computerUrl = prefs.getString('computer_url') ?? 'http://192.168.1.100:8000';
      _urlController.text = _computerUrl;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sync_enabled', _syncEnabled);
    await prefs.setString('computer_url', _computerUrl);
  }

  Future<void> _sendToComputer(String text) async {
    if (!_syncEnabled || text.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('$_computerUrl/receive_text'),
        headers: {
          'Content-Type': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
        body: jsonEncode({
          'text': text,
          'language': _currentLanguage,
          'confidence': _confidence,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() => _isConnected = true);
      } else {
        setState(() => _isConnected = false);
      }
    } catch (e) {
      setState(() => _isConnected = false);
      print('Failed to send to computer: $e');
    }
  }

  Future<void> _testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$_computerUrl/ping'),
        headers: {'ngrok-skip-browser-warning': 'true'},
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        setState(() => _isConnected = true);
        _showSnackBar('✅ Connected to computer!');
      } else {
        setState(() => _isConnected = false);
        _showSnackBar('❌ Connection failed');
      }
    } catch (e) {
      setState(() => _isConnected = false);
      _showSnackBar('❌ Cannot reach computer');
    }
  }

  Future<void> _initializeSpeech() async {
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
            });
          }
        },
        onError: (error) {
          setState(() {
            _isListening = false;
          });
          _showSnackBar('Error: ${error.errorMsg}');
        },
      );

      if (!available) {
        _showSnackBar('Speech recognition not available');
      }
    } else {
      _showSnackBar('Microphone permission denied');
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _text = result.recognizedWords;
              _confidence = result.confidence;
            });
            // Send to computer ONLY when final result is available
            if (result.finalResult) {
              _sendToComputer(_text);
            }
          },
          localeId: _currentLanguage,
          listenMode: stt.ListenMode.confirmation,
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _saveToHistory() {
    if (_text.isNotEmpty) {
      setState(() {
        _history.insert(0, _text);
        if (_history.length > 20) {
          _history.removeLast();
        }
      });
      _showSnackBar('Saved to history');
    }
  }

  void _copyToClipboard() {
    if (_text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _text));
      _showSnackBar('Copied to clipboard');
    }
  }

  void _clearText() {
    setState(() {
      _text = '';
      _confidence = 0.0;
    });
    _sendToComputer(''); // Clear on computer too
  }

  void _toggleLanguage() {
    setState(() {
      _currentLanguage = _currentLanguage == 'hi_IN' ? 'en_US' : 'hi_IN';
    });
    _showSnackBar(
        'Language: ${_currentLanguage == 'hi_IN' ? 'Hindi' : 'English'}');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Computer Sync Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text('Enable Computer Sync'),
              subtitle: const Text('Send text to computer in real-time'),
              value: _syncEnabled,
              onChanged: (value) {
                setState(() => _syncEnabled = value);
                _saveSettings();
                Navigator.pop(context);
                _showSettingsDialog();
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Computer URL',
                hintText: 'http://192.168.1.100:8000',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () {
                    setState(() {
                      _computerUrl = _urlController.text;
                    });
                    _saveSettings();
                    _testConnection();
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? 'Connected' : 'Not Connected',
                  style: TextStyle(
                    color: _isConnected ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: _testConnection,
            child: const Text('Test Connection'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _speech.stop();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Speech to Text',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
        actions: [
          // Sync Status Indicator
          if (_syncEnabled)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isConnected ? Colors.green : Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isConnected ? Icons.cloud_done : Icons.cloud_off,
                        size: 16,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isConnected ? 'PC' : 'OFF',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () async {
              await FloatingButtonService.init();
              await FloatingButtonService.showFloatingButton();
              _showSnackBar('Floating Button Enabled! Close app to use.');
            },
            tooltip: 'Enable Floating Button',
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _currentLanguage == 'hi_IN' ? 'हिं' : 'EN',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            onPressed: _toggleLanguage,
            tooltip: 'Toggle Language',
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: 'Settings',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple,
              Colors.deepPurple.shade300,
              Colors.purple.shade100,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main Text Display Area
              Expanded(
                flex: 3,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recognized Text',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          if (_confidence > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _confidence > 0.8
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(_confidence * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _confidence > 0.8
                                      ? Colors.green.shade700
                                      : Colors.orange.shade700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _text.isEmpty
                                ? 'Tap the microphone to start speaking...'
                                : _text,
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.5,
                              color: _text.isEmpty
                                  ? Colors.grey.shade400
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(
                            icon: Icons.copy,
                            label: 'Copy',
                            onPressed: _copyToClipboard,
                            color: Colors.blue,
                          ),
                          _buildActionButton(
                            icon: Icons.save,
                            label: 'Save',
                            onPressed: _saveToHistory,
                            color: Colors.green,
                          ),
                          _buildActionButton(
                            icon: Icons.clear,
                            label: 'Clear',
                            onPressed: _clearText,
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Microphone Button
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: GestureDetector(
                  onTap: _listen,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _pulseAnimation.value : 1.0,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: _isListening
                                  ? [Colors.red.shade400, Colors.red.shade700]
                                  : [
                                      Colors.deepPurple.shade400,
                                      Colors.deepPurple.shade700
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                        ? Colors.red
                                        : Colors.deepPurple)
                                    .withOpacity(0.4),
                                blurRadius: 20,
                                spreadRadius: _isListening ? 10 : 5,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Text(
                _isListening ? 'Listening...' : 'Tap to speak',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // History Section
              if (_history.isNotEmpty)
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _history.clear();
                                });
                              },
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _history.length,
                            itemBuilder: (context, index) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  dense: true,
                                  title: Text(
                                    _history[index],
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _history[index]),
                                      );
                                      _showSnackBar('Copied to clipboard');
                                    },
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _text = _history[index];
                                    });
                                    _sendToComputer(_text);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
