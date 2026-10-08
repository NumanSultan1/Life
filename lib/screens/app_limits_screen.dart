import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import '../widgets/liquid/liquid.dart';

/// Talks to the native app-limit code (Android only).
class AppLimitsChannel {
  static const _ch = MethodChannel('life/app_limits');
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Map<String, bool>> status() async => Map<String, bool>.from(await _ch.invokeMethod('status') as Map);
  static Future<void> openUsageAccess() => _ch.invokeMethod('openUsageAccess');
  static Future<void> openOverlay() => _ch.invokeMethod('openOverlay');
  static Future<Map<String, int>> limits() async => Map<String, int>.from(await _ch.invokeMethod('getLimits') as Map);
  static Future<void> setLimits(Map<String, int> limits) => _ch.invokeMethod('setLimits', limits);
  static Future<void> setFocusUntil(DateTime until) => _ch.invokeMethod('setFocusUntil', until.millisecondsSinceEpoch);
  static Future<Map<String, int>> usageToday() async => Map<String, int>.from(await _ch.invokeMethod('usageToday') as Map);
  static Future<List<InstalledApp>> listApps() async {
    final raw = await _ch.invokeMethod('listApps') as List;
    return raw.map((m) => InstalledApp(m['package'] as String, m['label'] as String, m['icon'] as Uint8List)).toList();
  }
}

class InstalledApp {
  final String package, label;
  final Uint8List icon;

  InstalledApp(this.package, this.label, this.icon);
}

/// Profile → App time limits: choose apps and a daily allowance for each.
class AppLimitsScreen extends StatefulWidget {
  const AppLimitsScreen({super.key});

  @override
  State<AppLimitsScreen> createState() => _AppLimitsScreenState();
}

class _AppLimitsScreenState extends State<AppLimitsScreen> with WidgetsBindingObserver {
  Map<String, bool> _status = const {'usageAccess': false, 'overlay': false};
  Map<String, int> _limits = {};
  Map<String, int> _usage = {};
  List<InstalledApp> _apps = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Coming back from Settings: re-check permissions and usage.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    if (!AppLimitsChannel.supported) {
      setState(() => _loading = false);
      return;
    }
    try {
      final status = await AppLimitsChannel.status();
      final limits = await AppLimitsChannel.limits();
      final usage = await AppLimitsChannel.usageToday();
      final apps = _apps.isEmpty ? await AppLimitsChannel.listApps() : _apps;
      if (!mounted) return;
      setState(() {
        _status = status;
        _limits = limits;
        _usage = usage;
        _apps = apps;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  InstalledApp? _app(String pkg) => _apps.where((a) => a.package == pkg).firstOrNull;

  Future<void> _save(Map<String, int> limits) async {
    await AppLimitsChannel.setLimits(limits);
    await _load();
  }

  Future<void> _pickApp() async {
    final query = ValueNotifier('');
    final picked = await showLiquidSheet<InstalledApp>(
      context: context,
      title: 'Choose an app',
      builder: (sheetContext) => ValueListenableBuilder<String>(
        valueListenable: query,
        builder: (context, q, _) {
          final list = _apps.where((a) => !_limits.containsKey(a.package) && a.label.toLowerCase().contains(q.toLowerCase())).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                autofocus: false,
                onChanged: (v) => query.value = v,
                decoration: const InputDecoration(hintText: 'Search apps', prefixIcon: Icon(Icons.search_rounded)),
              ),
              const SizedBox(height: 10),
              for (final app in list.take(60))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Image.memory(app.icon, width: 40, height: 40),
                  title: Text(app.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onTap: () => Navigator.pop(sheetContext, app),
                ),
              if (list.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No apps found', textAlign: TextAlign.center),
                ),
            ],
          );
        },
      ),
    );
    if (picked != null && mounted) await _editLimit(picked.package);
  }

