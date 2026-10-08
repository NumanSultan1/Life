import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';

/// One reading of a health metric. [value2] is the diastolic pressure.
class VitalReading {
  final DateTime time;
  final double value;
  final double? value2;
  final bool manual;

  const VitalReading(this.time, this.value, {this.value2, this.manual = false});

  Map<String, dynamic> toMap() => {'t': time.toIso8601String(), 'v': value, if (value2 != null) 'v2': value2};
  static VitalReading fromMap(Map m) =>
      VitalReading(DateTime.parse(m['t'] as String), (m['v'] as num).toDouble(), value2: (m['v2'] as num?)?.toDouble(), manual: true);
}

/// How a reading compares with typical adult ranges.
enum VitalStatus { good, watch, alert }

/// A health measurement shown on the Health screen.
class VitalMetric {
  final String id, label, unit;
  final IconData icon;
  final Color color;
  final List<HealthDataType> types;
  final Duration lookBack;
  final bool manualEntry;
  final int decimals;

  /// Typical range text and a status check (general guidance only).
  final String range;
  final VitalStatus Function(VitalReading r)? status;

  /// Converts a Health Connect value to the shown unit.
  final double Function(double v) convert;

  const VitalMetric({
    required this.id,
    required this.label,
    required this.unit,
    required this.icon,
    required this.color,
    this.types = const [],
    this.lookBack = const Duration(days: 30),
    this.manualEntry = true,
    this.decimals = 0,
    this.range = '',
    this.status,
    this.convert = _same,
  });

  static double _same(double v) => v;

  String format(VitalReading r) {
    String f(double v) => v.toStringAsFixed(decimals);
    return r.value2 == null ? f(r.value) : '${f(r.value)}/${f(r.value2!)}';
  }
}

VitalStatus _between(double v, double low, double high, {double? alertLow, double? alertHigh}) {
  if ((alertLow != null && v < alertLow) || (alertHigh != null && v > alertHigh)) return VitalStatus.alert;
  return v >= low && v <= high ? VitalStatus.good : VitalStatus.watch;
}

