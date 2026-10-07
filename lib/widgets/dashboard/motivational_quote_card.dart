import 'package:flutter/material.dart';
import '../liquid/liquid.dart';

class MotivationalQuoteCard extends StatelessWidget {
  const MotivationalQuoteCard({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onLiquid: true,
      highlighted: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.format_quote_rounded, size: 26),
              SizedBox(width: 6),
              Text('DAILY MOTIVATION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, letterSpacing: 1.4)),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '"We are what we repeatedly do. Excellence, then, is not an act, but a habit."',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic, height: 1.45),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('— Will Durant', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
