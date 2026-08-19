import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionHelper {
  static Future<bool> requestPermissionWithRationale({
    required BuildContext context,
    required Permission permission,
    required String title,
    required String rationale,
  }) async {
    var status = await permission.status;
    if (status.isGranted) return true;

    if (status.isDenied || status.isLimited) {
      if (!context.mounted) return false;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF004D40))),
          content: Text(rationale, style: const TextStyle(fontSize: 13, height: 1.4)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Allow Access'),
            ),
          ],
        ),
      );

      if (proceed != true) return false;
      status = await permission.request();
      return status.isGranted;
    }

    if (status.isPermanentlyDenied) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enable $title in App Settings to proceed.'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return false;
    }

    return false;
  }
}
