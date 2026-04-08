import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../services/app_localizations.dart';
import '../auth/login_screen.dart';
import '../shared/organic_products_screen.dart';
import '../shared/faq_screen.dart';
import '../shared/profile_screen.dart';
import 'subscription_screen.dart';
import 'purchase_orders_screen.dart';
import 'place_order_screen.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  String _userName = '';
  Map<String, dynamic>? _subscription;
  List<dynamic> _recentOrders = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pollOrders());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _pollOrders();
  }

  Future<void> _pollOrders() async {
    if (!mounted) return;
    final res = await ApiService.get('/purchase-orders?per_page=20');
    if (!mounted) return;
    if (res['success'] == true) {
      final orders = res['data']['data'] ?? [];
      setState(() => _recentOrders = (orders as List).take(5).toList());
      final events = await NotificationService.checkPurchaseOrders(orders);
      if (mounted) _showEvents(events);
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final info = await AuthService.getUserInfo();
    setState(() => _userName = info['name'] ?? '');

    // Get all subscriptions (backend returns a plain list, sorted latest first)
    final allSubsRes = await ApiService.get('/subscriptions');
    if (allSubsRes['success'] == true) {
      final items = allSubsRes['data'];
      if (items is List && items.isNotEmpty) {
        final latest = Map<String, dynamic>.from(items[0] as Map);
        final status = latest['status'] as String? ?? '';
        if (status == 'active' || status == 'pending') {
          setState(() => _subscription = latest);
        }
      }
    }

    final ordersRes = await ApiService.get('/purchase-orders?per_page=20');
    if (ordersRes['success'] == true) {
      final orders = ordersRes['data']['data'] ?? [];
      setState(() => _recentOrders = (orders as List).take(5).toList());
      final events = await NotificationService.checkPurchaseOrders(orders);
      if (mounted) _showEvents(events);
    }

    setState(() => _loading = false);

    await _handlePendingReorder();
  }

  Future<void> _handlePendingReorder() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final reorderType = prefs.getString(kPendingReorderKey);
    if (reorderType == 'purchase') {
      await prefs.remove(kPendingReorderKey);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PlaceOrderScreen()),
      );
    }
  }

  void _showEvents(List<OrderEvent> events) {
    if (!mounted || events.isEmpty) return;
    _showNextEvent(events, 0);
  }

  void _showNextEvent(List<OrderEvent> events, int index) {
    if (!mounted || index >= events.length) return;
    final e = events[index];
    final color = e.isSuccess ? const Color(0xFF3FB950) : Colors.redAccent;
    final icon  = e.isSuccess ? Icons.check_circle_outline : Icons.cancel_outlined;

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 3000), () {
          if (ctx.mounted) Navigator.of(ctx).pop();
        });
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 24, offset: Offset(0, 8))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: Colors.white, size: 36),
                  const SizedBox(height: 10),
                  Text(e.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(e.body,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) => Future.delayed(
          const Duration(milliseconds: 400),
          () => _showNextEvent(events, index + 1),
        ));
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(AppLocalizations.of(ctx).get('sign_out_confirm')),
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
              child: Text(AppLocalizations.of(ctx).get('sign_out'), style: const TextStyle(color: Colors.white)),
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
    final pages = [
      _BuyerHomeTab(
        userName: _userName,
        subscription: _subscription,
        recentOrders: _recentOrders,
        loading: _loading,
        onRefresh: _loadData,
        onSubscribe: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
        ).then((_) => _loadData()),
        onViewOrders: () => setState(() => _currentIndex = 1),
        onPlaceOrder: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlaceOrderScreen()),
        ).then((_) => _loadData()),
      ),
      const PurchaseOrdersScreen(),
      const OrganicProductsScreen(),
      const FaqScreen(),
      ProfileScreen(onLogout: _logout),
    ];

    return Scaffold(
      body: pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: const Color(0xFF3FB950),
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
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long),
            label: AppLocalizations.of(context).get('orders'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.eco_outlined),
            activeIcon: const Icon(Icons.eco),
            label: AppLocalizations.of(context).get('products'),
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

class _BuyerHomeTab extends StatelessWidget {
  final String userName;
  final Map<String, dynamic>? subscription;
  final List<dynamic> recentOrders;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onSubscribe;
  final VoidCallback onViewOrders;
  final VoidCallback onPlaceOrder;

  const _BuyerHomeTab({
    required this.userName,
    required this.subscription,
    required this.recentOrders,
    required this.loading,
    required this.onRefresh,
    required this.onSubscribe,
    required this.onViewOrders,
    required this.onPlaceOrder,
  });

