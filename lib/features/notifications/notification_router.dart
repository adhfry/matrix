import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app.dart';
import '../leave/ui/leave_screen.dart';
import '../shell/home_shell.dart';
import 'ui/notifications_screen.dart';

/// Buka tujuan notifikasi. [route] dari server, mis. "jaspel?month=09-2026",
/// "schedule?month=2026-11", "attendance", "leave", "chat?conversation=5".
/// Chat dibuka di SiLAKES web ([webUrl]); tujuan tak dikenal -> kotak masuk.
/// [goTab] memindah tab beranda (dari layanan maupun widget).
Future<void> openNotificationRoute({
  required void Function(int tab) goTab,
  String? route,
  String? webUrl,
  bool fromInbox = false,
}) async {
  final nav = rootNavigatorKey.currentState;
  if (nav == null) return;
  final path = Uri.tryParse(route ?? '')?.path ?? '';

  void toTab(int tab) {
    nav.popUntil((r) => r.isFirst);
    goTab(tab);
  }

  switch (path) {
    case 'jaspel':
      toTab(Tabs.kinerja);
    case 'schedule':
      toTab(Tabs.schedule);
    case 'attendance':
      toTab(Tabs.home);
    case 'leave':
      await nav.push(
        MaterialPageRoute<void>(builder: (_) => const LeaveScreen()),
      );
    case 'chat' when webUrl != null && webUrl.isNotEmpty:
      await launchUrl(Uri.parse(webUrl), mode: LaunchMode.externalApplication);
    default:
      if (!fromInbox) {
        await nav.push(
          MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
        );
      }
  }
}
