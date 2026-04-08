import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/app_localizations.dart';

class PaymentScreen extends StatelessWidget {
  final int orderId;
  final double liters;
  final double totalPrice;
  final String deliveryDate;
  final String address;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.liters,
    required this.totalPrice,
    required this.deliveryDate,
    required this.address,
  });

  static const _accent = Color(0xFF3FB950);

  // Replace these with your real payment details
  static const _ccp = '0012345678 / Clé 01';
  static const _baridimob = '00799999001234567801';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('payment')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Order confirmed banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        color: _accent,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).get('order_confirmed'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AppLocalizations.of(context).get('order_placed_prefix')}$orderId${AppLocalizations.of(context).get('order_placed_suffix')}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Order details
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).get('order_details'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(label: AppLocalizations.of(context).get('order_id'), value: '#$orderId'),
                    _DetailRow(label: AppLocalizations.of(context).get('quantity'), value: '${liters.toStringAsFixed(1)} ${AppLocalizations.of(context).get('liter_unit')}'),
                    _DetailRow(
                      label: AppLocalizations.of(context).get('total_amount'),
                      value: '${totalPrice.toStringAsFixed(2)} DZD',
                      bold: true,
                      valueColor: _accent,
                    ),
                    _DetailRow(label: AppLocalizations.of(context).get('delivery_date'), value: deliveryDate),
                    _DetailRow(
                      label: AppLocalizations.of(context).get('address_label'),
                      value: address,
                      multiline: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Payment instructions
              Text(
                AppLocalizations.of(context).get('payment_instructions'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).get('payment_instructions_body'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 16),

              // CCP card
              _PaymentMethodCard(
                icon: Icons.account_balance_outlined,
                title: AppLocalizations.of(context).get('ccp_cheque_postal'),
                detail: _ccp,
              ),
              const SizedBox(height: 12),

              // BaridiMob card
              _PaymentMethodCard(
                icon: Icons.phone_android_outlined,
                title: AppLocalizations.of(context).get('baridimob'),
                detail: _baridimob,
              ),
              const SizedBox(height: 32),

              // Amount to pay
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _accent.withValues(alpha: 0.2),
                      _accent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _accent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context).get('amount_to_pay'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${totalPrice.toStringAsFixed(2)} DZD',
                      style: const TextStyle(
                        color: _accent,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton.icon(
                onPressed: () {
                  // Pop back to the orders screen
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                icon: const Icon(Icons.done_all),
                label: Text(AppLocalizations.of(context).get('done_go_to_orders')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  final bool multiline;

  const _DetailRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
    this.multiline = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment:
            multiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _PaymentMethodCard({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF3FB950).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF3FB950), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.54),
                    fontSize: 13,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy_outlined,
                size: 18, color: cs.onSurface.withValues(alpha: 0.38)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: detail));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context).get('copied_to_clipboard')),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
