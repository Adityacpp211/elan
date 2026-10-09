// Élan — Hospital receiver service
// Owns the receiving hospital's inbox: server sync plus a local cache so the
// console still shows the last known alerts when the backend is unreachable.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'api_service.dart';

class ReceiverInbox {
  final List<ReceiverAlert> alerts;
  final ReceiverHospital? hospital;
  final ReceiverStats stats;

  const ReceiverInbox({
    this.alerts = const [],
    this.hospital,
    this.stats = const ReceiverStats(),
  });
}

class ReceiverService {
  static final ReceiverService _instance = ReceiverService._internal();
  factory ReceiverService() => _instance;
  ReceiverService._internal();

  final ApiService _api = ApiService();

  static const _kCacheKey = 'receiverInboxCache';
  static const _kHospitalKey = 'receiverHospitalCache';

  ReceiverInbox? _memoryCache;
  bool _syncing = false;
  bool get isSyncing => _syncing;

  /// The last known inbox, served from memory or disk without a network call.
  ReceiverInbox? get cachedInbox => _memoryCache;

  Future<ReceiverInbox> loadCache() async {
    if (_memoryCache != null) return _memoryCache!;

    final prefs = await SharedPreferences.getInstance();

    final alertsJson = prefs.getString(_kCacheKey);
    final hospitalJson = prefs.getString(_kHospitalKey);

    if (alertsJson == null && hospitalJson == null) {
      return const ReceiverInbox();
    }

    try {
      final alerts = alertsJson == null
          ? <ReceiverAlert>[]
          : (jsonDecode(alertsJson) as List)
              .whereType<Map<String, dynamic>>()
              .map(ReceiverAlert.fromJson)
              .toList();

      final hospital = hospitalJson == null
          ? null
          : ReceiverHospital.fromJson(
              (jsonDecode(hospitalJson) as Map).cast<String, dynamic>());

      final inbox = ReceiverInbox(
        alerts: alerts,
        hospital: hospital,
        stats: _recount(alerts),
      );
      _memoryCache = inbox;
      return inbox;
    } catch (_) {
      // A corrupt cache should never block the console.
      await prefs.remove(_kCacheKey);
      return const ReceiverInbox();
    }
  }

  /// Pull the inbox from the backend. Returns the cache untouched on failure.
  /// `pendingApproval` is true when the server says this staff account has
  /// not been approved yet — a different situation from being offline.
  Future<({ReceiverInbox? inbox, String? error, bool pendingApproval})>
      refreshInbox() async {
    if (_syncing) return (inbox: null, error: null, pendingApproval: false);

    _syncing = true;
    try {
      final response = await _api.getReceiverInbox();
      if (!response.success) {
        final data = response.data;
        return (
          inbox: null,
          error: response.error,
          pendingApproval: data is Map && data['code'] == 'pending_approval',
        );
      }

      final data = (response.data as Map?)?.cast<String, dynamic>() ?? {};
      final alerts = ((data['alerts'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ReceiverAlert.fromJson)
          .toList();

      final inbox = ReceiverInbox(
        alerts: alerts,
        hospital: data['hospital'] is Map
            ? ReceiverHospital.fromJson(
                (data['hospital'] as Map).cast<String, dynamic>())
            : null,
        stats: ReceiverStats.fromJson(
            (data['stats'] as Map?)?.cast<String, dynamic>()),
      );

      _memoryCache = inbox;
      await _persist(inbox);
      return (inbox: inbox, error: null, pendingApproval: false);
    } finally {
      _syncing = false;
    }
  }

  /// Acknowledge an alert and fold the server's response into the cache.
  Future<({ReceiverAlert? alert, String? error})> acknowledge(
    String alertId, {
    int? etaMinutes,
  }) async {
    final response = await _api.acknowledgeReceiverAlert(
      alertId,
      etaMinutes: etaMinutes,
    );
    if (!response.success) return (alert: null, error: response.error);

    final alert = response.data?['alert'] is Map
        ? ReceiverAlert.fromJson(
            (response.data!['alert'] as Map).cast<String, dynamic>())
        : null;
    if (alert != null) await _replace(alert);
    return (alert: alert, error: null);
  }

  /// Decline an alert and fold the server's response into the cache.
  Future<({ReceiverAlert? alert, String? error})> decline(
    String alertId, {
    String? reason,
  }) async {
    final response = await _api.declineReceiverAlert(alertId, reason: reason);
    if (!response.success) return (alert: null, error: response.error);

    final alert = response.data?['alert'] is Map
        ? ReceiverAlert.fromJson(
            (response.data!['alert'] as Map).cast<String, dynamic>())
        : null;
    if (alert != null) await _replace(alert);
    return (alert: alert, error: null);
  }

  /// The facility this staff member is signed in to.
  Future<({ReceiverHospital? hospital, String? error})> loadProfile() async {
    final response = await _api.getReceiverProfile();
    if (!response.success) return (hospital: null, error: response.error);

    final data = (response.data as Map?)?.cast<String, dynamic>() ?? {};
    final hospital = data['hospital'] is Map
        ? ReceiverHospital.fromJson(
            (data['hospital'] as Map).cast<String, dynamic>())
        : null;

    if (hospital != null) {
      _memoryCache = ReceiverInbox(
        alerts: _memoryCache?.alerts ?? const [],
        hospital: hospital,
        stats: _recount(_memoryCache?.alerts ?? const []),
      );
      await _persist(_memoryCache!);
    }

    return (hospital: hospital, error: null);
  }

  Future<void> clearCache() async {
    _memoryCache = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCacheKey);
    await prefs.remove(_kHospitalKey);
  }

  // ==================== INTERNAL ====================

  Future<void> _replace(ReceiverAlert alert) async {
    final current = _memoryCache ?? const ReceiverInbox();
    final alerts =
        current.alerts.map((a) => a.id == alert.id ? alert : a).toList();
    final updated = ReceiverInbox(
      alerts: alerts,
      hospital: current.hospital,
      stats: _recount(alerts),
    );
    _memoryCache = updated;
    await _persist(updated);
  }

  ReceiverStats _recount(List<ReceiverAlert> alerts) {
    var pending = 0, acknowledged = 0, declined = 0;
    for (final alert in alerts) {
      switch (alert.status) {
        case ReceiverAlertStatus.acknowledged:
          acknowledged++;
        case ReceiverAlertStatus.declined:
          declined++;
        case ReceiverAlertStatus.pending:
          pending++;
      }
    }
    return ReceiverStats(
      total: alerts.length,
      pending: pending,
      acknowledged: acknowledged,
      declined: declined,
    );
  }

  Future<void> _persist(ReceiverInbox inbox) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kCacheKey,
      jsonEncode(inbox.alerts.map((a) => a.toJson()).toList()),
    );
    if (inbox.hospital != null) {
      await prefs.setString(
        _kHospitalKey,
        jsonEncode({
          'id': inbox.hospital!.id,
          'name': inbox.hospital!.name,
          'address': inbox.hospital!.address,
          'phone': inbox.hospital!.phone,
          'latitude': inbox.hospital!.latitude,
          'longitude': inbox.hospital!.longitude,
        }),
      );
    }
  }
}
