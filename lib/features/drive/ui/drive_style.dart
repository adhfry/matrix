import 'package:flutter/material.dart';

import '../../../core/format/fmt.dart';
import '../data/drive_repository.dart';

/// Ikon & warna jenis berkas, mirip Drive: PDF merah, dokumen biru,
/// lembar kerja hijau, presentasi jingga, gambar ungu.
(IconData, Color) driveIconOf(DriveItem i) {
  if (i.isPerson) return (Icons.folder_shared_rounded, const Color(0xFF5F6368));
  if (i.isFolder) {
    return (
      i.shared ? Icons.folder_shared_rounded : Icons.folder_rounded,
      i.isKantor ? const Color(0xFF1A73E8) : const Color(0xFF5F6368),
    );
  }
  return switch (i.ext) {
    'pdf' => (Icons.picture_as_pdf_rounded, const Color(0xFFD93025)),
    'doc' || 'docx' || 'rtf' || 'txt' || 'odt' => (
      Icons.description_rounded,
      const Color(0xFF1A73E8),
    ),
    'xls' || 'xlsx' || 'csv' || 'ods' => (
      Icons.table_chart_rounded,
      const Color(0xFF188038),
    ),
    'ppt' || 'pptx' || 'odp' => (
      Icons.slideshow_rounded,
      const Color(0xFFE37400),
    ),
    'jpg' || 'jpeg' || 'png' || 'webp' || 'gif' || 'heic' => (
      Icons.image_rounded,
      const Color(0xFF9334E6),
    ),
    'mp4' || 'webm' || 'mov' || 'mkv' => (
      Icons.movie_rounded,
      const Color(0xFFD93025),
    ),
    'mp3' || 'ogg' || 'wav' || 'm4a' => (
      Icons.audiotrack_rounded,
      const Color(0xFFE37400),
    ),
    'zip' || 'rar' || '7z' => (Icons.folder_zip_rounded, const Color(0xFF5F6368)),
    _ => (Icons.insert_drive_file_rounded, const Color(0xFF5F6368)),
  };
}

String driveBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) {
    return '${(b / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2).replaceAll('.', ',')} GB';
}

/// Keterangan baris kedua: "12 item" untuk folder, "Diubah 3 Okt · 1,2 MB".
String driveSubtitle(DriveItem i) {
  if (i.isPerson) return '${i.items} item dibagikan';
  if (i.isFolder) {
    return [
      '${i.items} item',
      if (i.location != null && i.location!.isNotEmpty) i.location!,
    ].join(' · ');
  }
  return [
    if (i.kindLabel != null) i.kindLabel!,
    if (i.status != null && i.status != 'berlaku') driveStatusLabel(i.status!),
    if (i.updatedAt != null) 'Diubah ${Fmt.date(i.updatedAt!)}',
    if (i.size > 0) driveBytes(i.size),
    if (i.location != null && i.location!.isNotEmpty) i.location!,
  ].join(' · ');
}

String driveStatusLabel(String s) => switch (s) {
  'berlaku' => 'Berlaku',
  'draf' => 'Draf',
  'diganti' => 'Diganti revisi',
  'dicabut' => 'Dicabut',
  _ => s,
};
