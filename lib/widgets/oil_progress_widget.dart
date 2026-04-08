import 'package:flutter/material.dart';
import '../services/app_localizations.dart';

class OilProgressWidget extends StatelessWidget {
  final double litersCollected;

  const OilProgressWidget({super.key, required this.litersCollected});

  static const double threshold = 15.0;
  static const List<double> milestones = [0, 5, 10, 15];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    final progress  = (litersCollected / threshold).clamp(0.0, 1.0);
    final remaining = (threshold - litersCollected).clamp(0.0, threshold);
    final percent   = (progress * 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFF0A500).withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF0A500).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.get('collection_progress'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0A500).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${litersCollected.toStringAsFixed(1)}L / ${threshold.toInt()}L',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF0A500),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l.get('cycle_description'),
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.45),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Progress bar with milestones
          SizedBox(
            height: 36,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                // Background track
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Gradient fill
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB07D00), Color(0xFFF0A500), Color(0xFFFFD060)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF0A500).withValues(alpha: 0.5),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                  ),
                ),
                // Milestone dots
                ...milestones.map((ml) {
                  final frac = ml / threshold;
                  final reached = litersCollected >= ml;
                  return Align(
                    alignment: Alignment(frac * 2 - 1, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: reached ? 14 : 10,
                          height: reached ? 14 : 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: reached
                                ? const Color(0xFFF0A500)
                                : cs.onSurface.withValues(alpha: 0.24),
                            border: Border.all(
                              color: reached
                                  ? Colors.white
                                  : cs.onSurface.withValues(alpha: 0.24),
                              width: 1.5,
                            ),
                            boxShadow: reached
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFFF0A500)
                                          .withValues(alpha: 0.6),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${ml.toInt()}L',
                          style: TextStyle(
                            fontSize: 9,
                            color: reached
                                ? const Color(0xFFF0A500)
                                : cs.onSurface.withValues(alpha: 0.38),
                            fontWeight: reached
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Stats row
          Row(
            children: [
              _StatChip(
                label: l.get('cycle_progress'),
                value: '$percent%',
                icon: Icons.loop_rounded,
                color: const Color(0xFFF0A500),
              ),
              const SizedBox(width: 10),
              _StatChip(
                label: l.get('to_complete'),
                value: '${remaining.toStringAsFixed(1)}${l.get('l_left')}',
                icon: Icons.local_fire_department_outlined,
                color: cs.onSurface.withValues(alpha: 0.54),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Threshold banner
          if (litersCollected >= threshold)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF0A500), Color(0xFFFFD060)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.black, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.get('cycle_complete_banner'),
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    color: Color(0xFFF0A500),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${l.get('collect_more_prefix')}${remaining.toStringAsFixed(1)}${l.get('collect_more_suffix')}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.54),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.38)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
