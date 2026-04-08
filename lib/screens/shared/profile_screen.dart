import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';
import 'complaint_screen.dart';
import '../../services/notification_service.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, String> _userInfo = {};
  Map<String, dynamic>? _stats;
  bool _loading = true;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _userInfo = await AuthService.getUserInfo();
    final res = await ApiService.get('/profile/stats');
    if (res['success'] == true) setState(() => _stats = res['data']);
    final notifEnabled = await NotificationService.isEnabled();
    setState(() {
      _loading = false;
      _notificationsEnabled = notifEnabled;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    await NotificationService.setEnabled(value);
    if (value) await NotificationService.init();
    setState(() => _notificationsEnabled = value);
  }

  Color get _roleColor {
    switch (_userInfo['role']) {
      case 'seller':   return const Color(0xFFF0A500);
      case 'buyer':    return const Color(0xFF3FB950);
      case 'delivery': return const Color(0xFF58A6FF);
      default:         return const Color(0xFF8B949E);
    }
  }

  IconData get _roleIcon {
    switch (_userInfo['role']) {
      case 'seller':   return Icons.store_outlined;
      case 'buyer':    return Icons.shopping_cart_outlined;
      case 'delivery': return Icons.local_shipping_outlined;
      default:         return Icons.person_outline;
    }
  }

  String _roleLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    switch (_userInfo['role']) {
      case 'seller':   return l.get('seller');
      case 'buyer':    return l.get('buyer');
      case 'delivery': return l.get('delivery');
      default:         return 'User';
    }
  }

  Future<void> _toggleAvailability(bool value) async {
    final res = await ApiService.patch(
        '/delivery/availability', {'is_available': value});
    if (res['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_available', value);
      setState(() => _userInfo['is_available'] = value.toString());
    } else {
      _showSnack(res['message'] ?? AppLocalizations.of(context).get('failed_to_update_availability'),
          isError: true);
    }
  }

  void _openEditSheet() {
    final nameCtrl     = TextEditingController(text: _userInfo['name']);
    final phoneCtrl    = TextEditingController(text: _userInfo['phone']);
    final wilayaCtrl   = TextEditingController(text: _userInfo['wilaya']);
    final capacityCtrl =
        TextEditingController(text: _userInfo['capacity_liters']);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_outlined, color: _roleColor, size: 20),
                      const SizedBox(width: 10),
                      Text(AppLocalizations.of(ctx).get('edit_profile'),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: _roleColor)),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.38)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EditField(
                    controller: nameCtrl,
                    label: AppLocalizations.of(ctx).get('name'),
                    icon: Icons.person_outline,
                    accentColor: _roleColor,
                    validator: (v) => (v == null || v.trim().length < 3)
                        ? AppLocalizations.of(ctx).get('min_3_chars')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    controller: phoneCtrl,
                    label: AppLocalizations.of(ctx).get('phone_number'),
                    icon: Icons.phone_outlined,
                    accentColor: _roleColor,
                    keyboardType: TextInputType.phone,
                    validator: (v) => (v == null || v.trim().length < 9)
                        ? AppLocalizations.of(ctx).get('valid_phone')
                        : null,
                  ),
                  const SizedBox(height: 14),
                  _EditField(
                    controller: wilayaCtrl,
                    label: AppLocalizations.of(ctx).get('wilaya'),
                    icon: Icons.location_on_outlined,
                    accentColor: _roleColor,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? AppLocalizations.of(ctx).get('required')
                        : null,
                  ),
                  if (_userInfo['role'] == 'delivery') ...[
                    const SizedBox(height: 14),
                    _EditField(
                      controller: capacityCtrl,
                      label: AppLocalizations.of(ctx).get('max_capacity'),
                      icon: Icons.local_shipping_outlined,
                      accentColor: _roleColor,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        final n = double.tryParse(v.trim());
                        if (n == null || n < 1) {
                          return AppLocalizations.of(ctx).get('valid_number');
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (!formKey.currentState!.validate()) return;
                            setModal(() => saving = true);
                            final body = <String, dynamic>{
                              'name':   nameCtrl.text.trim(),
                              'phone':  phoneCtrl.text.trim(),
                              'wilaya': wilayaCtrl.text.trim(),
                            };
                            if (_userInfo['role'] == 'delivery' &&
                                capacityCtrl.text.trim().isNotEmpty) {
                              body['capacity_liters'] =
                                  double.parse(capacityCtrl.text.trim());
                            }
                            final res = await ApiService.put('/profile', body);
                            setModal(() => saving = false);
                            if (!ctx.mounted) return;
                            if (res['success'] == true) {
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await AuthService.saveUserInfo(
                                  prefs, res['data']['user']);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                              _load();
                              _showSnack('Profile updated successfully!');
                            } else {
                              _showSnack(
                                  res['message'] ?? 'Update failed',
                                  isError: true);
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _roleColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : Text(AppLocalizations.of(ctx).get('save_changes'),
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = [
      _HelpItem(icon: Icons.swap_horiz_rounded,       q: l.get('help_q1'), a: l.get('help_a1')),
      _HelpItem(icon: Icons.water_drop_outlined,       q: l.get('help_q2'), a: l.get('help_a2')),
      _HelpItem(icon: Icons.shopping_cart_outlined,    q: l.get('help_q3'), a: l.get('help_a3')),
      _HelpItem(icon: Icons.star_outline,              q: l.get('help_q4'), a: l.get('help_a4')),
      _HelpItem(icon: Icons.payment_outlined,          q: l.get('help_q5'), a: l.get('help_a5')),
      _HelpItem(icon: Icons.report_problem_outlined,   q: l.get('help_q6'), a: l.get('help_a6')),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (ctx, scrollCtrl) => Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.help_outline,
                        color: Color(0xFFF0A500), size: 20),
                    const SizedBox(width: 10),
                    Text(
                      AppLocalizations.of(ctx).get('help_support'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  AppLocalizations.of(ctx).get('common_questions'),
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant, height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  itemCount: items.length,
                  separatorBuilder: (ctx, i) =>
                      Divider(color: cs.outlineVariant, height: 24),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(right: 12, top: 2),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0A500)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(item.icon,
                                color: const Color(0xFFF0A500), size: 18),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.q,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  item.a,
                                  style: TextStyle(
                                    color: cs.onSurface.withValues(alpha: 0.54),
                                    fontSize: 12,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/logo.jpg',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'OilTrade',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF0A500),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(ctx).get('version'),
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Text(
                      'OilTrade ',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(ctx).get('algeria'),
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppLocalizations.of(ctx).get('about_tagline'),
                style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.38),
                  fontSize: 12,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                AppLocalizations.of(ctx).get('copyright'),
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.24), fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppLocalizations.of(ctx).get('ok'),
                  style: const TextStyle(color: Color(0xFFF0A500))),
            ),
          ],
        );
      },
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDelivery  = _userInfo['role'] == 'delivery';
    final isAvailable = _userInfo['is_available'] == 'true';

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('profile')),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFF0A500)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header card ─────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: _roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _roleColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: _roleColor.withValues(alpha: 0.4),
                                width: 2),
                          ),
                          child: Center(
                            child: Text(
                              (_userInfo['name'] ?? 'U')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: _roleColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(_userInfo['name'] ?? '—',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _roleColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(_roleIcon, color: _roleColor, size: 14),
                              const SizedBox(width: 6),
                              Text(_roleLabel(context),
                                  style: TextStyle(
                                      color: _roleColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          onPressed: _openEditSheet,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _roleColor,
                            side: BorderSide(
                                color: _roleColor.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 8),
                          ),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(AppLocalizations.of(context).get('edit_profile'),
                              style: const TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Delivery: availability toggle ─────────────────────
                  if (isDelivery) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: isAvailable
                                ? const Color(0xFF3FB950)
                                    .withValues(alpha: 0.4)
                                : cs.outlineVariant),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAvailable
                                ? Icons.check_circle_outline
                                : Icons.pause_circle_outline,
                            color: isAvailable
                                ? const Color(0xFF3FB950)
                                : cs.onSurface.withValues(alpha: 0.38),
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppLocalizations.of(context).get('availability'),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: isAvailable
                                            ? const Color(0xFF3FB950)
                                            : cs.onSurface.withValues(alpha: 0.54))),
                                Text(
                                    isAvailable
                                        ? AppLocalizations.of(context).get('accepting_orders')
                                        : AppLocalizations.of(context).get('not_accepting_orders'),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurface.withValues(alpha: 0.38))),
                              ],
                            ),
                          ),
                          Switch(
                            value: isAvailable,
                            onChanged: _toggleAvailability,
                            activeThumbColor: const Color(0xFF3FB950),
                            activeTrackColor:
                                const Color(0xFF3FB950).withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Contact info ──────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppLocalizations.of(context).get('contact_info'),
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: cs.onSurface.withValues(alpha: 0.7))),
                        const SizedBox(height: 14),
                        _InfoRow(
                            icon: Icons.email_outlined,
                            label: AppLocalizations.of(context).get('email'),
                            value: _userInfo['email'] ?? '—'),
                        _InfoRow(
                            icon: Icons.phone_outlined,
                            label: AppLocalizations.of(context).get('phone'),
                            value: _userInfo['phone'] ?? '—'),
                        _InfoRow(
                            icon: Icons.location_on_outlined,
                            label: AppLocalizations.of(context).get('wilaya'),
                            value: _userInfo['wilaya'] ?? '—',
                            isLast: _userInfo['role'] == 'buyer'),
                        if (isDelivery)
                          _InfoRow(
                            icon: Icons.local_shipping_outlined,
                            label: AppLocalizations.of(context).get('capacity'),
                            value: (_userInfo['capacity_liters']?.isNotEmpty == true)
                                ? '${_userInfo['capacity_liters']} ${AppLocalizations.of(context).get('l_per_trip')}'
                                : AppLocalizations.of(context).get('not_set'),
                          ),
                        if (_userInfo['role'] == 'seller' || isDelivery)
                          _InfoRow(
                            icon: Icons.account_balance_outlined,
                            label: AppLocalizations.of(context).get('ccp'),
                            value: (_userInfo['ccp']?.isNotEmpty == true)
                                ? _userInfo['ccp']!
                                : AppLocalizations.of(context).get('not_set'),
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Stats ─────────────────────────────────────────────
                  if (_stats != null) ...[
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppLocalizations.of(context).get('activity_stats'),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: cs.onSurface.withValues(alpha: 0.7))),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              if (_stats!['total_collections'] != null)
                                _StatCard(
                                    label: AppLocalizations.of(context).get('collections'),
                                    value: '${_stats!['total_collections']}',
                                    icon: Icons.water_drop_outlined,
                                    color: const Color(0xFFF0A500)),
                              if (_stats!['total_orders'] != null)
                                _StatCard(
                                    label: AppLocalizations.of(context).get('orders'),
                                    value: '${_stats!['total_orders']}',
                                    icon: Icons.receipt_long_outlined,
                                    color: const Color(0xFF3FB950)),
                              if (_stats!['avg_rating'] != null)
                                _StatCard(
                                    label: AppLocalizations.of(context).get('rating'),
                                    value: '${_stats!['avg_rating']}',
                                    icon: Icons.star_outline,
                                    color: const Color(0xFFF0A500)),
                              if (_stats!['completed_count'] != null)
                                _StatCard(
                                    label: AppLocalizations.of(context).get('completed'),
                                    value: '${_stats!['completed_count']}',
                                    icon: Icons.check_circle_outline,
                                    color: const Color(0xFF3FB950)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Settings menu ─────────────────────────────────────
                  Container(
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                _notificationsEnabled
                                    ? Icons.notifications_active_outlined
                                    : Icons.notifications_off_outlined,
                                color: _notificationsEnabled
                                    ? _roleColor
                                    : cs.onSurface.withValues(alpha: 0.38),
                                size: 22,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(AppLocalizations.of(context).get('notifications'),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                    Text(
                                      _notificationsEnabled
                                          ? AppLocalizations.of(context).get('order_updates_enabled')
                                          : AppLocalizations.of(context).get('notifications_off'),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: cs.onSurface.withValues(alpha: 0.38)),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _notificationsEnabled,
                                onChanged: _toggleNotifications,
                                activeThumbColor: _roleColor,
                                activeTrackColor: _roleColor.withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                        ),
                        Divider(color: cs.outlineVariant, height: 1),
                        _DarkModeTile(),
                        Divider(color: cs.outlineVariant, height: 1),
                        _LanguageTile(),
                        Divider(color: cs.outlineVariant, height: 1),
                        _MenuTile(
                            icon: Icons.security_outlined,
                            label: AppLocalizations.of(context).get('privacy_security'),
                            onTap: () {}),
                        Divider(color: cs.outlineVariant, height: 1),
                        _MenuTile(
                          icon: Icons.help_outline,
                          label: AppLocalizations.of(context).get('help_support'),
                          onTap: () => _showHelpSheet(context),
                        ),
                        Divider(color: cs.outlineVariant, height: 1),
                        _MenuTile(
                          icon: Icons.share_outlined,
                          label: AppLocalizations.of(context).get('share_app'),
                          onTap: () => SharePlus.instance.share(
                            ShareParams(
                              text:
                                  '🫙 Discover OilTrade — Algeria\'s first platform for used cooking oil!\n'
                                  'Sell your used oil, earn money, and help protect the environment.\n'
                                  'Download the app now and join the green community.',
                            ),
                          ),
                        ),
                        Divider(color: cs.outlineVariant, height: 1),
                        _MenuTile(
                          icon: Icons.info_outline,
                          label: AppLocalizations.of(context).get('about'),
                          onTap: () => _showAboutDialog(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Report a Problem ──────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComplaintScreen()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFA85050).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFA85050).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.report_problem_outlined,
                                color: Color(0xFFA85050), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context).get('report_problem'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Color(0xFFA85050),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppLocalizations.of(context).get('report_subtitle'),
                                  style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 14,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Logout ────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: widget.onLogout,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        padding:
                            const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.logout, size: 18),
                      label: Text(AppLocalizations.of(context).get('sign_out'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final Color accentColor;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _EditField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.accentColor,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: cs.onSurface),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: accentColor.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon,
            color: accentColor.withValues(alpha: 0.7), size: 18),
        filled: true,
        fillColor: cs.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: accentColor.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: accentColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accentColor),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: cs.onSurface.withValues(alpha: 0.38)),
            const SizedBox(width: 10),
            SizedBox(
              width: 65,
              child: Text(label,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.38), fontSize: 13)),
            ),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontSize: 13))),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: cs.outlineVariant, height: 1),
          )
        else
          const SizedBox(height: 2),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38))),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuTile(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: cs.onSurface.withValues(alpha: 0.54), size: 20),
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Icon(Icons.arrow_forward_ios,
          size: 14, color: cs.onSurface.withValues(alpha: 0.24)),
    );
  }
}

