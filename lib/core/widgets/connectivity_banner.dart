import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_colors.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  final Widget child;

  const ConnectivityBanner({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _slideAnimation;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _showBanner() {
    if (!_isVisible) {
      setState(() => _isVisible = true);
      _animationController?.forward();
      
      // Banner akan tetap muncul selama 3 detik
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          _hideBanner();
        }
      });
    }
  }

  void _hideBanner() {
    if (_isVisible) {
      _animationController?.reverse().then((_) {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ConnectivityState>(connectivityProvider, (previous, next) {
      if (next.message.isNotEmpty) {
        _showBanner();
      }
    });

    final connectivity = ref.watch(connectivityProvider);

    return Stack(
      children: [
        widget.child,
        if (_isVisible && connectivity.message.isNotEmpty)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnimation!.drive(
                Tween<Offset>(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ),
              ),
              child: Material(
                elevation: 8,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 12,
                    left: 16,
                    right: 16,
                  ),
                  decoration: BoxDecoration(
                    color: connectivity.isConnected
                        ? AppColors.success
                        : AppColors.error,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        connectivity.isConnected
                            ? Icons.wifi
                            : Icons.wifi_off,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          connectivity.message,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (connectivity.isConnected)
                        Icon(
                          _getConnectionIcon(connectivity.type),
                          color: Colors.white.withValues(alpha: 0.7),
                          size: 16,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _getConnectionIcon(ConnectivityType type) {
    switch (type) {
      case ConnectivityType.wifi:
        return Icons.wifi;
      case ConnectivityType.mobile:
        return Icons.signal_cellular_alt;
      case ConnectivityType.ethernet:
        return Icons.settings_ethernet;
      default:
        return Icons.cloud_off;
    }
  }
}
