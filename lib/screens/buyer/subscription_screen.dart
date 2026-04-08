import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String _selectedPlan = 'basic';
  XFile? _receiptFile;
  Uint8List? _receiptBytes; // used for web preview
  bool _loading = false;
  bool _success = false;
  String? _error;

  // Prices loaded from API; fallback to defaults while loading
  Map<String, int> _livePrices = {'basic': 10000, 'premium': 20000, 'vip': 30000};

  static const List<Map<String, dynamic>> _planMeta = [
    {
      'key': 'basic',
      'label': 'Basic',
      'liters': 100,
      'priority': 1,
      'color': Color(0xFF58A6FF),
      'icon': Icons.water_drop_outlined,
      'featureKeys': ['plan_feature_basic_1', 'plan_feature_basic_2', 'plan_feature_basic_3'],
    },
    {
      'key': 'premium',
      'label': 'Premium',
      'liters': 200,
      'priority': 2,
      'color': Color(0xFF3FB950),
      'icon': Icons.verified_outlined,
      'featureKeys': ['plan_feature_premium_1', 'plan_feature_premium_2', 'plan_feature_premium_3'],
    },
    {
      'key': 'vip',
      'label': 'VIP',
      'liters': 300,
      'priority': 3,
      'color': Color(0xFFF0A500),
      'icon': Icons.workspace_premium_outlined,
      'featureKeys': ['plan_feature_vip_1', 'plan_feature_vip_2', 'plan_feature_vip_3'],
    },
  ];

  List<Map<String, dynamic>> get _plans => _planMeta.map((p) {
    return {...p, 'price': _livePrices[p['key']] ?? 0};
  }).toList();

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  Future<void> _fetchPrices() async {
    try {
      final res = await ApiService.get('/subscriptions/plans');
      if (res['success'] == true) {
        final plans = res['data']?['plans'] as Map<String, dynamic>? ?? {};
        if (mounted) {
          setState(() {
            _livePrices = {
              'basic':   (plans['basic']?['price'] as num?)?.toInt()   ?? 10000,
              'premium': (plans['premium']?['price'] as num?)?.toInt() ?? 20000,
              'vip':     (plans['vip']?['price'] as num?)?.toInt()     ?? 30000,
            };
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _receiptFile = picked;
        _receiptBytes = bytes;
      });
    }
  }

  Future<void> _subscribe() async {
    if (_receiptFile == null) {
      setState(() => _error = AppLocalizations.of(context).get('val_upload_receipt'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ApiService.uploadFile(
      '/subscriptions',
      _receiptFile!,
      {'plan': _selectedPlan},
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() => _success = true);
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('subscription_failed'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('choose_a_plan')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _success ? _buildSuccess() : _buildContent(),
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
                color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: Color(0xFF3FB950),
                size: 48,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context).get('subscription_submitted'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).get('subscription_submitted_body'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('back_to_home')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptPreview() {
    final cs = Theme.of(context).colorScheme;
    if (_receiptBytes != null) {
      // Works on both web and mobile
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.memory(
              _receiptBytes!,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _receiptFile = null;
                _receiptBytes = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.upload_file_outlined, color: cs.onSurface.withValues(alpha: 0.38), size: 36),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).get('upload_baridimob_receipt'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).get('tap_to_select_gallery'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.24), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Plan cards
          ..._plans.map((plan) {
            final isSelected = _selectedPlan == plan['key'];
            final color = plan['color'] as Color;
            return GestureDetector(
              onTap: () => setState(() => _selectedPlan = plan['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : cs.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : cs.outline,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.15),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            plan['icon'] as IconData,
                            color: color,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan['label'] as String,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: isSelected ? color : cs.onSurface,
                                ),
                              ),
                              Text(
                                AppLocalizations.of(context).get('plan_liters_month').replaceAll('{liters}', '${plan['liters']}'),
                                style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.54),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${plan['price']} DZD',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? color : cs.onSurface,
                              ),
                            ),
                            Text(
                              AppLocalizations.of(context).get('per_month'),
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.38),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        if (isSelected)
                          Icon(Icons.check_circle, color: color, size: 22)
                        else
                          Icon(
                            Icons.radio_button_unchecked,
                            color: cs.onSurface.withValues(alpha: 0.24),
                            size: 22,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...((plan['featureKeys'] as List<String>).map((key) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: isSelected ? color : cs.onSurface.withValues(alpha: 0.38),
                                size: 15,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                AppLocalizations.of(context).get(key),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? cs.onSurface.withValues(alpha: 0.7) : cs.onSurface.withValues(alpha: 0.38),
                                ),
                              ),
                            ],
                          ),
                        ))),
                    if (plan['priority'] as int > 1)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${AppLocalizations.of(context).get('priority_score')}${plan['priority']}',
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          // Payment section
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payment, color: Color(0xFF3FB950), size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context).get('payment_ccp_title'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).get('payment_ccp_body'),
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.onSurface.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${AppLocalizations.of(context).get('ccp_account_label')} 00123456789 / Clé 45',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Color(0xFF3FB950),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context).get('account_name_label')} OilTrade Algeria',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Receipt upload
          GestureDetector(
            onTap: _pickReceipt,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _receiptFile != null
                      ? const Color(0xFF3FB950)
                      : cs.outline,
                ),
              ),
              child: _buildReceiptPreview(),
            ),
          ),
          const SizedBox(height: 16),

          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _subscribe,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3FB950),
                foregroundColor: Colors.white,
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(_loading ? AppLocalizations.of(context).get('submitting') : AppLocalizations.of(context).get('subscribe_now')),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