  Future<void> _editLimit(String pkg) async {
    const options = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240];
    var index = options.indexOf(_limits[pkg] ?? 30).clamp(0, options.length - 1);
    final app = _app(pkg);
    final save = await showLiquidSheet<bool>(
      context: context,
      title: app?.label ?? pkg,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setStateModal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetLabel('Daily limit'),
            BubbleSlider(
              value: index / (options.length - 1),
              labelBuilder: (v) => _fmt(options[(v * (options.length - 1)).round()]),
              onChanged: (v) => setStateModal(() => index = (v * (options.length - 1)).round()),
            ),
            const SizedBox(height: 8),
            Text(
              'When ${app?.label ?? 'this app'} reaches ${_fmt(options[index])} today, Life covers it with a "time\'s up" screen. You get a heads-up 5 minutes before. It resets at midnight.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 24),
            GlowButton(label: 'Save limit', onPressed: () => Navigator.pop(sheetContext, true)),
          ],
        ),
      ),
    );
    if (save == true) await _save({..._limits, pkg: options[index]});
  }

  static String _fmt(int minutes) => minutes < 60 ? '$minutes min' : '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}';

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ready = _status['usageAccess'] == true && _status['overlay'] == true;

    return Scaffold(
      body: AmbientBackground(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            LiquidHeader(
              title: 'App time limits',
              subtitle: 'Set a daily allowance for distracting apps',
              leading: GlassIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              child: !AppLimitsChannel.supported
                  ? GlassCard(
                      child: Text(
                        'App limits are available in the Android app. On iPhone, use Settings → Screen Time.',
                        style: textTheme.bodyMedium?.copyWith(height: 1.4),
                      ),
                    )
                  : _loading
                  ? const Center(
                      child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!ready) ...[
                          _PermissionStep(
                            done: _status['usageAccess'] == true,
                            number: 1,
                            title: 'Allow usage access',
                            text: 'Lets Life see how long you use each app today. Find "Life" in the list and switch it on.',
                            onTap: AppLimitsChannel.openUsageAccess,
                          ),
                          _PermissionStep(
                            done: _status['overlay'] == true,
                            number: 2,
                            title: 'Allow display over other apps',
                            text: 'Lets Life show the "time\'s up" screen on top of an app.',
                            onTap: AppLimitsChannel.openOverlay,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Row(
                          children: [
                            Expanded(child: Text('Your limits', style: textTheme.titleMedium?.copyWith(fontSize: 17))),
                            TextButton.icon(
                              onPressed: ready ? _pickApp : () => showInfoSnackBar(context, 'Allow both permissions above first.'),
                              icon: Icon(Icons.add_rounded, color: AppColors.accentOn(context)),
                              label: Text(
                                'Add app',
                                style: TextStyle(color: AppColors.accentOn(context), fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_limits.isEmpty)
                          GlassCard(
                            child: Column(
                              children: [
                                Icon(Icons.hourglass_empty_rounded, size: 40, color: AppColors.accentOn(context)),
                                const SizedBox(height: 8),
                                Text('No limits yet', style: textTheme.titleMedium),
                                const SizedBox(height: 4),
                                Text(
                                  'Add an app like Instagram or YouTube and choose how long you can use it each day.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        for (final entry in _limits.entries)
                          _LimitTile(
                            app: _app(entry.key),
                            package: entry.key,
                            limit: entry.value,
                            used: _usage[entry.key] ?? 0,
                            label: _fmt,
                            onEdit: () => _editLimit(entry.key),
                            onRemove: () async {
                              final removed = entry;
                              await _save(Map.of(_limits)..remove(entry.key));
                              if (context.mounted) {
                                showUndoSnackBar(context, 'Limit removed', () => _save({..._limits, removed.key: removed.value}));
                              }
                            },
                          ),
                        const SizedBox(height: 12),
                        Text(
                          'Life keeps a small notification while limits are on, so Android lets it watch in the background.',
                          style: textTheme.bodyMedium?.copyWith(fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermissionStep extends StatelessWidget {
  final bool done;
  final int number;
  final String title, text;
  final VoidCallback onTap;

  const _PermissionStep({required this.done, required this.number, required this.title, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: done ? null : onTap,
      highlighted: done,
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: done ? AppColors.success : AppColors.royal,
            child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    '$number',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(done ? 'Done' : text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5, height: 1.35)),
              ],
            ),
          ),
          if (!done)
            Text(
              'Open',
              style: TextStyle(color: AppColors.accentOn(context), fontWeight: FontWeight.w800),
            ),
        ],
      ),
    );
  }
}

class _LimitTile extends StatelessWidget {
  final InstalledApp? app;
  final String package;
  final int limit, used;
  final String Function(int) label;
  final VoidCallback onEdit, onRemove;

  const _LimitTile({
    required this.app,
    required this.package,
    required this.limit,
    required this.used,
    required this.label,
    required this.onEdit,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final over = used >= limit;
    final ratio = limit == 0 ? 1.0 : (used / limit).clamp(0.0, 1.0);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onEdit,
      child: Row(
        children: [
          if (app != null) Image.memory(app!.icon, width: 42, height: 42) else const Icon(Icons.apps_rounded, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app?.label ?? package, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 7,
                    color: over ? AppColors.danger : AppColors.royal,
                    backgroundColor: AppColors.lavender.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  over ? 'Limit reached today · ${label(limit)}' : '${label(used)} used of ${label(limit)} today',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12, color: over ? AppColors.danger : null),
                ),
              ],
            ),
          ),
          IconButton(tooltip: 'Remove limit', onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
    );
  }
}
