import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/tokens.dart';
import '../../../core/widgets/finance.dart';
import '../../../core/widgets/mx.dart';
import '../data/attendance_models.dart';
import '../logic/preflight.dart';

/// Pusat default (UPTD Labkesmas Sumenep) sebelum posisi & titik dimuat.
const _defaultCenter = LatLng(-7.014418, 113.858575);

/// Buka navigasi jalan kaki ke titik absen di aplikasi peta.
Future<void> openNavigation(
  BuildContext context,
  AttendanceLocation? target,
) async {
  if (target == null) return;
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}&travelmode=walking',
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    showMxSnack(context, 'Aplikasi peta tidak bisa dibuka.', tone: Tone.alert);
  }
}

/// Peta pra-cek: lingkaran radius tiap titik, posisi pegawai + akurasi, dan
/// garis ke titik terdekat bila di luar radius. Kamera peta menyesuaikan sekali
/// begitu posisi pertama didapat; tombol arah untuk menyesuaikan lagi.
class PreflightMap extends StatefulWidget {
  const PreflightMap({super.key, required this.pre, required this.onNavigate});

  final AttendancePreflight pre;
  final VoidCallback onNavigate;

  @override
  State<PreflightMap> createState() => _PreflightMapState();
}

class _PreflightMapState extends State<PreflightMap> {
  final _map = MapController();
  bool _fitted = false;

  AttendancePreflight get pre => widget.pre;

  @override
  void initState() {
    super.initState();
    pre.addListener(_maybeFit);
  }

  @override
  void dispose() {
    pre.removeListener(_maybeFit);
    _map.dispose();
    super.dispose();
  }

  void _maybeFit() {
    if (!_fitted && pre.mapReady && pre.position != null) {
      _fitted = true;
      _fit();
    }
  }

