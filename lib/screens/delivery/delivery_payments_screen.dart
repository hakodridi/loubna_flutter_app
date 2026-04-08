import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

class DeliveryPaymentsScreen extends StatefulWidget {
  const DeliveryPaymentsScreen({super.key});

  @override
  State<DeliveryPaymentsScreen> createState() => _DeliveryPaymentsScreenState();
}

class _DeliveryPaymentsScreenState extends State<DeliveryPaymentsScreen> {
  List<dynamic> _payments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _loading = true);
    final result = await ApiService.get('/delivery/payments');
    if (mounted) {
      setState(() {
        _loading = false;
        if (result['success'] == true) {
          final data = result['data'];
          _payments = data is List ? data : [];
        }
      });
    }
  }

  double get _totalPaid => _payments.fold(
        0.0,
        (sum, p) => sum + (double.tryParse(p['amount']?.toString() ?? '0') ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: cs.surface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).get('my_payments'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF58A6FF),
              ),
            ),
            if (!_loading && _payments.isNotEmpty)
              Text(
                '${AppLocalizations.of(context).get('total_received_prefix')}${_totalPaid.toStringAsFixed(2)} DZD',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.54),
                ),
              ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
            )
          : RefreshIndicator(
              color: const Color(0xFF58A6FF),
              onRefresh: _loadPayments,
              child: _payments.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 52,
                                  color: cs.onSurface.withValues(alpha: 0.24),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppLocalizations.of(context).get('no_payments_yet'),
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.38),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _payments.length,
                      itemBuilder: (ctx, i) {
                        final p = _payments[i];
                        final amount = double.tryParse(p['amount']?.toString() ?? '0') ?? 0;
                        final date = p['created_at']?.toString().substring(0, 10) ?? '—';
                        final notes = p['notes'] as String?;
                        final photo = p['receipt_photo'] as String?;
                        final month = p['payment_month'] as String?;
                        return _PaymentCard(
                          amount: amount,
                          date: date,
                          paymentMonth: month,
                          notes: notes,
                          photoPath: photo,
                        );
                      },
                    ),
            ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final double amount;
  final String date;
  final String? paymentMonth;
  final String? notes;
  final String? photoPath;

  const _PaymentCard({
    required this.amount,
    required this.date,
    this.paymentMonth,
    this.notes,
    this.photoPath,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF3FB950).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF3FB950),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${amount.toStringAsFixed(2)} DZD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF3FB950),
                        ),
                      ),
                      if (paymentMonth != null && paymentMonth!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined,
                                size: 12, color: Color(0xFFF0A500)),
                            const SizedBox(width: 4),
                            Text(
                              _formatMonth(paymentMonth!),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFF0A500),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined,
                              size: 12, color: cs.onSurface.withValues(alpha: 0.38)),
                          const SizedBox(width: 4),
                          Text(
                            '${AppLocalizations.of(context).get('paid_on_prefix')}$date',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withValues(alpha: 0.54),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (notes != null && notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                notes!,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          if (photoPath != null && photoPath!.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 14, color: cs.onSurface.withValues(alpha: 0.38)),
                      const SizedBox(width: 6),
                      Text(
                        AppLocalizations.of(context).get('payment_receipt_label'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _openFullReceipt(context, photoPath!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        // '${ApiService.storageUrl}/$photoPath',
                        photoPath!,  // API now returns full URL via Storage::url() accessor
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (ctx, child, progress) => progress == null
                            ? child
                            : Container(
                                height: 180,
                                color: cs.onSurface.withValues(alpha: 0.05),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: progress.expectedTotalBytes != null
                                        ? progress.cumulativeBytesLoaded /
                                            progress.expectedTotalBytes!
                                        : null,
                                    color: const Color(0xFF3FB950),
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                        errorBuilder: (_, __, ___) => Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              AppLocalizations.of(context).get('receipt_unavailable'),
                              style: TextStyle(
                                color: cs.onSurface.withValues(alpha: 0.38),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    AppLocalizations.of(context).get('tap_full_size'),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMonth(String yyyyMm) {
    try {
      final parts = yyyyMm.split('-');
      const months = [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      final m = int.tryParse(parts[1]) ?? 0;
      return '${months[m]} ${parts[0]}';
    } catch (_) {
      return yyyyMm;
    }
  }

  void _openFullReceipt(BuildContext context, String path) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Builder(builder: (ctx) => Text(AppLocalizations.of(ctx).get('receipt'), style: const TextStyle(color: Colors.white))),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                // '${ApiService.storageUrl}/$path',
                path,  // API now returns full URL via Storage::url() accessor
                errorBuilder: (ctx2, __, ___) => Text(
                  AppLocalizations.of(ctx2).get('failed_to_load_image'),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
