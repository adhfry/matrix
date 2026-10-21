import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Kanal Android = "mx_" + kategori server, semuanya bersuara "Maaatriks"
/// (res/raw/matrix_voice, sama dengan suara pembuka). Nama tampil di
/// Pengaturan Android sehingga pegawai juga bisa mengatur suara per kanal.
/// Suara melekat pada kanal sejak dibuat, jadi kanal lama (tanpa awalan,
/// suara bawaan) dihapus dan diganti kanal baru ini.
const pushChannelPrefix = 'mx_';
const pushSound = RawResourceAndroidNotificationSound('matrix_voice');
const pushIcon = 'ic_stat_matrix';
const pushColor = Color(0xFF047857);

const pushChannels = <String, (String, String, Importance)>{
  'absensi': (
    'Pengingat absen',
    'Jendela check-in/check-out dibuka atau hampir tutup',
    Importance.high,
  ),
  'jadwal': (
    'Jadwal',
    'Jadwal terbit dan perubahan shift',
    Importance.defaultImportance,
  ),
  'jaspel': (
    'Jaspel',
    'Jaspel terbit dan status klaim',
    Importance.defaultImportance,
  ),
  'izin': (
    'Izin & cuti',
    'Keputusan pengajuan izin, sakit, cuti',
    Importance.defaultImportance,
  ),
  'tukar_jadwal': (
    'Tukar jadwal',
    'Permintaan dan keputusan tukar jadwal',
    Importance.defaultImportance,
  ),
  'chat': ('Chat', 'Pesan baru di chat SiLAKES', Importance.high),
  'chat_semua': (
    'Chat semua pengguna',
    'Pesan di percakapan seluruh staf',
    Importance.low,
  ),
  'rapat': ('Rapat', 'Undangan dan pengingat SiRapat', Importance.high),
  'panggilan_terlewat': (
    'Panggilan tak terjawab',
    'Panggilan suara dari chat yang tidak sempat diangkat',
    Importance.high,
  ),
  'persetujuan': (
    'Persetujuan admin',
    'Pengajuan pegawai dan hasil lab yang menunggu keputusan admin',
    Importance.high,
  ),
  'sistem': (
    'Pengumuman',
    'Informasi dari admin SiLAKES',
    Importance.defaultImportance,
  ),
};

/// Kanal dering panggilan masuk (res/raw/sfx_ditelfon), terpisah dari
/// [pushChannels] karena suaranya berbeda.
const callRingChannelId = '${pushChannelPrefix}panggilan';
const callRingSound = RawResourceAndroidNotificationSound('sfx_ditelfon');

AndroidNotificationChannel callRingChannel() => const AndroidNotificationChannel(
  callRingChannelId,
  'Panggilan masuk',
  description: 'Nada dering panggilan suara dari chat SiLAKES',
  importance: Importance.max,
  sound: callRingSound,
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
);

/// Kategori server yang dikenal; selain itu jatuh ke "sistem".
String pushCategory(Object? category) {
  final c = '${category ?? ''}';
  return pushChannels.containsKey(c) ? c : 'sistem';
}

AndroidNotificationDetails pushDetails(
  String category, {
  String? tag,
  StyleInformation? style,
  List<AndroidNotificationAction>? actions,
  NotificationVisibility? visibility,
  bool silent = false,
}) {
  final key = pushCategory(category);
  final channel = pushChannels[key]!;
  return AndroidNotificationDetails(
    '$pushChannelPrefix$key',
    channel.$1,
    channelDescription: channel.$2,
    importance: channel.$3,
    sound: pushSound,
    priority: channel.$3 == Importance.high
        ? Priority.high
        : Priority.defaultPriority,
    icon: pushIcon,
    color: pushColor,
    tag: tag,
    styleInformation: style,
    actions: actions,
    visibility: visibility,
    silent: silent,
    onlyAlertOnce: silent,
    category: key.startsWith('chat') ? AndroidNotificationCategory.message : null,
  );
}
