import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/pashto_voice.dart';
import '../services/translator.dart';
import '../services/voice_languages.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import 'liquid/liquid.dart';

final _speech = SpeechToText();
bool _ready = false;
Set<String>? _deviceLocales;

Future<bool> _init(void Function(String) onStatus, void Function(String, bool) onError) async {
  _ready = await _speech.initialize(
    onStatus: onStatus,
    onError: (e) => onError(e.errorMsg, e.permanent),
  );
  if (_ready && _deviceLocales == null) {
    _deviceLocales = (await _speech.locales()).map((l) => l.localeId.replaceAll('-', '_')).toSet();
  }
  return _ready;
}

/// The phone's locale id for [l] (e.g. ps_AF), or null if not offered.
String? _deviceLocaleFor(VoiceLanguage l) {
  final all = _deviceLocales;
  if (all == null) return l.code;
  if (all.contains(l.code)) return l.code;
  for (final id in all) {
    if (id.split('_').first == l.lang) return id;
  }
  return null;
}

/// Language chip + mic button that types what you say into [controller].
class VoiceInputButton extends StatefulWidget {
  final TextEditingController controller;

  /// Called when speech has been turned into text (e.g. to send it).
  final VoidCallback? onFinished;

  /// Extra words to help the Pashto model (names, the user's words).
  final String Function()? speechHints;

  /// Short commands (the assistant): stop listening soon after a pause.
  /// Otherwise (journal) allow longer pauses while thinking.
  final bool quick;

  const VoiceInputButton({super.key, required this.controller, this.onFinished, this.speechHints, this.quick = false});

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> with SingleTickerProviderStateMixin {
  bool _listening = false;
  bool _pashtoRecording = false;
  bool _transcribing = false;
  int _progress = 0;
  bool _pashtoReady = false;
  String _base = '';
  VoiceLanguage _lang = VoiceLanguageSetting.current;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    PashtoVoice.isDownloaded().then((v) {
      if (mounted) setState(() => _pashtoReady = v);
      // Load the Pashto model now so the first sentence is fast.
      if (v && _lang.lang == 'ps') PashtoVoice.warmUp();
    });
    // Start the speech recognizer now (only if the mic is already allowed,
    // so opening a screen never pops a permission prompt).
    if (!_usePashtoModel) {
      Permission.microphone.isGranted.then((granted) {
        if (granted && mounted && !_ready) _ensureReady(quiet: true);
      }).catchError((_) {});
    }
  }

  bool get _usePashtoModel => _lang.lang == 'ps' && PashtoVoice.supported;

  @override
  void dispose() {
    if (_listening) _speech.stop();
    if (_pashtoRecording) PashtoVoice.cancelRecording();
    PashtoVoice.onSilence = null;
    _pulse.dispose();
    super.dispose();
  }

  void _setListening(bool on) {
    if (!mounted) return;
    setState(() => _listening = on);
    on ? _pulse.repeat(reverse: true) : _pulse.stop();
  }

  Future<bool> _ensureReady({bool quiet = false}) async {
    final ok = await _init(
      (s) {
        if (s == SpeechToText.doneStatus || s == SpeechToText.notListeningStatus) _setListening(false);
      },
      (msg, permanent) {
        _setListening(false);
        if (!mounted || !permanent) return;
        final text = msg.contains('no_match')
            ? "Didn't catch that. Try again a little closer to the phone."
            : msg.contains('language')
                ? '${_lang.name} voice typing isn\'t available. Pick another language or add it in Google voice settings.'
                : 'Voice typing stopped ($msg).';
        showInfoSnackBar(context, text, icon: Icons.mic_off_rounded);
      },
    );
    if (!ok && mounted && !quiet) {
      showInfoSnackBar(context, 'Voice typing needs microphone access and Google speech services on this phone.', icon: Icons.mic_off_rounded);
    }
    return ok;
  }

