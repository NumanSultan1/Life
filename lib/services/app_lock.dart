import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';
import '../widgets/life_logo.dart';
import '../widgets/liquid/liquid.dart';
import 'hive_service.dart';

/// Optional lock with fingerprint, face or the phone's PIN/pattern.
/// It's a phone-level setting (covers every profile on this phone).
class AppLock {
  AppLock._();

  static final _auth = LocalAuthentication();
  static const _secure = MethodChannel('life/security');
  static Box get _box => Hive.box(HiveService.settingsBox);
  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static bool get enabled => supported && _box.get('appLockEnabled', defaultValue: false) as bool;

  /// True while the system prompt is showing (it pauses the app briefly).
  static bool authenticating = false;

  static Future<bool> deviceCanLock() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate(String reason) async {
    authenticating = true;
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    } finally {
      // Let the resume event from the prompt pass before relocking is allowed.
      Future.delayed(const Duration(milliseconds: 800), () => authenticating = false);
    }
  }

  /// Turns the lock on or off (asks to unlock first, proving it works).
  static Future<String?> setEnabled(bool on) async {
    if (on && !await deviceCanLock()) return 'Set a screen lock (PIN, pattern or fingerprint) in your phone settings first.';
    if (!await authenticate(on ? 'Confirm it\'s you to turn on App lock' : 'Confirm it\'s you to turn off App lock')) return 'Not changed.';
    await _box.put('appLockEnabled', on);
    await applySecureFlag();
    return null;
  }

  /// While the lock is on, hide Life's screen in recent apps and block
  /// screenshots (Android FLAG_SECURE).
  static Future<void> applySecureFlag() async {
    if (!supported) return;
    try {
      await _secure.invokeMethod('setSecure', enabled);
    } catch (_) {}
  }
}

/// Covers the app until the user unlocks; relocks after 30 s away.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  static const _grace = Duration(seconds: 30);
  late bool _locked = AppLock.enabled;
  DateTime? _leftAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLock.applySecureFlag();
    if (_locked) WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppLock.enabled || AppLock.authenticating) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _leftAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _leftAt == null ? Duration.zero : DateTime.now().difference(_leftAt!);
      _leftAt = null;
      if (away > _grace && !_locked) {
        setState(() => _locked = true);
        _unlock();
      }
    }
  }

  Future<void> _unlock() async {
    if (!_locked || AppLock.authenticating) return;
    final ok = await AppLock.authenticate('Unlock Life');
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Keep the app alive underneath, but hidden and not focusable.
        ExcludeSemantics(excluding: _locked, child: Offstage(offstage: _locked, child: widget.child)),
        if (_locked)
          Positioned.fill(
            child: LiquidBackground(
              child: SafeArea(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LifeLogoBadge(fontSize: 40),
                      const SizedBox(height: 24),
                      const Text('Life is locked', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, decoration: TextDecoration.none)),
                      const SizedBox(height: 8),
                      Text(
                        'Use your fingerprint, face or phone PIN',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.none),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: 220,
                        child: Material(
                          type: MaterialType.transparency,
                          child: GlowButton(label: 'Unlock', icon: Icons.fingerprint_rounded, onPressed: _unlock),
                        ),
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
}