  static const Map<String, Map<String, dynamic>> _planMeta = {
    'basic': {
      'color': Color(0xFF58A6FF),
      'icon': Icons.water_drop_outlined,
      'label': 'Basic',
    },
    'premium': {
      'color': Color(0xFF3FB950),
      'icon': Icons.verified_outlined,
      'label': 'Premium',
    },
    'vip': {
      'color': Color(0xFFF0A500),
      'icon': Icons.workspace_premium_outlined,
      'label': 'VIP',
    },
  };

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
        return const Color(0xFF3FB950);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs   = Theme.of(context).colorScheme;
    final plan = subscription?['plan'] as String?;
    final planMeta = plan != null ? _planMeta[plan] : null;

    return RefreshIndicator(
      color: const Color(0xFF3FB950),
      onRefresh: () async => onRefresh(),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 80,
            pinned: true,
            backgroundColor: cs.surface,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'OilTrade',
                    style: TextStyle(
                      color: Color(0xFF3FB950),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    '${AppLocalizations.of(context).get('hello')}, ${userName.split(' ').first}',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF3FB950).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).get('buyer'),
                    style: const TextStyle(
                      color: Color(0xFF3FB950),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(
                        color: Color(0xFF3FB950),
                      ),
                    ),
                  )
                else ...[
                  // Subscription card
                  if (subscription != null && subscription!['status'] == 'pending')
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2A2A1A), Color(0xFF3A3A1E)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFF0A500).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.hourglass_top_outlined,
                            color: Color(0xFFF0A500),
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).get('subscription_pending'),
                                  style: const TextStyle(
                                    color: Color(0xFFF0A500),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${subscription!['plan']?.toString().toUpperCase() ?? ''} ${AppLocalizations.of(context).get('subscription_pending_subtitle')}',
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.54),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (subscription == null)
                    GestureDetector(
                      onTap: onSubscribe,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A3A2A), Color(0xFF1E4D33)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF3FB950).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: Color(0xFF3FB950),
                              size: 28,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context).get('subscribe_to_plan'),
                                    style: const TextStyle(
                                      color: Color(0xFF3FB950),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    AppLocalizations.of(context).get('subscribe_to_plan_subtitle'),
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.54),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: cs.onSurface.withValues(alpha: 0.38),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            (planMeta?['color'] as Color? ?? const Color(0xFF3FB950))
                                .withValues(alpha: 0.2),
                            (planMeta?['color'] as Color? ?? const Color(0xFF3FB950))
                                .withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (planMeta?['color'] as Color? ??
                                  const Color(0xFF3FB950))
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                planMeta?['icon'] as IconData? ??
                                    Icons.verified_outlined,
                                color: planMeta?['color'] as Color? ??
                                    const Color(0xFF3FB950),
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${planMeta?['label'] ?? plan} Plan',
                                style: TextStyle(
                                  color: planMeta?['color'] as Color? ??
                                      const Color(0xFF3FB950),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: Color(0xFF3FB950),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _InfoTile(
                                label: AppLocalizations.of(context).get('quota'),
                                value: '${subscription!['liters_limit']}${AppLocalizations.of(context).get('l_per_month')}',
                              ),
                              const SizedBox(width: 8),
                              _InfoTile(
                                label: 'Price',
                                value: '${subscription!['price']} DZD',
                              ),
                              const SizedBox(width: 8),
                              _InfoTile(
                                label: 'Priority',
                                value: '#${subscription!['priority_score'] ?? '?'}',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: onSubscribe,
                            child: Text(
                              AppLocalizations.of(context).get('upgrade_plan'),
                              style: const TextStyle(
                                color: Color(0xFF3FB950),
                                fontSize: 12,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Place Order button
                  GestureDetector(
                    onTap: onPlaceOrder,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A3A2A), Color(0xFF1E4D33)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFF3FB950).withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.shopping_cart_outlined,
                            color: Color(0xFF3FB950),
                            size: 26,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).get('place_an_order'),
                                  style: const TextStyle(
                                    color: Color(0xFF3FB950),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppLocalizations.of(context).get('place_order_subtitle'),
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white.withValues(alpha: 0.5),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Recent orders
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).get('recent_orders'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: onViewOrders,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF3FB950),
                        ),
                        child: Text(AppLocalizations.of(context).get('view_all'), style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (recentOrders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined, color: cs.onSurface.withValues(alpha: 0.24), size: 40),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).get('no_orders_yet'),
                              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...recentOrders.map((order) {
                      final status = order['status'] ?? 'pending';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.shopping_bag_outlined,
                                color: _statusColor(status),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${AppLocalizations.of(context).get('order_hash')}${order['id']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${order['liters'] ?? '?'}${AppLocalizations.of(context).get('liter_unit')}',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.54),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(status).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
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
                      );
                    }),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.38)),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
