import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';

class ConnectivityState {
  final bool isConnected;
  final String message;
  final ConnectivityType type;

  ConnectivityState({
    required this.isConnected,
    required this.message,
    required this.type,
  });
}

enum ConnectivityType {
  none,
  wifi,
  mobile,
  ethernet,
}

class ConnectivityNotifier extends StateNotifier<ConnectivityState> {
  StreamSubscription<ConnectivityResult>? _subscription;
  bool _hasShownInitialConnection = false;

  ConnectivityNotifier() : super(ConnectivityState(
    isConnected: true,
    message: '',
    type: ConnectivityType.none,
  )) {
    _init();
  }

  void _init() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
    
    _subscription = Connectivity().onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
    });
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    bool isConnected = result != ConnectivityResult.none;
    String message = '';
    ConnectivityType type = ConnectivityType.none;

    if (isConnected) {
      if (_hasShownInitialConnection) {
        message = 'Internet Terhubung';
      }
      _hasShownInitialConnection = true;

      switch (result) {
        case ConnectivityResult.wifi:
          type = ConnectivityType.wifi;
          break;
        case ConnectivityResult.mobile:
          type = ConnectivityType.mobile;
          break;
        case ConnectivityResult.ethernet:
          type = ConnectivityType.ethernet;
          break;
        default:
          type = ConnectivityType.none;
      }
    } else {
      message = 'Internet Terputus';
      type = ConnectivityType.none;
      _hasShownInitialConnection = true;
    }

    state = ConnectivityState(
      isConnected: isConnected,
      message: message,
      type: type,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, ConnectivityState>((ref) {
  return ConnectivityNotifier();
});