final vitalMetrics = <VitalMetric>[
  VitalMetric(
    id: 'heart_rate',
    label: 'Heart rate',
    unit: 'bpm',
    icon: Icons.favorite_rounded,
    color: AppColors.danger,
    types: const [HealthDataType.HEART_RATE],
    lookBack: const Duration(days: 2),
    range: '60–100 bpm at rest',
    status: (r) => _between(r.value, 50, 100, alertLow: 40, alertHigh: 130),
  ),
  VitalMetric(
    id: 'resting_hr',
    label: 'Resting pulse',
    unit: 'bpm',
    icon: Icons.monitor_heart_rounded,
    color: AppColors.pink,
    types: const [HealthDataType.RESTING_HEART_RATE],
    lookBack: const Duration(days: 14),
    range: '60–100 bpm (lower is fitter)',
    status: (r) => _between(r.value, 45, 100, alertLow: 40, alertHigh: 110),
  ),
  VitalMetric(
    id: 'blood_pressure',
    label: 'Blood pressure',
    unit: 'mmHg',
    icon: Icons.bloodtype_rounded,
    color: AppColors.danger,
    types: const [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
    range: 'Below 120/80 is normal',
    status: (r) {
      final d = r.value2 ?? 0;
      if (r.value >= 140 || d >= 90 || r.value < 90) return VitalStatus.alert;
      if (r.value >= 120 || d >= 80) return VitalStatus.watch;
      return VitalStatus.good;
    },
  ),
  VitalMetric(
    id: 'blood_oxygen',
    label: 'Blood oxygen',
    unit: '%',
    icon: Icons.air_rounded,
    color: AppColors.sky,
    types: const [HealthDataType.BLOOD_OXYGEN],
    lookBack: const Duration(days: 14),
    range: '95–100%',
    // Health Connect stores a fraction (0.97) on some phones.
    convert: _percent,
    status: (r) => _between(r.value, 95, 100, alertLow: 90),
  ),
  VitalMetric(
    id: 'blood_glucose',
    label: 'Blood sugar',
    unit: 'mg/dL',
    icon: Icons.water_drop_outlined,
    color: AppColors.warning,
    types: const [HealthDataType.BLOOD_GLUCOSE],
    range: '70–99 fasting, under 140 after meals',
    status: (r) => _between(r.value, 70, 140, alertLow: 54, alertHigh: 200),
  ),
  VitalMetric(
    id: 'body_temp',
    label: 'Temperature',
    unit: '°C',
    icon: Icons.thermostat_rounded,
    color: AppColors.warning,
    types: const [HealthDataType.BODY_TEMPERATURE],
    decimals: 1,
    range: '36.1–37.2 °C',
    status: (r) => _between(r.value, 36.1, 37.5, alertLow: 35, alertHigh: 38),
  ),
  VitalMetric(
    id: 'respiratory_rate',
    label: 'Breathing',
    unit: 'breaths/min',
    icon: Icons.waves_rounded,
    color: AppColors.sky,
    types: const [HealthDataType.RESPIRATORY_RATE],
    lookBack: const Duration(days: 14),
    range: '12–20 at rest',
    status: (r) => _between(r.value, 12, 20, alertLow: 8, alertHigh: 25),
  ),
  VitalMetric(
    id: 'hrv',
    label: 'HRV',
    unit: 'ms',
    icon: Icons.ssid_chart_rounded,
    color: AppColors.violet,
    types: const [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
    lookBack: const Duration(days: 14),
    manualEntry: false,
    range: 'Higher usually means better recovery',
  ),
  const VitalMetric(
    id: 'weight',
    label: 'Weight',
    unit: 'kg',
    icon: Icons.monitor_weight_rounded,
    color: AppColors.royal,
    types: [HealthDataType.WEIGHT],
    lookBack: Duration(days: 365),
    decimals: 1,
  ),
  VitalMetric(
    id: 'height',
    label: 'Height',
    unit: 'cm',
    icon: Icons.height_rounded,
    color: AppColors.royal,
    types: const [HealthDataType.HEIGHT],
    lookBack: const Duration(days: 3650),
    // Health Connect stores metres.
    convert: (v) => v < 3 ? v * 100 : v,
  ),
  VitalMetric(
    id: 'body_fat',
    label: 'Body fat',
    unit: '%',
    icon: Icons.accessibility_new_rounded,
    color: AppColors.violet,
    types: const [HealthDataType.BODY_FAT_PERCENTAGE],
    lookBack: const Duration(days: 365),
    decimals: 1,
    convert: _percent,
  ),
];

double _percent(double v) => v <= 1 ? v * 100 : v;

/// An app or device that sends data to Health Connect (e.g. Samsung
/// Health with a Galaxy Watch), and when its newest reading was taken.
class HealthSource {
  final String app;
  final String? device;
  final DateTime latest;

  const HealthSource(this.app, this.device, this.latest);
}

const _appNames = {
  'com.sec.android.app.shealth': 'Samsung Health',
  'com.google.android.apps.fitness': 'Google Fit',
  'com.fitbit.FitbitMobile': 'Fitbit',
  'com.xiaomi.wearable': 'Mi Fitness',
  'com.mi.health': 'Mi Fitness',
  'com.huami.watch.hmwatchmanager': 'Zepp (Amazfit)',
  'com.garmin.android.apps.connectmobile': 'Garmin Connect',
  'com.ouraring.oura': 'Oura',
  'com.whoop.android': 'WHOOP',
  'com.withings.wiscale2': 'Withings',
  'com.polar.flow': 'Polar Flow',
  'com.coros.coros': 'COROS',
  'com.oneplus.health': 'OHealth',
  'com.heytap.health.international': 'OHealth',
  'com.google.android.apps.healthdata': 'Health Connect',
  'android': 'This phone',
};

String _friendlyApp(String id) => _appNames[id] ?? (id.contains('.') ? id.split('.').last : id);

String? _friendlyDevice(String? model) {
  if (model == null || model.isEmpty) return null;
  if (model.startsWith('SM-R')) return 'Galaxy Watch';
  if (model.startsWith('SM-')) return 'Galaxy phone';
  return model;
}

/// A workout from Health Connect.
class WorkoutEntry {
  final String type;
  final DateTime start;
  final Duration duration;
  final int? calories;

  const WorkoutEntry(this.type, this.start, this.duration, this.calories);
}

/// Reads vitals, body measurements, workouts, water and food from Health
/// Connect, and keeps readings the user types in by hand.
class VitalsProvider extends ChangeNotifier {
  final Health _health = Health();
  bool _configured = false;
  bool loading = false;
  DateTime? lastUpdated;

  static const _extraTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.RESPIRATORY_RATE,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.WATER,
    HealthDataType.WORKOUT,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.NUTRITION,
  ];

  static const _activityTypes = [
    HealthDataType.STEPS,
    HealthDataType.FLIGHTS_CLIMBED,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
  ];

  /// Health Connect readings per metric id, newest first.
  final Map<String, List<VitalReading>> _connected = {};

  /// Today's heart-rate range from Health Connect.
  int? heartMin, heartMax, heartAvg;

  double waterLitres = 0;
  int totalCalories = 0;
  int caloriesEaten = 0;
  List<WorkoutEntry> workouts = [];

  /// Whether the user allowed the extra health data in Health Connect.
  bool allConnected = false;

  /// Apps/devices that sent data in the last two days, newest first.
  List<HealthSource> sources = [];
  final Map<String, HealthSource> _sources = {};

  void _noteSource(HealthDataPoint p) {
    if (p.recordingMethod == RecordingMethod.manual && p.sourceId == 'com.example.vortextech_appdev_week4') return;
    final id = p.sourceId.isNotEmpty ? p.sourceId : p.sourceName;
    if (id.isEmpty) return;
    final device = _friendlyDevice(p.deviceModel);
    final key = '$id|${device ?? ''}';
    final old = _sources[key];
    if (old == null || p.dateTo.isAfter(old.latest)) _sources[key] = HealthSource(_friendlyApp(id), device, p.dateTo);
  }

  /// True when some data comes from a watch or band (not just the phone).
  bool get hasWearable => sources.any((s) => s.device != null && s.device != 'Galaxy phone');

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Box get _box => Hive.box(HiveService.settingsBox);
  static String get _key => '${HiveService.getCurrentUser()}_vitals';

  Map<String, List<VitalReading>> get _manual {
    final raw = (_box.get(_key) as Map?) ?? const {};
    return {for (final e in raw.entries) e.key as String: (e.value as List).map((m) => VitalReading.fromMap(m as Map)).toList()};
  }

  /// Every reading (Health Connect and manual), newest first.
  List<VitalReading> history(String id) {
    final all = [...?_connected[id], ...?_manual[id]]..sort((a, b) => b.time.compareTo(a.time));
    return all;
  }

  VitalReading? latest(String id) {
    final h = history(id);
    return h.isEmpty ? null : h.first;
  }

  /// Body mass index from the latest weight and height.
  double? get bmi {
    final w = latest('weight')?.value, h = latest('height')?.value;
    if (w == null || h == null || h <= 0) return null;
    return w / ((h / 100) * (h / 100));
  }

  static String bmiLabel(double bmi) => bmi < 18.5
      ? 'Underweight'
      : bmi < 25
          ? 'Healthy'
          : bmi < 30
              ? 'Overweight'
              : 'Obese';

  Future<void> addManual(String id, double value, {double? value2}) async {
    final all = Map<String, dynamic>.from((_box.get(_key) as Map?) ?? const {});
    final list = List<Map>.from((all[id] as List?) ?? const []);
    list.add(VitalReading(DateTime.now(), value, value2: value2).toMap());
    all[id] = list.length > 200 ? list.sublist(list.length - 200) : list;
    await _box.put(_key, all);
    notifyListeners();
  }

  Future<void> deleteManual(String id, VitalReading r) async {
    final all = Map<String, dynamic>.from((_box.get(_key) as Map?) ?? const {});
    final list = List<Map>.from((all[id] as List?) ?? const [])..removeWhere((m) => m['t'] == r.time.toIso8601String());
    all[id] = list;
    await _box.put(_key, all);
    notifyListeners();
  }

  Future<void> _configure() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Asks Health Connect for all the extra health data.
  Future<bool> connectAll() async {
    if (!supported) return false;
    try {
      await _configure();
      // Ask for everything at once: steps/sleep for Activity and all vitals.
      final all = {..._extraTypes, ..._activityTypes}.toList();
      allConnected = await _health.requestAuthorization(all, permissions: all.map((_) => HealthDataAccess.READ).toList());
    } catch (e) {
      debugPrint('Health Connect authorization failed: $e');
    }
    await refresh();
    return allConnected;
  }

  /// Reads everything allowed; each type separately, so one missing
  /// permission doesn't hide the rest.
  Future<void> refresh() async {
    if (!supported || loading) return;
    loading = true;
    notifyListeners();
    try {
      await _configure();
      if (!await _health.isHealthConnectAvailable()) return;
      allConnected = await _health.hasPermissions(_extraTypes, permissions: _extraTypes.map((_) => HealthDataAccess.READ).toList()) ?? false;
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      _sources.clear();
      Future<List<HealthDataPoint>> read(HealthDataType t, DateTime from) async {
        try {
          final points = await _health.getHealthDataFromTypes(types: [t], startTime: from, endTime: now);
          final recent = now.subtract(const Duration(days: 2));
          for (final p in points) {
            if (p.dateTo.isAfter(recent)) _noteSource(p);
          }
          return points;
        } catch (_) {
          return const [];
        }
      }

      // Steps from the last day, just to see which watch/apps are syncing.
      await read(HealthDataType.STEPS, now.subtract(const Duration(days: 1)));

      double num(HealthDataPoint p) => p.value is NumericHealthValue ? (p.value as NumericHealthValue).numericValue.toDouble() : 0;

      for (final m in vitalMetrics) {
        final from = now.subtract(m.lookBack);
        if (m.id == 'blood_pressure') {
          final sys = await read(HealthDataType.BLOOD_PRESSURE_SYSTOLIC, from);
          final dia = await read(HealthDataType.BLOOD_PRESSURE_DIASTOLIC, from);
          _connected[m.id] = [
            for (final s in sys)
              VitalReading(s.dateFrom, num(s),
                  value2: dia.where((d) => d.dateFrom.difference(s.dateFrom).inMinutes.abs() < 2).map(num).firstOrNull),
          ]..sort((a, b) => b.time.compareTo(a.time));
          continue;
        }
        final points = await read(m.types.first, from);
        _connected[m.id] = points.map((p) => VitalReading(p.dateFrom, m.convert(num(p)))).toList()..sort((a, b) => b.time.compareTo(a.time));
      }

      final today = (_connected['heart_rate'] ?? const <VitalReading>[]).where((r) => !r.time.isBefore(midnight)).map((r) => r.value).toList();
      if (today.isEmpty) {
        heartMin = heartMax = heartAvg = null;
      } else {
        heartMin = today.reduce((a, b) => a < b ? a : b).round();
        heartMax = today.reduce((a, b) => a > b ? a : b).round();
        heartAvg = (today.reduce((a, b) => a + b) / today.length).round();
      }

      waterLitres = (await read(HealthDataType.WATER, midnight)).fold(0.0, (a, p) => a + num(p));
      totalCalories = (await read(HealthDataType.TOTAL_CALORIES_BURNED, midnight)).fold(0.0, (a, p) => a + num(p)).round();
      caloriesEaten = (await read(HealthDataType.NUTRITION, midnight))
          .fold(0.0, (a, p) => a + (p.value is NutritionHealthValue ? ((p.value as NutritionHealthValue).calories ?? 0) : 0))
          .round();
      workouts = (await read(HealthDataType.WORKOUT, now.subtract(const Duration(days: 7))))
          .where((p) => p.value is WorkoutHealthValue)
          .map((p) {
            final w = p.value as WorkoutHealthValue;
            return WorkoutEntry(_workoutName(w.workoutActivityType.name), p.dateFrom, p.dateTo.difference(p.dateFrom), w.totalEnergyBurned);
          })
          .toList()
        ..sort((a, b) => b.start.compareTo(a.start));
      sources = _sources.values.toList()..sort((a, b) => b.latest.compareTo(a.latest));
      lastUpdated = now;
    } catch (e) {
      debugPrint('Vitals read failed: $e');
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  static String _workoutName(String raw) {
    final words = raw.toLowerCase().split('_').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'Workout';
    final s = words.join(' ');
    return s[0].toUpperCase() + s.substring(1);
  }
}