  /// One-time download of the Pashto model, with progress.
  Future<bool> _downloadPashto() async {
    final ok = await showLiquidConfirm(
      context,
      title: 'Download Pashto voice?',
      icon: Icons.download_rounded,
      message: 'Google has no Pashto voice typing, so Life uses its own Pashto speech model. '
          'It\'s a one-time ${PashtoVoice.sizeLabel} download (Wi-Fi recommended). After that it works offline and your voice never leaves the phone.',
      confirmLabel: 'Download',
    );
    if (!ok || !mounted) return false;
    final progress = ValueNotifier<double>(0);
    var cancelled = false;
    String? error;
    final dialog = showLiquidDialog<void>(
      context: context,
      title: 'Downloading Pashto voice',
      icon: Icons.download_rounded,
      dismissible: false,
      builder: (c) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ValueListenableBuilder<double>(
            valueListenable: progress,
            builder: (_, v, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: v, minHeight: 10, color: AppColors.royal, backgroundColor: AppColors.royal.withValues(alpha: 0.12)),
                ),
                const SizedBox(height: 8),
                Text('${(v * 100).toStringAsFixed(0)}% of ${PashtoVoice.sizeLabel}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              cancelled = true;
              Navigator.pop(c);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    try {
      await PashtoVoice.download((v) => progress.value = v, cancelled: () => cancelled);
    } catch (e) {
      error = cancelled ? null : e.toString().replaceFirst('Exception: ', '');
    }
    if (!cancelled && mounted) Navigator.of(context, rootNavigator: true).pop();
    await dialog;
    progress.dispose();
    if (!mounted) return false;
    if (error != null) {
      showInfoSnackBar(context, 'Couldn\'t download Pashto voice: $error', icon: Icons.wifi_off_rounded);
      return false;
    }
    if (cancelled) return false;
    setState(() => _pashtoReady = true);
    PashtoVoice.warmUp();
    showInfoSnackBar(context, 'Pashto voice is ready. Tap the mic and speak پښتو.', icon: Icons.check_circle_rounded);
    return true;
  }

  Future<void> _togglePashto() async {
    if (_transcribing) return;
    if (_pashtoRecording) {
      PashtoVoice.onSilence = null;
      setState(() {
        _pashtoRecording = false;
        _transcribing = true;
        _progress = 0;
      });
      _pulse.stop();
      try {
        final text = await PashtoVoice.stopAndTranscribe(hints: widget.speechHints?.call(), onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        });
        if (!mounted) return;
        if (text.isEmpty) {
          showInfoSnackBar(context, 'Didn\'t hear anything. Hold the phone closer and speak a bit louder.', icon: Icons.mic_off_rounded);
        } else {
          final cur = widget.controller.text;
          final value = '${cur.isEmpty || cur.endsWith(' ') || cur.endsWith('\n') ? cur : '$cur '}$text ';
          widget.controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
          widget.onFinished?.call();
        }
      } catch (e) {
        if (mounted) showInfoSnackBar(context, 'Couldn\'t understand the recording. Please try again.', icon: Icons.mic_off_rounded);
      } finally {
        if (mounted) setState(() => _transcribing = false);
      }
      return;
    }
    if (!_pashtoReady && !await _downloadPashto()) return;
    if (!await PashtoVoice.hasMicPermission()) {
      if (mounted) showInfoSnackBar(context, 'Allow microphone access for Life to use voice typing.', icon: Icons.mic_off_rounded);
      return;
    }
    // Stop by itself once the user pauses.
    PashtoVoice.onSilence = () {
      if (mounted && _pashtoRecording) _togglePashto();
    };
    await PashtoVoice.startRecording();
    if (!mounted) return;
    setState(() => _pashtoRecording = true);
    _pulse.repeat(reverse: true);
    // Keep recordings short enough to transcribe quickly.
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted && _pashtoRecording) _togglePashto();
    });
  }

  Future<void> _toggle() async {
    if (_usePashtoModel) return _togglePashto();
    if (_listening) {
      await _speech.stop();
      return _setListening(false);
    }
    if (!await _ensureReady() || !mounted) return;
    final locale = _deviceLocaleFor(_lang);
    if (locale == null) {
      showInfoSnackBar(
        context,
        '${_lang.name} isn\'t installed for voice typing on this phone. Add it in Settings › Google › Voice, or pick another language.',
        icon: Icons.translate_rounded,
      );
    }
    final text = widget.controller.text;
    _base = text.isEmpty || text.endsWith(' ') || text.endsWith('\n') ? text : '$text ';
    _setListening(true);
    await _speech.listen(
      onResult: (r) {
        final words = r.recognizedWords;
        // Capitalise Latin-script languages only; add the right full stop.
        final cased = words.isEmpty || _lang.rtl ? words : '${words[0].toUpperCase()}${words.substring(1)}';
        final stop = _lang.lang == 'ur' ? '۔ ' : (_lang.rtl ? ' ' : '. ');
        final value = _base + cased + (r.finalResult && words.isNotEmpty ? stop : '');
        widget.controller.value = TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length));
        if (r.finalResult) {
          _base = value;
          if (words.isNotEmpty) widget.onFinished?.call();
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: locale ?? _lang.code,
        partialResults: true,
        listenMode: widget.quick ? ListenMode.confirmation : ListenMode.dictation,
        pauseFor: Duration(milliseconds: widget.quick ? 1500 : 3000),
        listenFor: Duration(minutes: widget.quick ? 1 : 3),
      ),
    );
  }

  Future<void> _pickLanguage() async {
    if (_listening) await _speech.stop();
    // Availability is known once voice typing has been used; don't ask
    // for the microphone just to show the list.
    if (!mounted) return;
    final picked = await showLiquidSheet<VoiceLanguage>(
      context: context,
      title: 'Speak in…',
      builder: (c) {
        final textTheme = Theme.of(c).textTheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Speak in your language and it\'s written in that language. You can translate to English afterwards.',
                style: textTheme.bodyMedium?.copyWith(height: 1.4)),
            const SizedBox(height: 12),
            for (final l in voiceLanguages)
              GlassCard(
                margin: const EdgeInsets.only(bottom: 8),
                highlighted: l.code == _lang.code,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => Navigator.pop(c, l),
                child: Row(
                  children: [
                    SizedBox(width: 74, child: Text(l.native, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          if (l.lang == 'ps' && PashtoVoice.supported)
                            Text(
                              _pashtoReady ? 'Offline Pashto voice installed in Life' : 'Life downloads Pashto voice (${PashtoVoice.sizeLabel}) the first time',
                              style: textTheme.bodyMedium?.copyWith(fontSize: 11.5, color: _pashtoReady ? AppColors.success : AppColors.accentOn(c)),
                            )
                          else if (_deviceLocaleFor(l) == null)
                            Text('Not installed on this phone yet', style: textTheme.bodyMedium?.copyWith(fontSize: 11.5, color: AppColors.warning)),
                        ],
                      ),
                    ),
                    if (l.code == _lang.code) Icon(Icons.check_circle_rounded, color: AppColors.accentOn(c)),
                  ],
                ),
              ),
            if (_pashtoReady)
              TextButton.icon(
                onPressed: () async {
                  final ok = await showLiquidConfirm(c,
                      title: 'Remove Pashto voice?',
                      message: 'Frees ${PashtoVoice.sizeLabel}. You can download it again any time.',
                      confirmLabel: 'Remove',
                      icon: Icons.delete_outline_rounded,
                      destructive: true);
                  if (!ok) return;
                  await PashtoVoice.deleteModel();
                  if (mounted) setState(() => _pashtoReady = false);
                  if (c.mounted) Navigator.pop(c);
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: Text('Remove Pashto voice (${PashtoVoice.sizeLabel})'),
              ),
          ],
        );
      },
    );
    if (picked == null) return;
    await VoiceLanguageSetting.set(picked);
    if (mounted) setState(() => _lang = picked);
    if (picked.lang == 'ps' && _pashtoReady) PashtoVoice.warmUp();
  }

  @override
  Widget build(BuildContext context) {
    final active = _listening || _pashtoRecording;
    final color = active ? AppColors.danger : AppColors.royal;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: 'Voice language: ${_lang.name}. Change',
          excludeSemantics: true,
          child: Pressable(
            onTap: _pickLanguage,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.royal.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(17)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate_rounded, size: 15, color: AppColors.accentOn(context)),
                  const SizedBox(width: 4),
                  Text(_lang.native, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.accentOn(context))),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: active ? 'Stop voice typing' : 'Speak instead of typing',
          child: Semantics(
            button: true,
            label: _transcribing ? 'Writing your speech' : active ? 'Stop voice typing' : 'Voice typing in ${_lang.name}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: _toggle,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) => Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.14),
                    boxShadow: active
                        ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6 + 14 * math.max(_pulse.value, PashtoVoice.level.value), spreadRadius: 2 + 4 * PashtoVoice.level.value)]
                        : null,
                  ),
                  child: _transcribing
                      ? Padding(
                          padding: const EdgeInsets.all(11),
                          child: CircularProgressIndicator(strokeWidth: 2.5, value: _progress > 0 ? _progress / 100 : null, color: AppColors.royal),
                        )
                      : Icon(active ? Icons.stop_rounded : Icons.mic_rounded, color: color),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A text field that switches to right-to-left for Urdu, Pashto, Arabic…
class SmartTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const SmartTextField({super.key, required this.controller, required this.hint, this.maxLines = 5});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        maxLines: maxLines,
        textDirection: isRtlText(value.text) ? TextDirection.rtl : TextDirection.ltr,
        style: isRtlText(value.text) ? const TextStyle(fontSize: 17, height: 1.7) : null,
        decoration: InputDecoration(hintText: hint),
      ),
    );
  }
}

/// "Translate to English" for text written in another language.
class TranslateButton extends StatefulWidget {
  final TextEditingController controller;

  const TranslateButton({super.key, required this.controller});

  @override
  State<TranslateButton> createState() => _TranslateButtonState();
}

class _TranslateButtonState extends State<TranslateButton> {
  bool _busy = false;

  Future<void> _translate() async {
    final text = widget.controller.text.trim();
    if (text.isEmpty) return;
    if (!VoiceLanguageSetting.translateConsent) {
      final ok = await showLiquidConfirm(
        context,
        title: 'Translate online?',
        icon: Icons.translate_rounded,
        message: 'To translate, this text is sent securely to MyMemory, a free online translation service. Nothing else from Life is sent. Continue?',
        confirmLabel: 'Translate',
      );
      if (!ok) return;
      await VoiceLanguageSetting.giveTranslateConsent();
    }
    var lang = VoiceLanguageSetting.current;
    if (lang.lang == 'en' && isRtlText(text)) lang = voiceLanguages.firstWhere((l) => l.lang == 'ur');
    setState(() => _busy = true);
    try {
      final english = await Translator.toEnglish(text, lang.lang);
      if (!mounted) return;
      final choice = await showLiquidDialog<String>(
        context: context,
        title: 'English translation',
        icon: Icons.translate_rounded,
        builder: (c) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(english, style: const TextStyle(fontSize: 15, height: 1.5)),
            const SizedBox(height: 8),
            Text('Machine translation from ${lang.name}. It may not be perfect.', style: Theme.of(c).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
            const SizedBox(height: 18),
            LiquidDialogActions(
              cancelLabel: 'Add below',
              confirmLabel: 'Replace',
              onCancel: () => Navigator.pop(c, 'add'),
              onConfirm: () => Navigator.pop(c, 'replace'),
            ),
          ],
        ),
      );
      if (choice == 'replace') widget.controller.text = english;
      if (choice == 'add') widget.controller.text = '${widget.controller.text.trimRight()}\n\n(English) $english';
    } catch (e) {
      if (mounted) showInfoSnackBar(context, 'Couldn\'t translate right now. Check your internet and try again.', icon: Icons.wifi_off_rounded);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: widget.controller,
      builder: (context, value, _) {
        final show = value.text.trim().isNotEmpty && (VoiceLanguageSetting.current.lang != 'en' || isRtlText(value.text));
        if (!show) return const SizedBox.shrink();
        return Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _busy ? null : _translate,
            icon: _busy ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.translate_rounded, color: AppColors.accentOn(context)),
            label: Text('Translate to English', style: TextStyle(color: AppColors.accentOn(context), fontWeight: FontWeight.w800)),
          ),
        );
      },
    );
  }
}
