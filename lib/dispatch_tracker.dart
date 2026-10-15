// Élan — Live dispatch tracker.
// Shown right after an alert is sent (and from the alert log): follows the
// alert from "sent" to "help is on the way", like a delivery tracker, so the
// sender always knows whether anyone is coming.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'services/api_service.dart';
import 'services/phone_service.dart';

/// One hospital's view of the alert, as returned by GET /api/alerts/:id.
class _Dispatch {
  final String name;
  final String phone;
  final bool delivered;
  final bool acknowledged;
  final bool declined;
  final String? declineReason;
  final int? etaMinutes;
  final DateTime? acknowledgedAt;

  _Dispatch.fromJson(Map<String, dynamic> j)
      : name = (j['name'] as String?) ?? 'Hospital',
        phone = (j['phone'] as String?) ?? '',
        delivered = j['notificationSent'] == true,
        acknowledged = j['acknowledged'] == true,
        declined = j['declined'] == true,
        declineReason = j['declineReason'] as String?,
        etaMinutes = (j['etaMinutes'] as num?)?.toInt(),
        acknowledgedAt =
            DateTime.tryParse((j['acknowledgedAt'] as String?) ?? '')?.toLocal();

  /// When this hospital's team is expected, if it gave an estimate.
  DateTime? get arrival => acknowledged && etaMinutes != null
      ? (acknowledgedAt ?? DateTime.now()).add(Duration(minutes: etaMinutes!))
      : null;
}

enum _Phase { waiting, coming, noneAccepted }

class DispatchTrackerScreen extends StatefulWidget {
  const DispatchTrackerScreen({
    super.key,
    required this.alertId,
    this.hospitalsNotified,
  });

  final String alertId;

  /// Known right after sending; lets the screen render before the first poll.
  final int? hospitalsNotified;

  @override
  State<DispatchTrackerScreen> createState() => _DispatchTrackerScreenState();
}

class _DispatchTrackerScreenState extends State<DispatchTrackerScreen> {
  final _api = ApiService();

  static const _pollEvery = Duration(seconds: 5);

  List<_Dispatch> _dispatches = [];
  DateTime? _createdAt;
  DateTime? _lastUpdated;
  bool _loaded = false;
  String? _error;
  _Phase? _lastPhase;

  Timer? _poll;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(_pollEvery, (_) => _load());
    // Timers on screen (elapsed, ETA countdown) update every second.
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final response = await _api.getAlertDetails(widget.alertId);
    if (!mounted) return;

    if (!response.success || response.data is! Map) {
      setState(() => _error = response.error);
      return;
    }

    final data = response.data as Map;
    final dispatches = ((data['hospitals'] as List?) ?? const [])
        .whereType<Map>()
        .map((h) => _Dispatch.fromJson(h.cast<String, dynamic>()))
        .toList();

    setState(() {
      _dispatches = dispatches;
      _createdAt =
          DateTime.tryParse((data['createdAt'] as String?) ?? '')?.toLocal();
      _lastUpdated = DateTime.now();
      _loaded = true;
      _error = null;
    });

