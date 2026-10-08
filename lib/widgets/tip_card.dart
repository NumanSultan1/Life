import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../services/hive_service.dart';
import '../theme/app_colors.dart';
import 'liquid/liquid.dart';

/// A one-time hint that disappears for good once dismissed.
class TipCard extends StatefulWidget {
  final String id;
  final String text;
  final IconData icon;
  final bool onLiquid;
  final EdgeInsetsGeometry margin;

  const TipCard({super.key, required this.id, required this.text, this.icon = Icons.lightbulb_rounded, this.onLiquid = false, this.margin = const EdgeInsets.only(bottom: 14)});

  @override
  State<TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<TipCard> {
  Box get _box => Hive.box(HiveService.settingsBox);
  String get _key => '${HiveService.getCurrentUser()}_tip_${widget.id}';

  @override
  Widget build(BuildContext context) {
    if (_box.get(_key) == true) return const SizedBox.shrink();
    final fg = widget.onLiquid ? Colors.white : null;
    return GlassCard(
      onLiquid: widget.onLiquid,
      margin: widget.margin,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      child: Row(
        children: [
          Icon(widget.icon, color: widget.onLiquid ? const Color(0xFFFFE082) : AppColors.warning),
          const SizedBox(width: 10),
          Expanded(child: Text(widget.text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13, height: 1.35))),
          IconButton(
            tooltip: 'Got it, hide this tip',
            icon: Icon(Icons.close_rounded, size: 18, color: fg),
            onPressed: () {
              _box.put(_key, true);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}
