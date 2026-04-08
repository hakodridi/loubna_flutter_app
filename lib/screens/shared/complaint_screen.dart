import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

const _kGreen  = Color(0xFF2D5F3F);
const _kSage   = Color(0xFF9DBF8A);
const _kRed    = Color(0xFFA85050);
const _kCardBg = Color(0xFF1C261C);
const _kBorder = Color(0xFF2E3D2E);
const _kMuted  = Color(0xFF607060);

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  int? _selectedType;
  final _descCtrl  = TextEditingController();
  bool _submitted  = false;
  bool _loading    = false;

  List<String> _problemTypes(BuildContext context) {
    final l = AppLocalizations.of(context);
    return [
      l.get('complaint_type_1'),
      l.get('complaint_type_2'),
      l.get('complaint_type_3'),
      l.get('complaint_type_4'),
      l.get('complaint_type_5'),
    ];
  }

  // API values (always in English regardless of language)
  static const _problemTypeApiValues = [
    'Order not received',
    'Oil quality issue',
    'Problem with driver',
    'Payment issue',
    'Other',
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).get('complaint_select_type'))),
      );
      return;
    }
    if (_descCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).get('complaint_enter_desc'))),
      );
      return;
    }

    setState(() => _loading = true);
    final result = await ApiService.post('/complaints', {
      'problem_type': _problemTypeApiValues[_selectedType!],
      'description':  _descCtrl.text.trim(),
    });
    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? AppLocalizations.of(context).get('failed_to_submit_ticket'))),
      );
      return;
    }

    setState(() => _submitted = true);
  }

  void _reset() {
    setState(() {
      _selectedType = null;
      _descCtrl.clear();
      _submitted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _kGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kSage),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).get('complaint_screen_title'),
          style: TextStyle(
            color: _kSage,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: _submitted ? _buildSuccess() : _buildForm(),
    );
  }

  Widget _buildSuccess() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kGreen.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF4E9669),
                size: 46,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).get('complaint_submitted'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).get('complaint_submitted_body'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: _kMuted, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _reset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: _kSage,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13)),
                ),
                child: Text(
                  AppLocalizations.of(context).get('complaint_new_ticket'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).get('complaint_go_back'), style: const TextStyle(color: _kMuted)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Info banner ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kRed.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🚨', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).get('complaint_support_title'),
                        style: const TextStyle(
                          color: _kRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        AppLocalizations.of(context).get('complaint_support_body'),
                        style: const TextStyle(
                            color: _kMuted, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Problem type selector ────────────────────────────────────
          Text(
            AppLocalizations.of(context).get('complaint_type_label'),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          ...List.generate(_problemTypes(context).length, (i) {
            final selected = _selectedType == i;
            return GestureDetector(
              onTap: () => setState(() => _selectedType = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: selected
                      ? _kRed.withValues(alpha: 0.07)
                      : cs.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? _kRed.withValues(alpha: 0.55)
                        : cs.outline,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _problemTypes(context)[i],
                        style: TextStyle(
                          color: selected ? _kRed : cs.onSurface.withValues(alpha: 0.7),
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? _kRed : cs.outline,
                          width: 2,
                        ),
                        color: selected
                            ? _kRed.withValues(alpha: 0.15)
                            : Colors.transparent,
                      ),
                      child: selected
                          ? Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _kRed,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),

          // ── Description textarea ─────────────────────────────────────
          Text(
            AppLocalizations.of(context).get('complaint_desc_label'),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLines: 4,
            style: TextStyle(color: cs.onSurface),
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context).get('complaint_desc_hint'),
              hintStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 13),
              contentPadding: const EdgeInsets.all(14),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: cs.outline, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(color: cs.outline, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide(
                    color: _kRed.withValues(alpha: 0.6), width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // ── Submit button ────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
                elevation: 2,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      AppLocalizations.of(context).get('complaint_submit'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
