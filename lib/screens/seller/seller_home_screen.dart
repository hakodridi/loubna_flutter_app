import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/app_localizations.dart';
import '../../widgets/oil_progress_widget.dart';
import '../auth/login_screen.dart';
import '../shared/organic_products_screen.dart';
import '../shared/faq_screen.dart';
import '../shared/profile_screen.dart';
import 'request_collection_screen.dart';
import 'collection_history_screen.dart';

class SellerHomeScreen extends StatefulWidget {
  const SellerHomeScreen({super.key});

  @override
  State<SellerHomeScreen> createState() => _SellerHomeScreenState();
}

class _SellerHomeScreenState extends State<SellerHomeScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  double _litersCollected = 0.0;
  double _cycleliters = 0.0;
  double _totalEarnings = 0.0;
  List<dynamic> _recentOrders = [];
  bool _loading = true;
  String _userName = '';
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    // Poll every 30 seconds while the screen is visible
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
    // Re-check orders when the user brings the app back to the foreground
    if (state == AppLifecycleState.resumed) _pollOrders();
  }

  /// Silent poll — only checks for new events, no loading spinner.
  Future<void> _pollOrders() async {
    if (!mounted) return;
    final res = await ApiService.get('/collection-orders?per_page=20');
    if (!mounted) return;
    if (res['success'] == true) {
      final orders = res['data']['data'] ?? [];
      setState(() => _recentOrders = (orders as List).take(5).toList());
      final events = await NotificationService.checkCollectionOrders(orders);
      if (mounted) _showEvents(events);
    }
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final info = await AuthService.getUserInfo();
    setState(() => _userName = info['name'] ?? '');

    final progressRes = await ApiService.get('/oil-progress');
    if (progressRes['success'] == true) {
      final data = progressRes['data'];
      setState(() {
        _litersCollected = double.tryParse(data['total_liters'].toString()) ?? 0.0;
        _cycleliters     = double.tryParse(data['liters_in_cycle'].toString()) ?? 0.0;
        _totalEarnings   = double.tryParse(data['estimated_value'].toString()) ?? 0.0;
      });
    }

    final ordersRes = await ApiService.get('/collection-orders?per_page=20');
    if (ordersRes['success'] == true) {
      final orders = ordersRes['data']['data'] ?? [];
      setState(() => _recentOrders = (orders as List).take(5).toList());
      final events = await NotificationService.checkCollectionOrders(orders);
      if (mounted) _showEvents(events);
    }

    setState(() => _loading = false);

    await _handlePendingReorder();
  }

  Future<void> _handlePendingReorder() async {
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final reorderType = prefs.getString(kPendingReorderKey);
    if (reorderType == 'collection') {
      await prefs.remove(kPendingReorderKey);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const RequestCollectionScreen()),
      );
    }
  }

  void _showEvents(List<OrderEvent> events) {
    if (!mounted || events.isEmpty) return;
    // Show one at a time — chain them sequentially
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
      _HomeTab(
        userName: _userName,
        litersCollected: _litersCollected,
        cycleliters: _cycleliters,
        totalEarnings: _totalEarnings,
        recentOrders: _recentOrders,
        loading: _loading,
        onRefresh: _loadData,
        onRequestCollection: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RequestCollectionScreen()),
        ).then((_) => _loadData()),
        onViewHistory: () {
          setState(() => _currentIndex = 1);
        },
      ),
      const CollectionHistoryScreen(),
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
        selectedItemColor: const Color(0xFFF0A500),
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
            icon: const Icon(Icons.history_outlined),
            activeIcon: const Icon(Icons.history),
            label: AppLocalizations.of(context).get('history'),
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

class _HomeTab extends StatelessWidget {
  final String userName;
  final double litersCollected;
  final double cycleliters;
  final double totalEarnings;
  final List<dynamic> recentOrders;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onRequestCollection;
  final VoidCallback onViewHistory;

  const _HomeTab({
    required this.userName,
    required this.litersCollected,
    required this.cycleliters,
    required this.totalEarnings,
    required this.recentOrders,
    required this.loading,
    required this.onRefresh,
    required this.onRequestCollection,
    required this.onViewHistory,
  });

  static String _fmtDZD(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M DZD';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k DZD';
    return '${v.toStringAsFixed(0)} DZD';
  }

  static String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return RefreshIndicator(
      color: const Color(0xFFF0A500),
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
                      color: Color(0xFFF0A500),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0A500).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFF0A500).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).get('seller'),
                    style: const TextStyle(
                      color: Color(0xFFF0A500),
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
                        color: Color(0xFFF0A500),
                      ),
                    ),
                  )
                else ...[
                  OilProgressWidget(litersCollected: cycleliters),
                  const SizedBox(height: 20),

                  // Request Collection CTA
                  GestureDetector(
                    onTap: onRequestCollection,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFB07D00), Color(0xFFF0A500)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF0A500).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline,
                            color: Colors.black,
                            size: 28,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).get('request_collection'),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppLocalizations.of(context).get('request_collection_subtitle'),
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.black54,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Lifetime stats row
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3FB950).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF3FB950).withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.account_balance_wallet_outlined, size: 12, color: Color(0xFF3FB950)),
                                const SizedBox(width: 4),
                                Text(AppLocalizations.of(context).get('total_earned'), style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
                              ]),
                              const SizedBox(height: 4),
                              Text(_fmtDZD(totalEarnings), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF3FB950))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF58A6FF).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.water_drop_outlined, size: 12, color: Color(0xFF58A6FF)),
                                const SizedBox(width: 4),
                                Text(AppLocalizations.of(context).get('total_sold'), style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.5))),
                              ]),
                              const SizedBox(height: 4),
                              Text('${litersCollected.toStringAsFixed(1)} L', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Recent orders
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context).get('recent_collections'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: onViewHistory,
                        child: Text(
                          AppLocalizations.of(context).get('view_all'),
                          style: const TextStyle(fontSize: 12),
                        ),
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
                            Icon(
                              Icons.inbox_outlined,
                              color: cs.onSurface.withValues(alpha: 0.24),
                              size: 40,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              AppLocalizations.of(context).get('no_collections_yet'),
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
                                Icons.local_shipping_outlined,
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
                                    '${order['liters'] ?? '?'} ${AppLocalizations.of(context).get('liters')}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    order['address'] ?? '',
                                    style: TextStyle(
                                      color: cs.onSurface.withValues(alpha: 0.54),
                                      fontSize: 12,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, size: 10, color: cs.onSurface.withValues(alpha: 0.38)),
                                      const SizedBox(width: 3),
                                      Text(
                                        _fmtDate(order['created_at']),
                                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.38)),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.attach_money, size: 10, color: Color(0xFF3FB950)),
                                      const SizedBox(width: 2),
                                      Text(
                                        _fmtDZD((double.tryParse(order['liters'].toString()) ?? 0) * 10000),
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF3FB950), fontWeight: FontWeight.w600),
                                      ),
                                    ],
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
