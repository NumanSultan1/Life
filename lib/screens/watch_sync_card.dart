import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/activity_provider.dart';
import '../providers/vitals_provider.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';

const _channel = MethodChannel('life/health_setup');

/// Watch/band apps and how to share their data with Health Connect.
const _watchApps = <(String, String, String)>[
  ('com.sec.android.app.shealth', 'Samsung Health', 'Galaxy Watch, Galaxy Fit and Galaxy Ring. In Samsung Health: Settings › Health Connect › allow all.'),
  ('com.xiaomi.wearable', 'Mi Fitness', 'Xiaomi / Redmi watches and Mi Band. In Mi Fitness: Profile › Health Connect › turn on.'),
  ('com.fitbit.FitbitMobile', 'Fitbit', 'Fitbit watches and bands. In Fitbit: Profile › Health Connect › turn on.'),
  ('com.huami.watch.hmwatchmanager', 'Zepp (Amazfit)', 'Amazfit watches and bands. In Zepp: Profile › Add accounts › Health Connect.'),
  ('com.garmin.android.apps.connectmobile', 'Garmin Connect', 'Garmin watches share steps and some activity data with Health Connect.'),
];

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Shows which watch/band is syncing, and helps connect one.
class WatchSyncCard extends StatefulWidget {
  const WatchSyncCard({super.key});

  @override
  State<WatchSyncCard> createState() => _WatchSyncCardState();
}

class _WatchSyncCardState extends State<WatchSyncCard> {
  bool _syncing = false;
  List<String> _installed = const [];

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _channel.invokeListMethod<String>('installed').then((v) {
        if (mounted) setState(() => _installed = v ?? const []);
      }).catchError((_) {});
    }
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final activity = Provider.of<ActivityProvider>(context, listen: false);
    final vitals = Provider.of<VitalsProvider>(context, listen: false);
    await Future.wait([activity.refresh(), vitals.refresh()]);
    if (mounted) setState(() => _syncing = false);
  }

  Future<void> _connect() async {
    final vitals = Provider.of<VitalsProvider>(context, listen: false);
    final activity = Provider.of<ActivityProvider>(context, listen: false);
    final ok = await vitals.connectAll();
    await activity.connect();
    if (mounted) showInfoSnackBar(context, ok ? 'Connected. Pulling in your watch data…' : 'Allow the data in Health Connect to see it here.', icon: Icons.watch_rounded);
  }

  Future<void> _open(String method, [String? arg]) async {
    try {
      final ok = await _channel.invokeMethod<bool>(method, arg);
      if (ok != true && mounted) showInfoSnackBar(context, 'Couldn\'t open it on this phone.');
    } catch (_) {
      if (mounted) showInfoSnackBar(context, 'Couldn\'t open it on this phone.');
    }
  }

  void _showSteps() {
    showLiquidSheet(
      context: context,
      title: 'Connect a watch or band',
      builder: (c) {
        final textTheme = Theme.of(c).textTheme;
        Widget step(int n, String text) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(radius: 12, backgroundColor: AppColors.royal, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
                ],
              ),
            );
        final sorted = [..._watchApps]..sort((a, b) => (_installed.contains(b.$1) ? 1 : 0).compareTo(_installed.contains(a.$1) ? 1 : 0));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            step(1, 'Pair your watch or band with its own app as usual (for example Samsung Health for a Galaxy Watch).'),
            step(2, 'In that app, turn on sharing with Health Connect (see your app below).'),
            step(3, 'Tap "Allow health data" here and allow everything for Life.'),
            step(4, 'Done. Life reads steps, heart rate, sleep, SpO2, workouts and more whenever the watch syncs.'),
            const SizedBox(height: 6),
            for (final (pkg, name, how) in sorted)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name + (_installed.contains(pkg) ? '  ✓ installed' : ''), style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(how, style: textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.35)),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => _open('openApp', pkg), child: Text(_installed.contains(pkg) ? 'Open' : 'Get')),
                  ],
                ),
              ),
            Text(
              'Huawei and some other brands don\'t share with Health Connect, so their data can\'t reach Life.',
              style: textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.35),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(onPressed: () => _open('openHealthConnect'), icon: const Icon(Icons.settings_rounded), label: const Text('Open Health Connect settings')),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = Provider.of<VitalsProvider>(context);
    final textTheme = Theme.of(context).textTheme;
    if (!v.supported) return const SizedBox.shrink();
    final wearables = v.sources.where((s) => s.device != null && s.device != 'Galaxy phone').toList();
    final others = v.sources.where((s) => !wearables.contains(s)).toList();
    final connected = wearables.isNotEmpty;

    return GlassCard(
      highlighted: !connected,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: (connected ? AppColors.success : AppColors.royal).withValues(alpha: 0.14)),
                child: Icon(Icons.watch_rounded, color: connected ? AppColors.success : AppColors.royal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(connected ? 'Watch connected' : 'Watch & band', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      connected ? 'Data syncs whenever your watch syncs' : 'Sync heart rate, sleep and more from your wearable',
                      style: textTheme.bodyMedium?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Sync now',
                onPressed: _syncing ? null : _syncNow,
                icon: _syncing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded),
              ),
            ],
          ),
          if (v.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final s in [...wearables, ...others].take(4))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(s.device != null && s.device != 'Galaxy phone' ? Icons.watch_rounded : Icons.smartphone_rounded, size: 16, color: AppColors.accentOn(context)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${s.app}${s.device == null ? '' : ' · ${s.device}'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                    Text(_ago(s.latest), style: textTheme.bodyMedium?.copyWith(fontSize: 12)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              if (!v.allConnected) ...[
                Expanded(child: GlowButton(label: 'Allow health data', height: 44, onPressed: _connect)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: _showSteps,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: Text(connected ? 'Watch settings' : 'How to connect'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
