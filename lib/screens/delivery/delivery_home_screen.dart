import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../auth/login_screen.dart';
import '../shared/organic_products_screen.dart';
import '../shared/faq_screen.dart';
import '../shared/profile_screen.dart';
import 'delivery_order_detail_screen.dart';
import 'delivery_payments_screen.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late TabController _tabController;
  String _userName = '';
  List<dynamic> _collections = [];
  List<dynamic> _purchases = [];
  Map<String, dynamic>? _stats;
  bool _loading = true;
  Position? _agentPosition;
  final Set<int> _accepting = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initPosition();
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _agentPosition = pos);
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final info = await AuthService.getUserInfo();
    setState(() => _userName = info['name'] ?? '');

    final results = await Future.wait([
      ApiService.get('/collection-orders?status=assigned'),
      ApiService.get('/purchase-orders?status=assigned'),
      ApiService.get('/delivery/stats'),
    ]);

    if (results[0]['success'] == true) {
      setState(() {
        _collections = results[0]['data']['data'] ?? results[0]['data'] ?? [];
      });
    }
    if (results[1]['success'] == true) {
      setState(() {
        _purchases = results[1]['data']['data'] ?? results[1]['data'] ?? [];
      });
    }
    if (results[2]['success'] == true) {
      setState(() => _stats = results[2]['data']);
    }
    setState(() => _loading = false);
  }

  double _distanceKm(dynamic order) {
    final lat = order['latitude'];
    final lng = order['longitude'];
    if (lat == null || lng == null || _agentPosition == null) {
      return double.infinity;
    }
    return _haversineKm(
      _agentPosition!.latitude,
      _agentPosition!.longitude,
      (lat as num).toDouble(),
      (lng as num).toDouble(),
    );
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) *
            cos(lat2 * pi / 180) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  List<dynamic> _sorted(List<dynamic> orders) {
    final list = List<dynamic>.from(orders);
    list.sort((a, b) => _distanceKm(a).compareTo(_distanceKm(b)));
    return list;
  }

  Future<void> _acceptInPlace(dynamic order, String type) async {
    final id = order['id'] as int;
    setState(() => _accepting.add(id));
    final endpoint =
        type == 'collection' ? '/collection-orders' : '/purchase-orders';
    final result = await ApiService.patch('$endpoint/$id/accept', {});
    if (!mounted) return;
    setState(() => _accepting.remove(id));
    if (result['success'] == true) {
      final l = AppLocalizations.of(context);
      NotificationService.show(
        id: order['id'] ?? 0,
        title: l.get('notif_task_accepted'),
        body: '${type == 'collection' ? l.get('notif_collection_label') : l.get('notif_purchase_label')} #${order['id']} ${l.get('notif_accepted_suffix')}',
      );
      _showCenterToast(context, l.get('toast_task_accepted'), success: true);
      _loadData();
    } else {
      _showCenterToast(context, result['message'] ?? AppLocalizations.of(context).get('failed_to_accept_task'), success: false);
    }
  }

  void _showCenterToast(BuildContext ctx, String msg, {required bool success}) {
    final color = success ? const Color(0xFF3FB950) : Colors.redAccent;
    final icon  = success ? Icons.check_circle_outline : Icons.cancel_outlined;
    showDialog(
      context: ctx,
      barrierColor: Colors.black26,
      barrierDismissible: false,
      builder: (dCtx) {
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (dCtx.mounted) Navigator.of(dCtx).pop();
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 6))],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(msg, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(ctx).get('sign_out')),
        content: Text(
          AppLocalizations.of(ctx).get('sign_out_confirm_body'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppLocalizations.of(ctx).get('sign_out'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
      },
    );
    if (confirm == true) {
      await AuthService.logout();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedCollections = _sorted(_collections);
    final sortedPurchases = _sorted(_purchases);

    final pages = [
      _TasksHomeTab(
        userName: _userName,
        collections: sortedCollections,
        purchases: sortedPurchases,
        stats: _stats,
        loading: _loading,
        tabController: _tabController,
        accepting: _accepting,
        distanceKm: _distanceKm,
        onRefresh: _loadData,
        onAccept: _acceptInPlace,
        onOrderTap: (order, type) async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DeliveryOrderDetailScreen(
                order: order,
                orderType: type,
              ),
            ),
          );
          _loadData();
        },
      ),
      const OrganicProductsScreen(),
      const DeliveryPaymentsScreen(),
      const FaqScreen(),
      ProfileScreen(onLogout: _logout),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: const Color(0xFF58A6FF),
        unselectedItemColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11,
        unselectedFontSize: 10,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: AppLocalizations.of(context).get('home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.eco_outlined),
            activeIcon: const Icon(Icons.eco),
            label: AppLocalizations.of(context).get('products'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            activeIcon: const Icon(Icons.account_balance_wallet),
            label: AppLocalizations.of(context).get('payments'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.help_outline),
            activeIcon: const Icon(Icons.help),
            label: AppLocalizations.of(context).get('faq_title'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: AppLocalizations.of(context).get('profile'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TasksHomeTab extends StatelessWidget {
  final String userName;
  final List<dynamic> collections;
  final List<dynamic> purchases;
  final Map<String, dynamic>? stats;
  final bool loading;
  final TabController tabController;
  final Set<int> accepting;
  final double Function(dynamic) distanceKm;
  final VoidCallback onRefresh;
  final Future<void> Function(dynamic, String) onAccept;
  final Future<void> Function(dynamic, String) onOrderTap;

  const _TasksHomeTab({
    required this.userName,
    required this.collections,
    required this.purchases,
    required this.stats,
    required this.loading,
    required this.tabController,
    required this.accepting,
    required this.distanceKm,
    required this.onRefresh,
    required this.onAccept,
    required this.onOrderTap,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: const Color(0xFF58A6FF),
      onRefresh: () async => onRefresh(),
      child: NestedScrollView(
        headerSliverBuilder: (ctx, _) => [
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            backgroundColor: Theme.of(ctx).colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 16, bottom: 52, right: 16),
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OilTrade',
                    style: TextStyle(
                      color: Color(0xFF58A6FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${AppLocalizations.of(ctx).get('hello')}, ${userName.split(' ').first}',
                    style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.54),
                        fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF58A6FF).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(ctx).get('agent_badge'),
                    style: const TextStyle(
                      color: Color(0xFF58A6FF),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            bottom: TabBar(
              controller: tabController,
              indicatorColor: const Color(0xFF58A6FF),
              labelColor: const Color(0xFF58A6FF),
              unselectedLabelColor: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.38),
              tabs: [
                Tab(text: '${AppLocalizations.of(ctx).get('collections')} (${collections.length})'),
                Tab(text: '${AppLocalizations.of(ctx).get('purchases_tab')} (${purchases.length})'),
              ],
            ),
          ),
        ],
        body: loading
            ? const Center(
                child:
                    CircularProgressIndicator(color: Color(0xFF58A6FF)),
              )
            : Column(
                children: [
                  if (stats != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Row(
                        children: [
                          _StatItem(
                            label: AppLocalizations.of(context).get('completed'),
                            value: '${stats!['completed_count'] ?? 0}',
                            color: const Color(0xFF3FB950),
                          ),
                          _StarRatingItem(
                            rating: stats!['avg_rating'] != null
                                ? (stats!['avg_rating'] as num).toDouble()
                                : null,
                          ),
                          _StatItem(
                            label: AppLocalizations.of(context).get('active'),
                            value:
                                '${collections.length + purchases.length}',
                            color: const Color(0xFF58A6FF),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: tabController,
                      children: [
                        _TaskList(
                          orders: collections,
                          type: 'collection',
                          emptyMessage: AppLocalizations.of(context).get('no_collection_tasks'),
                          accepting: accepting,
                          distanceKm: distanceKm,
                          onAccept: (o) => onAccept(o, 'collection'),
                          onTap: (o) => onOrderTap(o, 'collection'),
                        ),
                        _TaskList(
                          orders: purchases,
                          type: 'purchase',
                          emptyMessage: AppLocalizations.of(context).get('no_purchase_tasks'),
                          accepting: accepting,
                          distanceKm: distanceKm,
                          onAccept: (o) => onAccept(o, 'purchase'),
                          onTap: (o) => onOrderTap(o, 'purchase'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StarRatingItem extends StatelessWidget {
  final double? rating;

  const _StarRatingItem({this.rating});

  @override
  Widget build(BuildContext context) {
    final r = (rating ?? 0).round().clamp(0, 5);
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              5,
              (i) => Icon(
                i < r ? Icons.star : Icons.star_border,
                color: const Color(0xFFF0A500),
                size: 16,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppLocalizations.of(context).get('avg_rating'),
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(label,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<dynamic> orders;
  final String type;
  final String emptyMessage;
  final Set<int> accepting;
  final double Function(dynamic) distanceKm;
  final Future<void> Function(dynamic) onAccept;
  final Future<void> Function(dynamic) onTap;

  const _TaskList({
    required this.orders,
    required this.type,
    required this.emptyMessage,
    required this.accepting,
    required this.distanceKm,
    required this.onAccept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'collection'
                  ? Icons.water_drop_outlined
                  : Icons.local_shipping_outlined,
              color: cs.onSurface.withValues(alpha: 0.24),
              size: 52,
            ),
            const SizedBox(height: 12),
            Text(emptyMessage,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (ctx, i) {
        final order = orders[i];
        final id = order['id'] as int? ?? 0;
        return _TaskCard(
          order: order,
          type: type,
          isAccepting: accepting.contains(id),
          distanceKm: distanceKm(order),
          onAccept: () => onAccept(order),
          onTap: () => onTap(order),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final dynamic order;
  final String type;
  final bool isAccepting;
  final double distanceKm;
  final VoidCallback onAccept;
  final VoidCallback onTap;

  const _TaskCard({
    required this.order,
    required this.type,
    required this.isAccepting,
    required this.distanceKm,
    required this.onAccept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String? ?? 'pending';
    final isCollection = type == 'collection';
    final address = order['address'] as String? ?? 'No address';
    final time = isCollection
        ? (order['pickup_time'] ?? order['pickup_date'] ?? '—')
        : (order['delivery_time'] ?? order['delivery_date'] ?? '—');
    final hasDistance = distanceKm != double.infinity;
    final distStr =
        hasDistance ? '${distanceKm.toStringAsFixed(1)} km' : '— km';

    final l = AppLocalizations.of(context);
    final Color statusColor;
    final String statusLabel;
    switch (status) {
      case 'assigned':
        statusColor = const Color(0xFFF0A500);
        statusLabel = l.get('status_new');
      case 'accepted':
        statusColor = const Color(0xFF58A6FF);
        statusLabel = l.get('accepted');
      case 'in_transit':
        statusColor = const Color(0xFFAB7AE0);
        statusLabel = l.get('in_transit');
      default:
        statusColor = const Color(0xFF8B949E);
        statusLabel = l.statusLabel(status);
    }

    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF58A6FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCollection
                        ? Icons.water_drop_outlined
                        : Icons.local_shipping_outlined,
                    color: const Color(0xFF58A6FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCollection
                            ? '${l.get('collection_hash')}${order['id']} · ${order['liters']}${l.get('liter_unit')}'
                            : '${l.get('purchase_hash')}${order['id']} · ${order['liters']}${l.get('liter_unit')}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: cs.onSurface.withValues(alpha: 0.24)),
              ],
            ),
            const SizedBox(height: 12),
            // Pickup address
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: cs.onSurface.withValues(alpha: 0.38)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Time + Distance chip
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: cs.onSurface.withValues(alpha: 0.38)),
                const SizedBox(width: 6),
                Text(time.toString(),
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: hasDistance
                        ? const Color(0xFF3FB950).withValues(alpha: 0.1)
                        : cs.onSurface.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasDistance
                          ? const Color(0xFF3FB950).withValues(alpha: 0.35)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.near_me_outlined,
                          size: 11,
                          color: hasDistance
                              ? const Color(0xFF3FB950)
                              : cs.onSurface.withValues(alpha: 0.38)),
                      const SizedBox(width: 4),
                      Text(
                        distStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasDistance
                              ? const Color(0xFF3FB950)
                              : cs.onSurface.withValues(alpha: 0.38),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Accept Task button — only for assigned orders
            if (status == 'assigned') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isAccepting ? null : onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58A6FF),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isAccepting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : Text(l.get('accept_task'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
