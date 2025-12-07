import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart' as shelf;
import 'dart:convert';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1000, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Voice Typer - PC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const ReceiverScreen(),
    );
  }
}

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> with WindowListener, TrayListener {
  HttpServer? _server;
  final int _port = 8080;
  bool _isRunning = false;
  String _latestText = '';
  final List<String> _textHistory = [];
  String _status = 'Click START to begin';
  bool _isMinimized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    trayManager.addListener(this);
    _initSystemTray();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    trayManager.removeListener(this);
    _stopServer();
    super.dispose();
  }

  // Commented out - app stays in taskbar when minimized
  // @override
  // void onWindowMinimize() {
  //   windowManager.hide();
  //   setState(() {
  //     _isMinimized = true;
  //   });
  // }

  @override
  void onTrayIconMouseDown() {
    _showWindow();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  Future<void> _initSystemTray() async {
    try {
      await trayManager.setIcon(
        Platform.isWindows
            ? 'windows/runner/resources/app_icon.ico'
            : 'assets/app_icon.png',
      );
      
      Menu menu = Menu(
        items: [
          MenuItem(
            key: 'show_window',
            label: 'Show Window',
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'exit',
            label: 'Exit',
          ),
        ],
      );
      await trayManager.setContextMenu(menu);
      await trayManager.setToolTip('USB Voice Typer');
    } catch (e) {
      print('System tray init error: $e');
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show_window') {
      _showWindow();
    } else if (menuItem.key == 'exit') {
      _exitApp();
    }
  }

  void _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
    setState(() {
      _isMinimized = false;
    });
  }

  void _exitApp() {
    windowManager.destroy();
    exit(0);
  }

  Future<void> _startServer() async {
    try {
      final router = shelf.Router();

      router.post('/receive_text', (Request request) async {
        final content = await request.readAsString();
        final data = jsonDecode(content);
        final text = data['text'] ?? '';

        if (text.isNotEmpty) {
          setState(() {
            _latestText = text;
            _textHistory.insert(0, text);
            if (_textHistory.length > 50) _textHistory.removeLast();
            _status = 'Received: ${DateTime.now().hour}:${DateTime.now().minute}:${DateTime.now().second}';
          });

          // Auto paste
          await _pasteText(text);
        }

        return Response.ok(
          jsonEncode({'status': 'success'}),
          headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        );
      });

      router.get('/ping', (Request request) {
        return Response.ok(
          jsonEncode({'status': 'ok'}),
          headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        );
      });

      router.get('/get_latest_text', (Request request) {
        return Response.ok(
          jsonEncode({'text': _latestText}),
          headers: {'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*'},
        );
      });

      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, _port);

      setState(() {
        _isRunning = true;
        _status = 'Server running on port $_port';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
      });
    }
  }

  Future<void> _stopServer() async {
    await _server?.close();
    setState(() {
      _isRunning = false;
      _status = 'Server stopped';
    });
  }

  Future<void> _pasteText(String text) async {
    try {
      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: text));
      
      // Simulate Ctrl+V using PowerShell
      await Process.run('powershell', [
        '-c',
        '\$wshell = New-Object -ComObject wscript.shell; \$wshell.SendKeys(\'^v\')'
      ]);
    } catch (e) {
      print('Paste error: $e');
    }
  }

  void _clearHistory() {
    setState(() {
      _textHistory.clear();
      _latestText = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Row(
        children: [
          // Left Panel - Controls
          Container(
            width: 350,
            color: Colors.deepPurple.shade700,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'USB Voice Typer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'PC Receiver',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 40),
                
                // Status
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: _isRunning ? Colors.green.shade700 : Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _isRunning ? Icons.check_circle : Icons.pending,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _status,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Start/Stop Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isRunning ? _stopServer : _startServer,
                    icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                    label: Text(_isRunning ? 'STOP SERVER' : 'START SERVER'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRunning ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Clear Button
                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: OutlinedButton.icon(
                    onPressed: _clearHistory,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Clear History'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // Instructions
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How to Use:',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        '1. Click START SERVER\n2. Connect phone via USB\n3. Open mobile app\n4. Speak into phone\n5. Text will auto-paste!',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Right Panel - Display
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Latest Text
                  const Text(
                    'Latest Text',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.deepPurple.shade200, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: Text(
                      _latestText.isEmpty ? 'Waiting for voice input...' : _latestText,
                      style: TextStyle(
                        fontSize: 24,
                        color: _latestText.isEmpty ? Colors.grey : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // History
                  const Text(
                    'History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: _textHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No history yet',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(15),
                              itemCount: _textHistory.length,
                              separatorBuilder: (context, index) => const Divider(),
                              itemBuilder: (context, index) {
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepPurple.shade100,
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        color: Colors.deepPurple.shade700,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    _textHistory[index],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.copy, size: 20),
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: _textHistory[index]));
                                    },
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
