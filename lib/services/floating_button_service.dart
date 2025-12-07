import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FloatingButtonService {
  
  static Future<void> init() async {
    bool status = await FlutterOverlayWindow.isPermissionGranted();
    if (!status) {
      await FlutterOverlayWindow.requestPermission();
    }
  }

  static Future<void> showFloatingButton() async {
    if (await FlutterOverlayWindow.isActive()) return;
    
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "Magic Typer",
      overlayContent: "Tap to speak",
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.right,
      height: 200,
      width: 200,
    );
  }
}