class _DarkModeTile extends StatelessWidget {
  const _DarkModeTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        final cs = Theme.of(context).colorScheme;
        return ListTile(
          leading: Icon(
            isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            color: cs.onSurface.withValues(alpha: 0.54),
            size: 20,
          ),
          title: Text(AppLocalizations.of(context).get('dark_mode'), style: const TextStyle(fontSize: 14)),
          trailing: Switch(
            value: isDark,
            activeThumbColor: const Color(0xFFF0A500),
            activeTrackColor:
                const Color(0xFFF0A500).withValues(alpha: 0.4),
            onChanged: (value) async {
              themeNotifier.value =
                  value ? ThemeMode.dark : ThemeMode.light;
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('dark_mode', value);
            },
          ),
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        final isArabic = locale.languageCode == 'ar';
        final cs = Theme.of(context).colorScheme;
        return ListTile(
          leading: Icon(Icons.language_outlined,
              color: cs.onSurface.withValues(alpha: 0.54), size: 20),
          title: Text(isArabic ? 'اللغة' : 'Language',
              style: const TextStyle(fontSize: 14)),
          trailing: Container(
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LangOption(
                  label: 'EN',
                  selected: !isArabic,
                  onTap: () => AppLocalizations.setLocale('en'),
                ),
                _LangOption(
                  label: 'عربي',
                  selected: isArabic,
                  onTap: () => AppLocalizations.setLocale('ar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0A500) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.black : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54),
          ),
        ),
      ),
    );
  }
}

class _HelpItem {
  final IconData icon;
  final String q;
  final String a;
  const _HelpItem({required this.icon, required this.q, required this.a});
}
