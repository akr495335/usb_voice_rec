import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'dart:convert';

class WindowsServerService {
  HttpServer? _server;
  final int _port = 8080;

  Future<String> startServer(Function(String) onLog) async {
    try {
      final router = Router();

      router.post('/receive_text', (Request request) async {
        final content = await request.readAsString();
        final data = jsonDecode(content);
        final text = data['text'];

        onLog("Received: $text");

        if (text != null && text.isNotEmpty) {
          await _handleText(text, onLog);
        }

        return Response.ok(jsonEncode({'status': 'success'}),
            headers: {'Content-Type': 'application/json'});
      });

      router.get('/ping', (Request request) {
        return Response.ok(jsonEncode({'status': 'ok'}),
            headers: {'Content-Type': 'application/json'});
      });

      // Listen on all interfaces (0.0.0.0) so mobile can connect
      _server = await shelf_io.serve(router, InternetAddress.anyIPv4, _port);
      
      String ip = await _getLocalIp();
      String url = "http://$ip:$_port";
      onLog("Server started at $url");
      return "Server running on $url";
    } catch (e) {
      onLog("Error starting server: $e");
      return "Error: $e";
    }
  }

  Future<void> stopServer() async {
    await _server?.close();
  }

  Future<String> _getLocalIp() async {
    try {
      // First try to find a non-loopback IPv4 address
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
             // Prefer addresses starting with 192.168 or 10. or 172.
             if (addr.address.startsWith('192.168.') || 
                 addr.address.startsWith('10.') || 
                 addr.address.startsWith('172.')) {
               return addr.address;
             }
          }
        }
      }
      
      // If no specific private IP found, return the first non-loopback IPv4
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
           if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
             return addr.address;
           }
        }
      }
    } catch (e) {
      print(e);
    }
    return "127.0.0.1";
  }

  Future<void> _handleText(String text, Function(String) onLog) async {
    // 1. Copy to Clipboard
    await Clipboard.setData(ClipboardData(text: text));
    onLog("Copied to clipboard");

    // 2. Simulate Ctrl+V using PowerShell
    // This is a robust way to simulate keystrokes on Windows without extra C++ plugins
    try {
      onLog("Pasting...");
      await Process.run('powershell', [
        '-c',
        '\$wshell = New-Object -ComObject wscript.shell; \$wshell.SendKeys(\'^v\')'
      ]);
      onLog("Pasted!");
    } catch (e) {
      onLog("Error pasting: $e");
    }
  }
}