  void _fit() {
    final p = pre.position;
    final n = pre.nearest;
    if (p == null) return;
    final me = LatLng(p.latitude, p.longitude);
    if (n == null || (n.distance ?? 0) < 30) {
      _map.move(me, 18);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [me, LatLng(n.latitude, n.longitude)],
        padding: const EdgeInsets.all(48),
        maxZoom: 18,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final p = pre.position;
    final n = pre.nearest;
    final me = p == null ? null : LatLng(p.latitude, p.longitude);
    final outside =
        n != null && !n.inRange && !pre.locationFree && pre.radiusRequired;
    final points = pre.locations ?? const <AttendanceLocation>[];

    return MxCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: points.isNotEmpty
                        ? LatLng(points.first.latitude, points.first.longitude)
                        : _defaultCenter,
                    initialZoom: 16.5,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () {
                      pre.markMapReady();
                      _maybeFit();
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.silakes.matrix',
                      errorTileCallback: (tile, error, stack) =>
                          pre.markTilesFailed(),
                    ),
                    CircleLayer(
                      circles: [
                        for (final l in points)
                          CircleMarker(
                            point: LatLng(l.latitude, l.longitude),
                            radius: l.radiusMeters.toDouble(),
                            useRadiusInMeter: true,
                            color: c.primaryBright.withValues(
                              alpha: l.id == n?.id ? 0.22 : 0.10,
                            ),
                            borderColor: c.primary,
                            borderStrokeWidth: l.id == n?.id ? 2.5 : 1,
                          ),
                        if (me != null && p!.accuracy > 0)
                          CircleMarker(
                            point: me,
                            radius: p.accuracy,
                            useRadiusInMeter: true,
                            color: c.ink.withValues(alpha: 0.08),
                            borderColor: c.ink.withValues(alpha: 0.25),
                            borderStrokeWidth: 1,
                          ),
                      ],
                    ),
                    if (outside && me != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [me, LatLng(n.latitude, n.longitude)],
                            color: c.alert,
                            strokeWidth: 3,
                            pattern: StrokePattern.dashed(
                              segments: const [10, 8],
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final l in points)
                          Marker(
                            point: LatLng(l.latitude, l.longitude),
                            width: 30,
                            height: 30,
                            child: Tooltip(
                              message: l.name,
                              child: IconBadge(
                                Icons.apartment_rounded,
                                size: 30,
                                background: c.surface,
                                color: c.primary,
                              ),
                            ),
                          ),
                        if (me != null)
                          Marker(
                            point: me,
                            width: 22,
                            height: 22,
                            child: Semantics(
                              label: 'Posisi Anda',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: c.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [TextSourceAttribution('© OpenStreetMap')],
                    ),
                  ],
                ),
                if (!pre.mapReady || p == null)
                  Positioned(
                    left: Sp.md,
                    top: Sp.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: Sp.sm),
                          Text(
                            !pre.mapReady
                                ? 'Menyiapkan peta…'
                                : 'Mencari posisi…',
                            style: context.text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                if (p != null)
                  Positioned(
                    right: Sp.md,
                    top: Sp.md,
                    child: Material(
                      color: c.surface,
                      shape: const CircleBorder(),
                      child: IconButton(
                        onPressed: _fit,
                        tooltip: 'Pusatkan peta',
                        icon: Icon(Icons.my_location_rounded, color: c.primary),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (outside)
            Padding(
              padding: const EdgeInsets.fromLTRB(Sp.lg, Sp.md, Sp.lg, Sp.md),
              child: Row(
                children: [
                  // Panah penunjuk arah ke titik terdekat (utara = atas, sama seperti peta).
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.alertContainer,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedRotation(
                      turns: (pre.bearingToNearest() ?? 0) / 360,
                      duration: Motion.of(context, Motion.standard),
                      child: Icon(
                        Icons.navigation_rounded,
                        color: c.alert,
                        semanticLabel: 'Arah ${pre.directionToNearest() ?? ''}',
                      ),
                    ),
                  ),
                  const SizedBox(width: Sp.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Menuju ${n.name}',
                          style: context.text.titleSmall,
                        ),
                        Text(
                          '${_meters(n.distance ?? 0)}${pre.directionToNearest() == null ? '' : ' ke arah ${pre.directionToNearest()}'} · masuk radius ${n.radiusMeters} m',
                          style: context.text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  FilledButton(
                    onPressed: widget.onNavigate,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(48, 44),
                    ),
                    child: const Text('Navigasi'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _meters(double d) =>
      d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';
}

/// Daftar pemeriksaan kesiapan, tiap baris dengan status & aksi perbaikan.
class PreflightChecklist extends StatelessWidget {
  const PreflightChecklist({
    super.key,
    required this.items,
    required this.onAction,
  });

  final List<CheckItem> items;
  final ValueChanged<CheckId> onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final done = items
        .where((i) => i.state == CheckState.ok || i.state == CheckState.warn)
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Pemeriksaan kesiapan',
          subtitle: '$done dari ${items.length} siap',
        ),
        MxCard(
          padding: const EdgeInsets.symmetric(vertical: Sp.xs),
          child: Column(
            children: [
              for (final i in items)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Sp.lg,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: Motion.of(context, Motion.standard),
                        child: switch (i.state) {
                          CheckState.pending => const SizedBox(
                            key: ValueKey('p'),
                            width: 32,
                            height: 32,
                            child: Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          ),
                          CheckState.ok => const IconBadge(
                            Icons.check_rounded,
                            key: ValueKey('o'),
                            size: 32,
                          ),
                          CheckState.warn => IconBadge(
                            Icons.priority_high_rounded,
                            key: const ValueKey('w'),
                            size: 32,
                            background: c.pendingContainer,
                            color: c.pending,
                          ),
                          CheckState.fail => IconBadge(
                            Icons.close_rounded,
                            key: const ValueKey('f'),
                            size: 32,
                            background: c.alertContainer,
                            color: c.alert,
                          ),
                        },
                      ),
                      const SizedBox(width: Sp.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.title, style: context.text.titleSmall),
                            Text(
                              i.detail,
                              style: context.text.bodySmall?.copyWith(
                                color: i.state == CheckState.fail
                                    ? c.alert
                                    : (i.state == CheckState.warn
                                          ? c.pending
                                          : c.inkMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i.actionLabel != null &&
                          i.state == CheckState.fail) ...[
                        const SizedBox(width: Sp.sm),
                        OutlinedButton(
                          onPressed: () => onAction(i.id),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 40),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(i.actionLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
