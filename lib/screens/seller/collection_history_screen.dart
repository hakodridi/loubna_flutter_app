import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

class CollectionHistoryScreen extends StatefulWidget {
  const CollectionHistoryScreen({super.key});

  @override
  State<CollectionHistoryScreen> createState() =>
      _CollectionHistoryScreenState();
}

class _CollectionHistoryScreenState extends State<CollectionHistoryScreen> {
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.get('/collection-orders');
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() {
        _orders = res['data']['data'] ?? res['data'] ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message'] ?? 'Failed to load';
        _loading = false;
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF3FB950);
      case 'pending':
        return const Color(0xFFF0A500);
      case 'accepted':
        return const Color(0xFF58A6FF);
      case 'rejected':
        return Colors.redAccent;
      default:
        return const Color(0xFF8B949E);
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.hourglass_empty;
      case 'accepted':
        return Icons.local_shipping_outlined;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Future<void> _showRatingDialog(dynamic order) async {
    if (order['seller_rating'] != null) return;
    int rating = 0;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final cs = Theme.of(ctx).colorScheme;
          return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(ctx).get('rate_delivery_agent')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(ctx).get('collection_service_question'),
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return GestureDetector(
                    onTap: () => setS(() => rating = i + 1),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: const Color(0xFFF0A500),
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
              child: Text(AppLocalizations.of(ctx).get('cancel')),
            ),
            ElevatedButton(
              onPressed: rating == 0
                  ? null
                  : () async {
                      await ApiService.post('/ratings', {
                        'rateable_type': 'collection_order',
                        'rateable_id': order['id'],
                        'rating': rating,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      _load();
                    },
              child: Text(AppLocalizations.of(ctx).get('submit')),
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
        title: Text(AppLocalizations.of(context).get('collection_history')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF0A500)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                      ),
                      const SizedBox(height: 12),
                      TextButton(onPressed: _load, child: Text(AppLocalizations.of(context).get('retry'))),
                    ],
                  ),
                )
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), size: 56),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(context).get('no_collections_yet'),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppLocalizations.of(context).get('first_pickup_hint'),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24), fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: const Color(0xFFF0A500),
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        itemBuilder: (ctx, i) {
                          final cs = Theme.of(ctx).colorScheme;
                          final order = _orders[i];
                          final status = order['status'] ?? 'pending';
                          final canRate = status == 'completed' &&
                              order['seller_rating'] == null;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _statusColor(status)
                                              .withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _statusIcon(status),
                                          color: _statusColor(status),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '${order['liters'] ?? '?'} ${AppLocalizations.of(context).get('liters')}',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 3,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: _statusColor(status)
                                                        .withValues(alpha: 0.15),
                                                    borderRadius:
                                                        BorderRadius.circular(20),
                                                  ),
                                                  child: Text(
                                                    AppLocalizations.of(context).statusLabel(status),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: _statusColor(status),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              order['address'] ?? '',
                                              style: TextStyle(
                                                color: cs.onSurface.withValues(alpha: 0.54),
                                                fontSize: 12,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (order['created_at'] != null)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 4),
                                                child: Text(
                                                  order['created_at']
                                                      .toString()
                                                      .substring(0, 10),
                                                  style: TextStyle(
                                                    color: cs.onSurface.withValues(alpha: 0.24),
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (canRate)
                                  Container(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: cs.outlineVariant),
                                      ),
                                    ),
                                    child: TextButton.icon(
                                      onPressed: () => _showRatingDialog(order),
                                      icon: const Icon(
                                        Icons.star_outline,
                                        size: 16,
                                        color: Color(0xFFF0A500),
                                      ),
                                      label: Text(
                                        AppLocalizations.of(ctx).get('rate_delivery_agent'),
                                        style: const TextStyle(
                                          color: Color(0xFFF0A500),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (order['seller_rating'] != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(color: cs.outlineVariant),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFFF0A500),
                                          size: 16,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          '${AppLocalizations.of(ctx).get('you_rated')}${order['seller_rating']}/5',
                                          style: TextStyle(
                                            color: cs.onSurface.withValues(alpha: 0.54),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                // Payment receipt — shown when admin has paid
                                if (order['payment_receipt'] != null)
                                  _PaymentReceiptTile(
                                    path: order['payment_receipt'] as String,
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

class _PaymentReceiptTile extends StatelessWidget {
  final String path;
  const _PaymentReceiptTile({required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Old: manual URL construction — broken on Laravel Cloud
    // final url = '${ApiService.storageUrl}/$path';
    // Now: API returns full URL via Storage::url() accessor
    final url = path;
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF3FB950), size: 16),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context).get('payment_received'),
                style: const TextStyle(
                  color: Color(0xFF3FB950),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (ctx) => Dialog(
                backgroundColor: Theme.of(ctx).colorScheme.surface,
                child: InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  height: 80,
                  color: cs.surfaceContainerHighest,
                  alignment: Alignment.center,
                  child: Text(
                    AppLocalizations.of(context).get('receipt_load_error'),
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).get('tap_full_size'),
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.24), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
