import 'package:flutter/material.dart';
import '../../services/app_localizations.dart';

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  int? _expandedIndex;

  List<Map<String, String>> _faqs(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      {'question': l.get('faq_q1'), 'answer': l.get('faq_a1')},
      {'question': l.get('faq_q2'), 'answer': l.get('faq_a2')},
      {'question': l.get('faq_q3'), 'answer': l.get('faq_a3')},
      {'question': l.get('faq_q4'), 'answer': l.get('faq_a4')},
      {'question': l.get('faq_q5'), 'answer': l.get('faq_a5')},
      {'question': l.get('faq_q6'), 'answer': l.get('faq_a6')},
      {'question': l.get('faq_q7'), 'answer': l.get('faq_a7')},
      {'question': l.get('faq_q8'), 'answer': l.get('faq_a8')},
      {'question': l.get('faq_q9'), 'answer': l.get('faq_a9')},
      {'question': l.get('faq_q10'), 'answer': l.get('faq_a10')},
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('faq_title')),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header banner ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFF0A500).withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Text('🫙', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).get('faq_header'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppLocalizations.of(context).get('faq_tap_to_read'),
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── FAQ items ──────────────────────────────────────────────────
          ...List.generate(_faqs(context).length, (i) {
            final faq = _faqs(context)[i];
            final isExpanded = _expandedIndex == i;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isExpanded
                      ? const Color(0xFFF0A500).withValues(alpha: 0.4)
                      : cs.outlineVariant,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: ExpansionTile(
                  key: Key('faq_$i'),
                  initiallyExpanded: isExpanded,
                  onExpansionChanged: (expanded) {
                    setState(() => _expandedIndex = expanded ? i : null);
                  },
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  childrenPadding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  backgroundColor: Colors.transparent,
                  collapsedBackgroundColor: Colors.transparent,
                  iconColor: const Color(0xFFF0A500),
                  collapsedIconColor: cs.onSurface.withValues(alpha: 0.38),
                  title: Text(
                    faq['question']!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isExpanded
                          ? const Color(0xFFF0A500)
                          : cs.onSurface,
                    ),
                  ),
                  children: [
                    Divider(color: cs.outlineVariant, height: 1),
                    const SizedBox(height: 12),
                    Text(
                      faq['answer']!,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.6),
                        fontSize: 13,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
