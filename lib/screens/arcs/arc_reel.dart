import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../data/arcs.dart';
import '../../services/reel_cache.dart';

/// Full-screen motivation reel: the arc's clips play back to back with
/// bold lines over them. Returns true if the user tapped the call to
/// action at the end.
class ArcReel extends StatefulWidget {
  final ArcDefinition arc;
  final String actionLabel;

  const ArcReel({super.key, required this.arc, this.actionLabel = 'I\'m in'});

  static Future<bool?> show(BuildContext context, ArcDefinition arc, {String actionLabel = 'I\'m in'}) {
    return Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (_, _, _) => ArcReel(arc: arc, actionLabel: actionLabel),
        transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<ArcReel> createState() => _ArcReelState();
}

class _ArcReelState extends State<ArcReel> {
  static const clipLength = Duration(milliseconds: 5200);
  static const lineLength = Duration(milliseconds: 3100);

  final List<VideoPlayerController> _clips = [];
  int _clip = 0;
  int _line = 0;
  bool _ended = false;
  Timer? _clipTimer, _lineTimer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    // Text starts right away; clips load in parallel (streaming the first
    // time) and the photo shows until each one is ready.
    _lineTimer = Timer.periodic(lineLength, (_) {
      if (!mounted) return;
      if (_line < widget.arc.reelLines.length - 1) {
        setState(() => _line++);
      } else {
        _finish();
      }
    });
    final controllers = await Future.wait(widget.arc.reel.map(ReelCache.controller));
    if (!mounted) {
      for (final c in controllers) {
        c.dispose();
      }
      return;
    }
    _clips.addAll(controllers);
    setState(() {});
    for (var i = 0; i < _clips.length; i++) {
      final c = _clips[i];
      c
          .initialize()
          .then((_) {
            c.setVolume(0);
            if (mounted && i == _clip) _playClip(i);
            if (mounted) setState(() {});
          })
          .catchError((_) {
            // A clip that can't load (e.g. offline) is skipped; the photo stays.
          });
    }
    if (_clips.isNotEmpty) _playClip(0);
  }

  void _playClip(int i) {
    if (i >= _clips.length) return;
    final c = _clips[i];
    if (c.value.isInitialized) {
      c.seekTo(Duration.zero);
      c.play();
    }
    setState(() => _clip = i);
    _clipTimer?.cancel();
    _clipTimer = Timer(clipLength, () {
      if (!mounted) return;
      c.pause();
      _playClip((i + 1) % _clips.length);
    });
  }

  void _finish() {
    _lineTimer?.cancel();
    setState(() => _ended = true);
  }

  @override
  void dispose() {
    _clipTimer?.cancel();
    _lineTimer?.cancel();
    for (final c in _clips) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arc = widget.arc;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Clips cross-fade into each other.
          for (var i = 0; i < _clips.length; i++)
            AnimatedOpacity(
              opacity: i == _clip ? 1 : 0,
              duration: const Duration(milliseconds: 700),
              child: _clips[i].value.isInitialized
                  ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(width: _clips[i].value.size.width, height: _clips[i].value.size.height, child: VideoPlayer(_clips[i])),
                    )
                  : Image.asset(arc.background, fit: BoxFit.cover),
            ),
          // Darken for legibility, tinted with the arc's colours.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.35), arc.colors.first.withValues(alpha: 0.55), Colors.black.withValues(alpha: 0.85)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(arc.icon, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        arc.name.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 3),
                      ),
                      const Spacer(),
                      if (!_ended)
                        TextButton(
                          onPressed: _finish,
                          child: const Text(
                            'Skip',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  // Progress through the lines.
                  Row(
                    children: List.generate(arc.reelLines.length, (i) {
                      return Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: _ended || i <= _line ? 0.95 : 0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: _ended
                        ? _EndCard(key: const ValueKey('end'), arc: arc, actionLabel: widget.actionLabel)
                        : Text(
                            arc.reelLines[_line],
                            key: ValueKey(_line),
                            style: const TextStyle(color: Colors.white, fontSize: 40, height: 1.1, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                          ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndCard extends StatelessWidget {
  final ArcDefinition arc;
  final String actionLabel;

  const _EndCard({super.key, required this.arc, required this.actionLabel});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          arc.tagline,
          style: const TextStyle(color: Colors.white, fontSize: 30, height: 1.15, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          '${arc.lengthDays} days · ${arc.rules.length} daily rules · ${arc.strict ? 'miss one and you start again at Day 1' : 'every full day counts'}.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
        ),
        const SizedBox(height: 24),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: arc.colors.first,
            minimumSize: const Size.fromHeight(56),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text(
            'Close',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
