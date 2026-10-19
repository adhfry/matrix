import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/format/fmt.dart';
import '../../../core/push/push_service.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/notification_repository.dart';
import 'notification_style.dart';

final notificationPrefsProvider = FutureProvider.autoDispose<NotificationPrefs>(
  (ref) => ref.watch(notificationRepositoryProvider).prefs(),
);

/// Pengaturan notifikasi: satu sumber dengan SiLAKES web (diubah di sini =
/// berlaku juga di web). Tiap perubahan langsung disimpan.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  /// Salinan lokal agar sakelar langsung berpindah; dikembalikan bila gagal simpan.
  Map<String, bool>? _push;
  bool? _quiet;
  String? _quietStart;
  String? _quietEnd;
  PushPermission? _permission;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _readPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari Pengaturan Android: izin mungkin sudah berubah.
    if (state == AppLifecycleState.resumed) _readPermission();
  }

  Future<void> _readPermission() async {
    final p = await ref.read(pushServiceProvider).permission();
    if (mounted) setState(() => _permission = p);
  }

  Future<void> _save(Map<String, Object?> body, VoidCallback revert) async {
    try {
      await ref.read(notificationRepositoryProvider).savePrefs(body);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(revert);
      showMxSnack(context, e.message, tone: Tone.alert);
    }
  }

  void _toggle(String key, bool value) {
    final before = _push![key]!;
    setState(() => _push![key] = value);
    _save({
      'categories': {key: value},
    }, () => _push![key] = before);
  }

  void _toggleQuiet(bool value) {
    final before = _quiet;
    setState(() => _quiet = value);
    _save({'quiet_hours': value}, () => _quiet = before);
  }

  Future<void> _pickTime(bool start) async {
    final current =
        (start ? _quietStart : _quietEnd) ?? (start ? '21:00' : '05:30');
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
      helpText: start ? 'Jam tenang mulai' : 'Jam tenang selesai',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    final v =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    final before = start ? _quietStart : _quietEnd;
    setState(() => start ? _quietStart = v : _quietEnd = v);
    await _save({
      start ? 'quiet_start' : 'quiet_end': v,
    }, () => start ? _quietStart = before : _quietEnd = before);
  }

  Future<void> _enable() async {
    final ok = await ref.read(pushServiceProvider).requestPermission();
    await _readPermission();
    ref.invalidate(notificationPrefsProvider);
    if (!ok && mounted) {
      showMxSnack(
        context,
        'Izin notifikasi ditolak. Aktifkan lewat Pengaturan Android.',
        tone: Tone.pending,
      );
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final msg = await ref.read(notificationRepositoryProvider).sendTest();
      if (mounted) {
        showMxSnack(context, msg ?? 'Notifikasi uji dikirim.', tone: Tone.ok);
      }
    } on ApiException catch (e) {
      if (mounted) showMxSnack(context, e.message, tone: Tone.alert);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(notificationPrefsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan notifikasi')),
      body: prefs.when(
        loading: () => StateView.loading('Memuat pengaturan…'),
        error: (e, _) => StateView.error(
          e,
          onRetry: () => ref.invalidate(notificationPrefsProvider),
        ),
        data: (p) {
          _push ??= {for (final c in p.categories) c.key: c.push};
          _quiet ??= p.quietHours;
          _quietStart ??= p.quietStart;
          _quietEnd ??= p.quietEnd;
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Sp.gutter,
              Sp.sm,
              Sp.gutter,
              Sp.xxl,
            ),
            children: [
              _DeviceStatus(
                permission: _permission,
                testing: _testing,
                onEnable: _enable,
                onOpenSettings: openAppSettings,
                onTest: _test,
              ),
              if (p.devices.isNotEmpty) ...[
                const SizedBox(height: Sp.xl),
                const SectionTitle(
                  'Perangkat penerima',
                  subtitle: 'Notifikasi dikirim ke semua perangkat ini',
                ),
                MxCard(
                  padding: const EdgeInsets.symmetric(vertical: Sp.xs),
                  child: Column(
                    children: [for (final d in p.devices) _DeviceRow(d)],
                  ),
                ),
              ],
              const SizedBox(height: Sp.xl),
              const SectionTitle(
                'Jenis notifikasi',
                subtitle:
                    'Yang dimatikan tetap masuk kotak masuk, hanya tidak muncul di layar HP',
              ),
              MxCard(
                padding: const EdgeInsets.symmetric(vertical: Sp.xs),
                child: Column(
                  children: [
                    for (final c in p.categories)
                      _CategorySwitch(
                        category: c,
                        value: _push![c.key] ?? c.push,
                        onChanged: c.locked ? null : (v) => _toggle(c.key, v),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.xl),
              const SectionTitle('Jam tenang'),
              MxCard(
                padding: const EdgeInsets.symmetric(vertical: Sp.xs),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: _quiet!,
                      onChanged: _toggleQuiet,
                      title: const Text('Tahan notifikasi di malam hari'),
                      subtitle: const Text(
                        'Pengingat check-in/check-out tetap muncul karena menyangkut jadwal Anda hari ini.',
                      ),
                    ),
                    AnimatedSize(
                      duration: Motion.of(context, Motion.standard),
                      child: _quiet!
                          ? Row(
                              children: [
                                Expanded(
                                  child: _TimeTile(
                                    label: 'Mulai',
                                    value: _quietStart!,
                                    onTap: () => _pickTime(true),
                                  ),
                                ),
                                Expanded(
                                  child: _TimeTile(
                                    label: 'Selesai',
                                    value: _quietEnd!,
                                    onTap: () => _pickTime(false),
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DeviceStatus extends StatelessWidget {
  const _DeviceStatus({
    required this.permission,
    required this.testing,
    required this.onEnable,
    required this.onOpenSettings,
    required this.onTest,
  });

  final PushPermission? permission;
  final bool testing;
  final VoidCallback onEnable;
  final Future<bool> Function() onOpenSettings;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final (icon, fg, bg, title, body) = switch (permission) {
      PushPermission.granted => (
        Icons.notifications_active_outlined,
        c.primary,
        c.primaryContainer,
        'Notifikasi aktif di HP ini',
        'Pengingat absen, jadwal, jaspel, izin, dan chat SiLAKES akan muncul di sini.',
      ),
      PushPermission.denied => (
        Icons.notifications_off_outlined,
        c.alert,
        c.alertContainer,
        'Notifikasi diblokir',
        'Android memblokir notifikasi MATRIX. Buka pengaturan lalu izinkan notifikasi.',
      ),
      PushPermission.unavailable => (
        Icons.cloud_off_outlined,
        c.inkMuted,
        c.canvas,
        'Notifikasi belum tersedia',
        'Layanan notifikasi belum aktif di versi aplikasi ini. Kotak masuk tetap bisa dibuka.',
      ),
      _ => (
        Icons.notifications_none_rounded,
        c.pending,
        c.pendingContainer,
        'Notifikasi belum diaktifkan',
        'Aktifkan supaya tidak terlewat jendela check-in/check-out dan jadwal yang terbit.',
      ),
    };

    return MxCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon, size: 44, background: bg, color: fg),
              const SizedBox(width: Sp.md),
              Expanded(child: Text(title, style: context.text.titleSmall)),
            ],
          ),
          const SizedBox(height: Sp.sm),
          Text(
            body,
            style: context.text.bodyMedium?.copyWith(color: c.inkMuted),
          ),
          if (permission != null &&
              permission != PushPermission.unavailable) ...[
            const SizedBox(height: Sp.md),
            SizedBox(
              width: double.infinity,
              child: switch (permission) {
                PushPermission.granted => OutlinedButton.icon(
                  onPressed: testing ? null : onTest,
                  icon: testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_outlined),
                  label: const Text('Kirim notifikasi uji'),
                ),
                PushPermission.denied => FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Buka pengaturan Android'),
                ),
                _ => FilledButton.icon(
                  onPressed: onEnable,
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('Aktifkan notifikasi'),
                ),
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow(this.d);
  final PushDevice d;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final isApp = d.app == 'matrix';
    final last = d.lastUsedAt == null
        ? null
        : '${Fmt.date(d.lastUsedAt!.toLocal())} ${Fmt.timeOf(d.lastUsedAt!.toLocal())}';
    return ListTile(
      leading: IconBadge(
        isApp ? Icons.phone_android_rounded : Icons.laptop_chromebook_outlined,
        size: 36,
        background: isApp ? c.primaryContainer : context.hues.sky.bg,
        color: isApp ? c.primary : context.hues.sky.fg,
      ),
      title: Text(
        isApp
            ? 'Aplikasi MATRIX${d.appVersion == null ? '' : ' v${d.appVersion}'}'
            : 'SiLAKES web',
      ),
      subtitle: Text(
        [
          if (!isApp && d.deviceInfo != null) _browser(d.deviceInfo!),
          if (last != null) 'aktif $last',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static String _browser(String ua) {
    final browser = ua.contains('Edg/')
        ? 'Edge'
        : ua.contains('Chrome/')
        ? 'Chrome'
        : ua.contains('Firefox/')
        ? 'Firefox'
        : ua.contains('Safari/')
        ? 'Safari'
        : 'Browser';
    final os = ua.contains('Windows')
        ? 'Windows'
        : ua.contains('Android')
        ? 'Android'
        : ua.contains('Mac OS')
        ? 'macOS'
        : ua.contains('Linux')
        ? 'Linux'
        : null;
    return os == null ? browser : '$browser di $os';
  }
}

class _CategorySwitch extends StatelessWidget {
  const _CategorySwitch({
    required this.category,
    required this.value,
    required this.onChanged,
  });
  final PrefCategory category;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final s = notificationStyle(context, category.key);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      secondary: IconBadge(
        s.icon,
        size: 36,
        iconSize: 18,
        background: s.hue.bg,
        color: s.hue.fg,
      ),
      title: Text(category.label),
      subtitle: Text(
        category.locked
            ? '${category.description} Selalu aktif.'
            : category.description,
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.control),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.sm, Sp.lg, Sp.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.text.labelMedium?.copyWith(
                color: context.mx.inkMuted,
              ),
            ),
            Text(value.replaceAll(':', '.'), style: context.text.titleLarge),
          ],
        ),
      ),
    );
  }
}
