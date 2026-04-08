import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';
import '../../services/notification_service.dart';
import 'place_order_screen.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  static const _prefKey = 'dismissed_expired_order_ids';

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _isOverdue(dynamic dateStr) {
    if (dateStr == null) return true;
    try {
      final d = DateTime.parse(dateStr.toString().substring(0, 10));
      final now = DateTime.now();
      return !d.isAfter(DateTime(now.year, now.month, now.day));
    } catch (_) {
      return true;
    }
  }

  /// Whether the order should show the "cancelled / stock unavailable" UI.
  bool _isCancelled(Map order) {
    final s = (order['status'] ?? '') as String;
    return s == 'expired' ||
        s == 'rejected' ||
        (s == 'waitlist' && _isOverdue(order['delivery_date']));
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await ApiService.get('/purchase-orders');
    if (!mounted) return;

    if (res['success'] != true) {
      setState(() {
        _error = res['message'] ?? 'Failed to load orders';
        _loading = false;
      });
      return;
    }

    final raw = res['data'];
    final List<dynamic> orders =
        raw is Map ? ((raw['data'] as List?) ?? []) : ((raw as List?) ?? []);

    setState(() {
      _orders = orders;
      _loading = false;
    });

    // Detect cancelled/expired orders and alert the buyer only once per order
    final cancelled = orders
        .whereType<Map>()
        .where(_isCancelled)
        .toList();

    if (cancelled.isEmpty || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_prefKey) ?? [];
    final newCancelled = cancelled
        .where((o) => !dismissed.contains(o['id'].toString()))
        .toList();

    if (newCancelled.isEmpty || !mounted) return;

    final n = newCancelled.length;
    NotificationService.show(
      id: 9001,
      title: n > 1 ? '$n Orders Could Not Be Fulfilled' : 'Order Could Not Be Fulfilled',
      body: 'Your ${n > 1 ? 'orders were' : 'order was'} cancelled — '
          'oil stock was unavailable by the delivery date. Please re-order.',
    );

    Future.microtask(() {
      if (mounted) _showCancelledDialog(newCancelled);
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':   return const Color(0xFF3FB950);
      case 'pending':     return const Color(0xFFF0A500);
      case 'accepted':    return const Color(0xFF58A6FF);
      case 'in_transit':  return const Color(0xFFAB7AE0);
      case 'rejected':    return Colors.redAccent;
      case 'expired':     return Colors.deepOrangeAccent;
      case 'waitlist':    return const Color(0xFFAB7AE0);
      default:            return const Color(0xFF8B949E);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':   return Icons.check_circle_outline;
      case 'pending':     return Icons.hourglass_empty;
      case 'accepted':    return Icons.local_shipping_outlined;
      case 'in_transit':  return Icons.directions_car_outlined;
      case 'rejected':    return Icons.cancel_outlined;
      case 'expired':     return Icons.event_busy_outlined;
      case 'waitlist':    return Icons.schedule_outlined;
      default:            return Icons.circle_outlined;
    }
  }

  Future<void> _markDismissed(List<Map> orders) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_prefKey) ?? [];
    for (final o in orders) {
      final id = o['id'].toString();
      if (!dismissed.contains(id)) dismissed.add(id);
    }
    await prefs.setStringList(_prefKey, dismissed);
  }

  void _showCancelledDialog(List<Map> newCancelled) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.deepOrangeAccent, size: 26),
              const SizedBox(width: 8),
              Expanded(child: Text(AppLocalizations.of(ctx).get('order_not_fulfilled_title'))),
            ],
          ),
          content: Text(
            AppLocalizations.of(ctx).get('order_not_fulfilled_body'),
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.7), height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _markDismissed(newCancelled);
              },
              child: Text(AppLocalizations.of(ctx).get('dismiss')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _markDismissed(newCancelled);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlaceOrderScreen()),
                ).then((_) => _load());
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3FB950)),
              child: Text(AppLocalizations.of(ctx).get('reorder'),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showRatingDialog(dynamic order) async {
    if (order['buyer_rating'] != null) return;
    int rating = 0;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
            backgroundColor: cs.surface,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(AppLocalizations.of(ctx).get('rate_delivery_agent')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppLocalizations.of(ctx).get('delivery_service_question'),
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.54),
                        fontSize: 13)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    return GestureDetector(
                      onTap: () => setS(() => rating = i + 1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          color: const Color(0xFF3FB950),
                          size: 36,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(AppLocalizations.of(ctx).get('cancel'))),
              ElevatedButton(
                onPressed: rating == 0
                    ? null
                    : () async {
                        await ApiService.post('/ratings', {
                          'rateable_type': 'purchase_order',
                          'rateable_id': order['id'],
                          'rating': rating,
                        });
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3FB950)),
                child: Text(AppLocalizations.of(ctx).get('submit'),
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('my_orders')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlaceOrderScreen()),
        ).then((_) => _load()),
        backgroundColor: const Color(0xFF3FB950),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_shopping_cart),
        label: Text(AppLocalizations.of(context).get('place_order_label'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF3FB950)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 40),
                      const SizedBox(height: 8),
                      Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.54))),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: _load, child: Text(AppLocalizations.of(context).get('retry'))),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shopping_bag_outlined,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.24),
                              size: 56),
                          const SizedBox(height: 12),
                          Text(AppLocalizations.of(context).get('no_orders_yet'),
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.38),
                                  fontSize: 16)),
                          const SizedBox(height: 80),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFF3FB950),
                      onRefresh: _load,
                      child: ListView.builder(
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final cs = Theme.of(ctx).colorScheme;
                          final order = _orders[i] as Map;
                          final status =
                              (order['status'] ?? 'pending') as String;
                          final cancelled = _isCancelled(order);
                          final canRate = status == 'completed' &&
                              order['buyer_rating'] == null;

                          final totalPrice = order['total_price'] != null
                              ? double.tryParse(
                                  order['total_price'].toString())
                              : null;
                          final deliveryDate =
                              order['delivery_date'] != null
                                  ? order['delivery_date']
                                      .toString()
                                      .substring(0, 10)
                                  : null;

                          final Color statusColor = _statusColor(status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cancelled
                                    ? Colors.deepOrangeAccent
                                        .withValues(alpha: 0.4)
                                    : cs.outlineVariant,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: statusColor
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(_statusIcon(status),
                                            color: statusColor, size: 22),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text(
                                                  '${AppLocalizations.of(ctx).get('order_hash')}${order['id']}',
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 15),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: statusColor
                                                        .withValues(
                                                            alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(
                                                    AppLocalizations.of(context).statusLabel(status),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: statusColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${order['liters'] ?? '?'}${AppLocalizations.of(ctx).get('liter_unit')} ${AppLocalizations.of(ctx).get('ordered')}'
                                              '${totalPrice != null ? ' · ${totalPrice.toStringAsFixed(0)} DZD' : ''}',
                                              style: TextStyle(
                                                  color: cs.onSurface
                                                      .withValues(alpha: 0.54),
                                                  fontSize: 12),
                                            ),
                                            if (deliveryDate != null)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                    top: 3),
                                                child: Row(children: [
                                                  Icon(
                                                      Icons
                                                          .local_shipping_outlined,
                                                      size: 12,
                                                      color: cs.onSurface
                                                          .withValues(
                                                              alpha: 0.24)),
                                                  const SizedBox(width: 4),
                                                  Text('${AppLocalizations.of(ctx).get('deliver_prefix')}$deliveryDate',
                                                      style: TextStyle(
                                                          color: cs.onSurface
                                                              .withValues(
                                                                  alpha: 0.38),
                                                          fontSize: 11)),
                                                ]),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // ── Cancelled / waitlist banner ──────────────
                                if (cancelled || status == 'waitlist')
                                  _CancelledBanner(
                                    isCancelled: cancelled,
                                    onReorder: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const PlaceOrderScreen()),
                                    ).then((_) => _load()),
                                  ),

                                // ── Rating row ───────────────────────────────
                                if (canRate)
                                  Container(
                                    decoration: BoxDecoration(
                                        border: Border(
                                            top: BorderSide(
                                                color: cs.outlineVariant))),
                                    child: TextButton.icon(
                                      onPressed: () =>
                                          _showRatingDialog(order),
                                      icon: const Icon(Icons.star_outline,
                                          size: 16,
                                          color: Color(0xFF3FB950)),
                                      label: Text(AppLocalizations.of(ctx).get('rate_delivery_agent'),
                                          style: const TextStyle(
                                              color: Color(0xFF3FB950),
                                              fontSize: 13)),
                                    ),
                                  ),

                                if (order['buyer_rating'] != null)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 0, 16, 12),
                                    child: Row(children: [
                                      const Icon(Icons.star_rounded,
                                          color: Color(0xFF3FB950), size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                          '${AppLocalizations.of(ctx).get('you_rated')}${order['buyer_rating']}/5',
                                          style: TextStyle(
                                              color: cs.onSurface
                                                  .withValues(alpha: 0.54),
                                              fontSize: 12)),
                                    ]),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CancelledBanner extends StatelessWidget {
  final bool isCancelled;
  final VoidCallback onReorder;

  const _CancelledBanner(
      {required this.isCancelled, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    final color =
        isCancelled ? Colors.deepOrangeAccent : const Color(0xFFAB7AE0);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
                isCancelled
                    ? Icons.event_busy_outlined
                    : Icons.schedule_outlined,
                size: 14,
                color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                isCancelled
                    ? AppLocalizations.of(context).get('order_cancelled_status')
                    : AppLocalizations.of(context).get('order_waitlist_status'),
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            isCancelled
                ? AppLocalizations.of(context).get('order_cancelled_body')
                : AppLocalizations.of(context).get('order_waitlist_body'),
            style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 11,
                height: 1.4),
          ),
          if (isCancelled) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: onReorder,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(8)),
                child: Text(AppLocalizations.of(context).get('reorder'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
