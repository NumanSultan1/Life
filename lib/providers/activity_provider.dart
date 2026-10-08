import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/hive_service.dart';

/// Today's movement: steps, floors climbed, distance and active calories.
///
/// Health Connect (which Samsung Health and other apps sync to) gives
/// accurate all-day totals, including steps taken while Life was closed.
/// The phone's step sensor adds live steps on top while the app is open,
/// so the number ticks up as you walk. Without Health Connect, the sensor
/// alone is used.
class ActivityProvider extends ChangeNotifier {
  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
  ];

  final Health _health = Health();
  StreamSubscription<StepCount>? _sensorSub;
  Timer? _refreshTimer;

  bool _started = false;
  bool sensorAllowed = false;
  bool healthAvailable = false;
  bool healthConnected = false;

  int _healthSteps = 0;
  int _sensorSinceRefresh = 0; // live steps since the last Health Connect read
  int? _lastSensorValue;
  int _sensorOnlySteps = 0;

  int floors = 0;

  /// Last night's sleep (Health Connect), or null if unknown.
  Duration? sleepLastNight;
  double distanceKm = 0;
  int calories = 0;

  /// Called (once) when today's steps first reach 10,000, e.g. to tick
  /// the arcs' step rule.
  void Function()? onTenThousand;
  bool _tenThousandFired = false;

  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _user => HiveService.getCurrentUser();
  static String _date(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  int get goal => _box.get('${_user}_stepGoal', defaultValue: 8000) as int;
  Future<void> setGoal(int value) async {
    await _box.put('${_user}_stepGoal', value);
    notifyListeners();
  }

  int get steps => healthConnected ? _healthSteps + _sensorSinceRefresh : _sensorOnlySteps;
  /// Distance and calories including steps since the last Health Connect
  /// read, so they move live with the step counter.
  double get liveDistanceKm => healthConnected ? distanceKm + _sensorSinceRefresh * 0.00075 : steps * 0.00075;
  int get liveCalories => healthConnected ? calories + (_sensorSinceRefresh * 0.04).round() : (steps * 0.04).round();

  bool get isTracking => healthConnected || sensorAllowed;
  bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Starts tracking with whatever is already allowed (no prompts).
  Future<void> start() async {
    if (_started || !supported) return;
    _started = true;
    // Live steps first, so Home shows them right away.
    sensorAllowed = await Permission.activityRecognition.isGranted;
    _listenSensor();
    if (sensorAllowed) notifyListeners();
    try {
      await _health.configure();
      healthAvailable = await _health.isHealthConnectAvailable();
      if (healthAvailable) healthConnected = await _health.hasPermissions(_types) ?? false;
    } catch (e) {
      debugPrint('Health Connect unavailable: $e');
    }
    await refresh();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => refresh());
  }

  /// Asks for activity permissions (sensor, then Health Connect).
  /// Returns true if any step source is now allowed.
  Future<bool> connect() async {
    if (!supported) return false;
    sensorAllowed = (await Permission.activityRecognition.request()).isGranted;
    try {
      if (healthAvailable) {
        healthConnected = await _health.requestAuthorization(_types, permissions: _types.map((_) => HealthDataAccess.READ).toList());
      }
    } catch (e) {
      debugPrint('Health Connect authorization failed: $e');
    }
    _listenSensor();
    await refresh();
    return isTracking;
  }

  /// Opens the Play Store page to install Health Connect (older Android).
  Future<void> installHealthConnect() => _health.installHealthConnect();

  void _listenSensor() {
    if (!sensorAllowed || _sensorSub != null) return;
    _sensorSub = Pedometer.stepCountStream.listen(_onSensor, onError: (e) => debugPrint('Step sensor error: $e'));
  }

  /// The sensor reports steps since the phone booted; turn that into
  /// today's steps with a per-day baseline (and handle reboots).
  void _onSensor(StepCount event) {
    final value = event.steps;
    if (_lastSensorValue != null && value >= _lastSensorValue!) {
      _sensorSinceRefresh += value - _lastSensorValue!;
    }
    _lastSensorValue = value;

    final today = _date(DateTime.now());
    final baseKey = '${_user}_stepBase_$today';
    final carryKey = '${_user}_stepCarry_$today';
    final base = _box.get(baseKey) as int?;
    if (base == null) {
      // First reading today: count from here.
      _box.put(baseKey, value);
      _box.put(carryKey, 0);
    } else if (value < base) {
      // The phone rebooted (sensor restarted at 0): keep today's steps so
      // far as a carry, and count on from the new reading.
      _box.put(carryKey, _sensorOnlySteps);
      _box.put(baseKey, value);
    }
    final carry = _box.get(carryKey, defaultValue: 0) as int;
    _sensorOnlySteps = carry + value - (_box.get(baseKey) as int);
    _afterUpdate();
  }

  /// Reads today's totals from Health Connect.
  Future<void> refresh() async {
    if (healthConnected) {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      try {
        _healthSteps = await _health.getTotalStepsInInterval(midnight, now) ?? _healthSteps;
        _sensorSinceRefresh = 0;
        final points = await _health.getHealthDataFromTypes(types: _types.sublist(1, 4), startTime: midnight, endTime: now);
        await _readSleep(now);
        double sum(HealthDataType t) =>
            points.where((p) => p.type == t).fold(0.0, (a, p) => a + ((p.value as NumericHealthValue).numericValue.toDouble()));
        floors = sum(HealthDataType.FLIGHTS_CLIMBED).round();
        distanceKm = sum(HealthDataType.DISTANCE_DELTA) / 1000;
        calories = sum(HealthDataType.ACTIVE_ENERGY_BURNED).round();
      } catch (e) {
        debugPrint('Health Connect read failed: $e');
      }
    }
    if (!healthConnected) {
      // Rough estimates from steps alone.
      distanceKm = steps * 0.00075;
      calories = (steps * 0.04).round();
    }
    _afterUpdate();
  }

  /// Sleep sessions that ended between 6 PM yesterday and noon today.
  Future<void> _readSleep(DateTime now) async {
    final from = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 6));
    final to = DateTime(now.year, now.month, now.day, 12);
    final sessions = await _health.getHealthDataFromTypes(types: const [HealthDataType.SLEEP_SESSION], startTime: from, endTime: to.isAfter(now) ? now : to);
    if (sessions.isEmpty) return;
    final total = sessions.fold<Duration>(Duration.zero, (d, p) => d + p.dateTo.difference(p.dateFrom));
    sleepLastNight = total;
    final history = Map<String, dynamic>.from(_box.get('${_user}_sleepLog', defaultValue: <String, dynamic>{}) as Map);
    history[_date(now)] = total.inMinutes;
    await _box.put('${_user}_sleepLog', history);
  }

  void _afterUpdate() {
    final today = _date(DateTime.now());
    final history = Map<String, dynamic>.from(_box.get('${_user}_stepHistory', defaultValue: <String, dynamic>{}) as Map);
    if (history[today] != steps) {
      history[today] = steps;
      _box.put('${_user}_stepHistory', history);
    }
    if (steps >= 10000 && !_tenThousandFired) {
      _tenThousandFired = true;
      onTenThousand?.call();
    }
    notifyListeners();
  }

  /// Steps for Monday..Sunday of this week (null = no data).
  List<int?> thisWeek() {
    final history = Map<String, dynamic>.from(_box.get('${_user}_stepHistory', defaultValue: <String, dynamic>{}) as Map);
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => history[_date(monday.add(Duration(days: i)))] as int?);
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }
}
