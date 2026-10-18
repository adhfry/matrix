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

String meters(double d) =>
    d >= 1000 ? '${(d / 1000).toStringAsFixed(1)} km' : '${d.round()} m';

/// Peta latar layar absen (seperti v1): radius tiap titik, posisi pegawai +
/// akurasi, garis ke titik terdekat bila di luar radius. [fitPadding] = bagian
/// layar yang tertutup kamera & panel, supaya posisi tampil di sela keduanya.
class AttendanceMap extends StatefulWidget {
  const AttendanceMap({super.key, required this.pre, required this.fitPadding});

  final AttendancePreflight pre;
  final EdgeInsets fitPadding;

  @override
  State<AttendanceMap> createState() => AttendanceMapState();
}

class AttendanceMapState extends State<AttendanceMap> {
  final _map = MapController();
  bool _fitted = false;
  bool _ready = false;

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
    if (!_fitted && _ready && pre.position != null) {
      _fitted = true;
      recenter();
    }
  }

  /// Tampilkan posisi pegawai & titik terdekat di area peta yang terlihat.
  void recenter() {
    final p = pre.position;
    if (p == null || !_ready) return;
    final me = LatLng(p.latitude, p.longitude);
    final n = pre.nearest;
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: [
          me,
          if (n != null && (n.distance ?? 0) < 20000)
            LatLng(n.latitude, n.longitude),
        ],
        padding: widget.fitPadding,
        maxZoom: 18,
        minZoom: 3,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final p = pre.position;
    final n = pre.nearest;
    final me = p == null ? null : LatLng(p.latitude, p.longitude);
    final outside =
        n != null && !n.inRange && !pre.locationFree && pre.radiusRequired;
    final points = pre.locations ?? const <AttendanceLocation>[];

    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: points.isNotEmpty
            ? LatLng(points.first.latitude, points.first.longitude)
            : _defaultCenter,
        initialZoom: 16.5,
        backgroundColor: c.canvas,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () {
          _ready = true;
          pre.markMapReady();
          _maybeFit();
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.silakes.matrix',
          tileBuilder: dark ? darkModeTileBuilder : null,
          errorTileCallback: (tile, error, stack) => pre.markTilesFailed(),
        ),
        CircleLayer(
          circles: [
            for (final l in points)
              CircleMarker(
                point: LatLng(l.latitude, l.longitude),
                radius: l.radiusMeters.toDouble(),
                useRadiusInMeter: true,
                color: c.primaryBright.withValues(
                  alpha: l.id == n?.id ? 0.20 : 0.10,
                ),
                borderColor: c.primary,
                borderStrokeWidth: l.id == n?.id ? 2.5 : 1,
              ),
            if (me != null && p!.accuracy > 0)
              CircleMarker(
                point: me,
                radius: p.accuracy,
                useRadiusInMeter: true,
                color: c.primary.withValues(alpha: 0.08),
                borderColor: c.primary.withValues(alpha: 0.30),
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
                pattern: StrokePattern.dashed(segments: const [10, 8]),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final l in points)
              Marker(
                point: LatLng(l.latitude, l.longitude),
                width: 140,
                height: 64,
                // Pusat ikon (15 dari 64 px teratas) tepat di koordinat titik.
                alignment: const Alignment(0, 0.53),
                child: _PointPin(name: l.name, active: l.id == n?.id),
              ),
            if (me != null)
              Marker(
                point: me,
                width: 24,
                height: 24,
                child: Semantics(
                  label: 'Posisi Anda',
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: c.shadow,
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Penanda titik absen: ikon gedung + nama, menempel di bawah koordinat.
class _PointPin extends StatelessWidget {
  const _PointPin({required this.name, required this.active});
  final String name;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = context.mx;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconBadge(
          Icons.apartment_rounded,
          size: 30,
          iconSize: 18,
          background: active ? c.primary : c.surface,
          color: active ? c.onPrimary : c.primary,
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: c.ink,
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }
}

/// Daftar pemeriksaan kesiapan di panel bawah, tiap baris dengan status &
/// aksi perbaikan.
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
    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context, Motion.standard),
                  child: switch (i.state) {
                    CheckState.pending => const SizedBox(
                      key: ValueKey('p'),
                      width: 30,
                      height: 30,
                      child: Padding(
                        padding: EdgeInsets.all(7),
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                    CheckState.ok => const IconBadge(
                      Icons.check_rounded,
                      key: ValueKey('o'),
                      size: 30,
                      iconSize: 18,
                    ),
                    CheckState.warn => IconBadge(
                      Icons.priority_high_rounded,
                      key: const ValueKey('w'),
                      size: 30,
                      iconSize: 18,
                      background: c.pendingContainer,
                      color: c.pending,
                    ),
                    CheckState.fail => IconBadge(
                      Icons.close_rounded,
                      key: const ValueKey('f'),
                      size: 30,
                      iconSize: 18,
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
                          color: switch (i.state) {
                            CheckState.fail => c.alert,
                            CheckState.warn => c.pending,
                            _ => c.inkMuted,
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                if (i.actionLabel != null && i.state == CheckState.fail) ...[
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
    );
  }
}
