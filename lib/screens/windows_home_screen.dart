import 'package:flutter/material.dart';
import 'package:tts/services/windows_server_service.dart';

class WindowsHomeScreen extends StatefulWidget {
  const WindowsHomeScreen({super.key});

  @override
  State<WindowsHomeScreen> createState() => _WindowsHomeScreenState();
}

class _WindowsHomeScreenState extends State<WindowsHomeScreen> {
  final WindowsServerService _serverService = WindowsServerService();
  String _status = "Stopped";
  String _ipInfo = "Click Start to generate connection URL";
  final List<String> _logs = [];
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
  }

  void _toggleServer() async {
    if (_isRunning) {
      await _serverService.stopServer();
      setState(() {
        _isRunning = false;
        _status = "Stopped";
        _ipInfo = "Server stopped";
      });
    } else {
      setState(() {
        _status = "Starting...";
      });
      String url = await _serverService.startServer((log) {
        setState(() {
          _logs.insert(0, "${DateTime.now().hour}:${DateTime.now().minute}: $log");
          if (_logs.length > 50) _logs.removeLast();
        });
      });
      setState(() {
        _isRunning = true;
        _status = "Running";
        _ipInfo = url;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          // Left Panel: Controls
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(32),
              color: Colors.grey.shade100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Magic Typer PC",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Mobile to PC Typing Server",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 50),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "CONNECTION URL",
                          style: TextStyle(
                            color: Colors.tealAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          _ipInfo,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _toggleServer,
                      icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(_isRunning ? "STOP SERVER" : "START SERVER"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRunning ? Colors.red : Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right Panel: Logs
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Activity Log",
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                color: Colors.greenAccent,
                                fontFamily: 'Consolas',
                                fontSize: 14,
                              ),
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
