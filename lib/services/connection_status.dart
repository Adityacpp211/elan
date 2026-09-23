// CardioAid — Server connectivity monitor.
// Periodically pings the backend and exposes a ValueNotifier so the UI can
// reflect whether the app is syncing online or running in local/offline mode.

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_service.dart';

enum ServerStatus { checking, online, offline }

class ConnectionStatus extends ValueNotifier<ServerStatus> {
  static final ConnectionStatus _instance = ConnectionStatus._internal();
  factory ConnectionStatus() => _instance;
  ConnectionStatus._internal() : super(ServerStatus.checking);

  static const _defaultCheckEvery = Duration(seconds: 20);

  Timer? _timer;
  bool _disposed = false;

  bool get isOnline => value == ServerStatus.online;
  bool get isOffline =>
      value == ServerStatus.offline || value == ServerStatus.checking;

  /// Begin periodic health checks. Safe to call multiple times.
  void startMonitoring({Duration interval = _defaultCheckEvery}) {
    check();
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => check());
  }

  /// Run a single health check now, without flipping to [ServerStatus.checking].
  Future<void> check() async {
    final online = await ApiService().checkServerHealth();
    if (_disposed) return;
    value = online ? ServerStatus.online : ServerStatus.offline;
  }

  /// Force a re-check and show the connecting state while in flight.
  Future<void> refresh() async {
    if (_disposed) return;
    value = ServerStatus.checking;
    await check();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}