    // A buzz when a hospital accepts, so the sender notices without looking.
    final phase = _phase;
    if (_lastPhase != null &&
        _lastPhase != _Phase.coming &&
        phase == _Phase.coming) {
      HapticFeedback.heavyImpact();
    }
    _lastPhase = phase;
  }

  _Phase get _phase {
    if (_dispatches.any((d) => d.acknowledged)) return _Phase.coming;
    if (_dispatches.isNotEmpty && _dispatches.every((d) => d.declined)) {
      return _Phase.noneAccepted;
    }
    return _Phase.waiting;
  }

  /// The responding hospital expected soonest (or the first to accept).
  _Dispatch? get _responder {
    final accepted = _dispatches.where((d) => d.acknowledged).toList();
    if (accepted.isEmpty) return null;
    accepted.sort((a, b) {
      final x = a.arrival, y = b.arrival;
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return x.compareTo(y);
    });
    return accepted.first;
  }

  int get _deliveredCount =>
      _dispatches.where((d) => d.delivered).length;

  // ---------- formatting ----------

  static String _clock(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}';
  }

  static String _elapsed(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            ScreenHeader(
              title: 'Alert status',
              onBack: () => Navigator.of(context).pop(),
              trailing: _lastUpdated == null
                  ? null
                  : _LiveDot(stale: _error != null),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.textPrimary,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpace.xl, AppSpace.sm, AppSpace.xl, 32),
                  children: [
                    _statusCard(context),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpace.md),
                      ErrorBanner(
                          message:
                              'Live updates paused: ${_error!}. Retrying…'),
                    ],
                    const SizedBox(height: AppSpace.lg),
                    _timeline(context),
                    const SizedBox(height: AppSpace.lg),
                    if (_dispatches.isNotEmpty) _hospitals(context),
                    const SizedBox(height: AppSpace.xl),
                    OutlinedButton.icon(
                      onPressed: () => PhoneService.dial(
                          context, PhoneService.emergencyNumber),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: const Text('Call 112 (emergency services)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergency,
                        side: BorderSide(
                            color: AppColors.emergency.withValues(alpha: 0.4)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- status ----------

  Widget _statusCard(BuildContext context) {
    final now = DateTime.now();
    final responder = _responder;

    final Color color;
    final String title;
    final Widget body;

    switch (_phase) {
      case _Phase.coming:
        color = AppColors.success;
        final arrival = responder?.arrival;
        title = 'Help is on the way';
        if (arrival != null) {
          final left = arrival.difference(now);
          final big = left.inSeconds <= 0
              ? 'Arriving'
              : left.inMinutes < 1
                  ? '<1 min'
                  : '${left.inMinutes + (left.inSeconds % 60 > 0 ? 1 : 0)} min';
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(big, style: _bigNumberStyle),
              const SizedBox(height: 4),
              Text(
                '${responder!.name} expects to reach you around ${_clock(arrival)}.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],
          );
        } else {
          body = Text(
            '${responder?.name ?? 'A hospital'} accepted your alert and is responding.',
            style: Theme.of(context).textTheme.bodyLarge,
          );
        }
      case _Phase.noneAccepted:
        color = AppColors.emergency;
        title = 'No hospital could take this alert';
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Every notified hospital declined. Call emergency services now.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpace.md),
            FilledButton.icon(
              onPressed: () =>
                  PhoneService.dial(context, PhoneService.emergencyNumber),
              icon: const Icon(Icons.call_rounded),
              label: const Text('Call 112'),
            ),
          ],
        );
      case _Phase.waiting:
        color = AppColors.warning;
        title = 'Waiting for a hospital to respond';
        final since = _createdAt == null ? null : now.difference(_createdAt!);
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (since != null) Text(_elapsed(since), style: _bigNumberStyle),
            const SizedBox(height: 4),
            Text(
              'Hospitals have your location and symptoms. Stay where you '
              'are if it is safe, and keep your phone with you.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
      ),
      padding: const EdgeInsets.all(AppSpace.xl),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            body,
          ],
        ),
      ),
    );
  }

  static const _bigNumberStyle = TextStyle(
        fontSize: 44,
        height: 1.05,
        letterSpacing: -1.2,
        fontWeight: FontWeight.w800,
        fontVariations: AppFonts.w800,
        fontFeatures: [FontFeature.tabularFigures()],
        color: AppColors.textPrimary,
      );

  // ---------- timeline ----------

  Widget _timeline(BuildContext context) {
    final responder = _responder;
    final notified = _dispatches.isNotEmpty
        ? _dispatches.length
        : (widget.hospitalsNotified ?? 0);
    final arrival = responder?.arrival;

    final steps = <_Step>[
      _Step(
        'Alert sent',
        _createdAt == null ? null : 'at ${_clock(_createdAt!)}',
        done: true,
      ),
      _Step(
        'Delivered to $notified ${notified == 1 ? 'hospital' : 'hospitals'}',
        _loaded && _deliveredCount < notified
            ? '$_deliveredCount confirmed so far'
            : null,
        done: _loaded ? _deliveredCount > 0 : notified > 0,
      ),
      _Step(
        responder == null
            ? 'A hospital accepts'
            : '${responder.name} accepted',
        responder?.acknowledgedAt == null
            ? null
            : 'at ${_clock(responder!.acknowledgedAt!)}',
        done: responder != null,
        active: responder == null && _phase == _Phase.waiting,
      ),
      _Step(
        'Help arrives',
        arrival == null ? null : 'expected around ${_clock(arrival)}',
        done: arrival != null && DateTime.now().isAfter(arrival),
        active: responder != null,
      ),
    ];

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.sm),
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
        ],
      ),
    );
  }

  // ---------- hospitals ----------

  Widget _hospitals(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.lg, vertical: AppSpace.sm),
      child: Column(
        children: [
          for (var i = 0; i < _dispatches.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _hospitalRow(context, _dispatches[i]),
          ],
        ],
      ),
    );
  }

  Widget _hospitalRow(BuildContext context, _Dispatch d) {
    final (label, color) = d.acknowledged
        ? (
            d.etaMinutes == null ? 'Accepted' : 'Coming · ${d.etaMinutes} min',
            AppColors.success
          )
        : d.declined
            ? ('Declined', AppColors.textMuted)
            : !d.delivered
                ? ('Not delivered', AppColors.emergency)
                : ('Awaiting reply', AppColors.warning);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                StatusBadge(label: label, color: color),
                if (d.declined && (d.declineReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(d.declineReason!,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (d.phone.isNotEmpty)
            IconButton.outlined(
              tooltip: 'Call ${d.name}',
              onPressed: () => PhoneService.dial(context, d.phone),
              icon: const Icon(Icons.call_rounded, size: 20),
              style: IconButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.hairline),
              ),
            ),
        ],
      ),
    );
  }
}

class _Step {
  const _Step(this.title, this.detail, {this.done = false, this.active = false});
  final String title;
  final String? detail;
  final bool done;
  final bool active;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});
  final _Step step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final dotColor = step.done
        ? AppColors.success
        : step.active
            ? AppColors.warning
            : AppColors.hairline;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: step.done ? dotColor : AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: step.done
                      ? const Icon(Icons.check_rounded,
                          size: 12, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: step.done ? AppColors.success : AppColors.hairline,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: step.done || step.active
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                  ),
                  if (step.detail != null)
                    Text(step.detail!,
                        style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Live" indicator for the header: shows updates are flowing.
class _LiveDot extends StatelessWidget {
  const _LiveDot({required this.stale});
  final bool stale;

  @override
  Widget build(BuildContext context) => StatusBadge(
        label: stale ? 'Reconnecting' : 'Live',
        color: stale ? AppColors.warning : AppColors.success,
      );
}
