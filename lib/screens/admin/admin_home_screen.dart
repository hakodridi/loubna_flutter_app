import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';
import '../auth/login_screen.dart';

// ── Colours ───────────────────────────────────────────────────────────────
const _kBg      = Color(0xFF07080F);
const _kCard    = Color(0xFF161B22);
const _kBorder  = Color(0xFF30363D);
const _kGold    = Color(0xFFF0A500);
const _kGreen   = Color(0xFF2D5F3F);
const _kGreenAccent = Color(0xFF3FB950);
const _kSage    = Color(0xFF9DBF8A);
const _kMuted   = Color(0xFF8B949E);
const _kRed     = Color(0xFFDA3633);
const _kOrange  = Color(0xFFE3A833);

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ApiService.post('/auth/logout', {});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(
              color: _kGold, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout_rounded, color: cs.onSurface.withValues(alpha: 0.54)),
            tooltip: 'Sign Out',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _kGold,
          labelColor: _kGold,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.54),
          labelStyle: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Products'),
            Tab(text: 'Pending Collections'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProductsTab(onLogout: _logout),
          const _PendingCollectionsTab(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TAB 1 — Products
// ══════════════════════════════════════════════════════════════════════════
class _ProductsTab extends StatefulWidget {
  final VoidCallback onLogout;
  const _ProductsTab({required this.onLogout});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.get('/products');
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'];
      setState(() {
        _products = List<Map<String, dynamic>>.from(
          data is List ? data : (data['data'] ?? []),
        );
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message'] ?? 'Failed to load products';
        _loading = false;
      });
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Delete Product',
              style: TextStyle(color: cs.onSurface, fontSize: 16)),
          content: Text(
            'Delete "${p['name']}"?',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: _kRed)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final res = await ApiService.delete('/products/${p['id']}');
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Product deleted'), backgroundColor: _kRed),
      );
      _fetch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Delete failed'),
            backgroundColor: _kRed),
      );
    }
  }

  void _openAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _ProductFormScreen()),
    ).then((_) => _fetch());
  }

  void _openEditProduct(Map<String, dynamic> p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _ProductFormScreen(product: p)),
    ).then((_) => _fetch());
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kGold,
        foregroundColor: Colors.black,
        onPressed: _openAddProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add Product',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kGold))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: _kMuted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _fetch,
                          child: const Text('Retry')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  color: _kGold,
                  onRefresh: _fetch,
                  child: _products.isEmpty
                      ? const Center(
                          child: Text(
                              'No products — tap + to add one',
                              style: TextStyle(color: _kMuted)),
                        )
                      : ListView.builder(
                          padding:
                              const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _products.length,
                          itemBuilder: (_, i) => _ProductTile(
                            product: _products[i],
                            onEdit: () => _openEditProduct(_products[i]),
                            onDelete: () => _deleteProduct(_products[i]),
                          ),
                        ),
                ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// TAB 2 — Pending Collection Orders
// ══════════════════════════════════════════════════════════════════════════
class _PendingCollectionsTab extends StatefulWidget {
  const _PendingCollectionsTab();

  @override
  State<_PendingCollectionsTab> createState() =>
      _PendingCollectionsTabState();
}

class _PendingCollectionsTabState extends State<_PendingCollectionsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final res = await ApiService.get('/collection-orders');
    if (!mounted) return;
    if (res['success'] == true) {
      final data = res['data'];
      setState(() {
        _orders = data is List ? data : (data['data'] ?? []);
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message'] ?? 'Failed to load orders';
        _loading = false;
      });
    }
  }

  Future<void> _approve(dynamic order) async {
    final res = await ApiService.patch(
        '/collection-orders/${order['id']}/admin-approve', {});
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Request approved and agent assigned'),
            backgroundColor: _kGreenAccent),
      );
      _fetch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Approval failed'),
            backgroundColor: _kRed),
      );
    }
  }

  Future<void> _reject(dynamic order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          backgroundColor: cs.surface,
          title: Text('Reject Request',
              style: TextStyle(color: cs.onSurface, fontSize: 16)),
          content: Text(
            'Reject collection request #${order['id']}?',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54))),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reject', style: TextStyle(color: _kRed)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final res = await ApiService.patch(
        '/collection-orders/${order['id']}/admin-reject', {});
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Request rejected'), backgroundColor: _kRed),
      );
      _fetch();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(res['message'] ?? 'Rejection failed'),
            backgroundColor: _kRed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kGold));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: _kMuted)),
            const SizedBox(height: 16),
            ElevatedButton(
                onPressed: _fetch, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, color: _kMuted, size: 48),
            SizedBox(height: 12),
            Text('No pending requests',
                style: TextStyle(color: _kMuted, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _kGold,
      onRefresh: _fetch,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        itemBuilder: (_, i) => _CollectionOrderTile(
          order: _orders[i],
          onApprove: () => _approve(_orders[i]),
          onReject: () => _reject(_orders[i]),
        ),
      ),
    );
  }
}

// ── Collection order tile ─────────────────────────────────────────────────
class _CollectionOrderTile extends StatelessWidget {
  final dynamic order;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _CollectionOrderTile({
    required this.order,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final o        = order as Map<String, dynamic>;
    final seller   = o['seller'] as Map<String, dynamic>?;
    final liters   = o['liters']?.toString() ?? '?';
    final address  = o['address'] ?? '';
    final date     = (o['pickup_date'] ?? '').toString().length >= 10
        ? (o['pickup_date'] as String).substring(0, 10)
        : (o['pickup_date'] ?? '').toString();
    final quality  = o['quality'] ?? '';
    final notes    = o['notes'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _kOrange.withValues(alpha: 0.4)),
                  ),
                  child: const Text('Pending',
                      style: TextStyle(
                          color: _kOrange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('Request #${o['id']}',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const Spacer(),
                if (seller != null)
                  Text(seller['name'] ?? '',
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Details
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _detail(context, Icons.water_drop_outlined, '$liters ${AppLocalizations.of(context).get('liter_unit')}'),
                if (date.isNotEmpty)
                  _detail(context, Icons.calendar_today_outlined, date),
                if (quality.isNotEmpty)
                  _detail(context, Icons.star_outline, quality),
                if (address.isNotEmpty)
                  _detail(context, Icons.location_on_outlined, address),
                if (notes.isNotEmpty)
                  _detail(context, Icons.notes, notes),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action buttons
          Divider(color: cs.outline, height: 1),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_rounded,
                      color: _kGreenAccent, size: 18),
                  label: const Text('Approve',
                      style: TextStyle(
                          color: _kGreenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
              Container(width: 1, height: 36, color: cs.outline),
              Expanded(
                child: TextButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.close_rounded,
                      color: _kRed, size: 18),
                  label: const Text('Reject',
                      style: TextStyle(
                          color: _kRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, IconData icon, String text) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: cs.onSurface.withValues(alpha: 0.54), size: 13),
        const SizedBox(width: 4),
        Text(text,
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
            overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Product tile
// ══════════════════════════════════════════════════════════════════════════
class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ProductTile(
      {required this.product, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final cs       = Theme.of(context).colorScheme;
    final p        = product;
    // Old: manual URL construction — broken on Laravel Cloud
    // final imageUrl = p['image'] != null
    //     ? '${ApiService.storageUrl}/${p['image']}'
    //     : null;
    // Now: API returns full URL via Storage::url() accessor
    final imageUrl = p['image'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.horizontal(left: Radius.circular(11)),
            child: SizedBox(
              width: 80,
              height: 80,
              child: imageUrl != null
                  ? Image.network(imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, e, st) => _thumb())
                  : _thumb(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p['name'] ?? '',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${p['price']} ${p['unit'] ?? ''}  •  ${p['region'] ?? ''}',
                    style: const TextStyle(color: _kSage, fontSize: 11),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p['badge'] ?? '',
                    style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.edit_outlined, color: _kGold, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: _kRed, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _thumb() {
    return Container(
      color: _kGreen.withValues(alpha: 0.2),
      child: const Center(
          child: Icon(Icons.eco_rounded, color: _kSage, size: 28)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Product form (add / edit)
// ══════════════════════════════════════════════════════════════════════════
class _ProductFormScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const _ProductFormScreen({this.product});

  @override
  State<_ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<_ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  XFile? _pickedImage;

  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _unit;
  late final TextEditingController _region;
  late final TextEditingController _badge;
  late final TextEditingController _description;
  late final TextEditingController _ownerName;
  late final TextEditingController _ownerLocation;
  late final TextEditingController _ownerPhone;
  late final TextEditingController _ownerEmail;

  final List<Map<String, TextEditingController>> _specs = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name          = TextEditingController(text: p?['name'] ?? '');
    _price         = TextEditingController(text: p?['price']?.toString() ?? '');
    _unit          = TextEditingController(text: p?['unit'] ?? '');
    _region        = TextEditingController(text: p?['region'] ?? '');
    _badge         = TextEditingController(text: p?['badge'] ?? 'New ✦');
    _description   = TextEditingController(text: p?['description'] ?? '');
    _ownerName     = TextEditingController(text: p?['owner_name'] ?? '');
    _ownerLocation = TextEditingController(text: p?['owner_location'] ?? '');
    _ownerPhone    = TextEditingController(text: p?['owner_phone'] ?? '');
    _ownerEmail    = TextEditingController(text: p?['owner_email'] ?? '');

    final existingSpecs = p?['specs'];
    if (existingSpecs is List) {
      for (final s in existingSpecs) {
        _specs.add({
          'label': TextEditingController(text: s['label'] ?? ''),
          'value': TextEditingController(text: s['value'] ?? ''),
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _price, _unit, _region, _badge, _description,
      _ownerName, _ownerLocation, _ownerPhone, _ownerEmail,
    ]) {
      c.dispose();
    }
    for (final s in _specs) {
      s['label']!.dispose();
      s['value']!.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (img != null) setState(() => _pickedImage = img);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final specsList = _specs
        .map((s) => {'label': s['label']!.text, 'value': s['value']!.text})
        .where((s) => s['label']!.isNotEmpty)
        .toList();
    final specsJson = jsonEncode(specsList);

    final fields = {
      'name':           _name.text,
      'price':          _price.text,
      'unit':           _unit.text,
      'region':         _region.text,
      'badge':          _badge.text,
      'description':    _description.text,
      'owner_name':     _ownerName.text,
      'owner_location': _ownerLocation.text,
      'owner_phone':    _ownerPhone.text,
      'owner_email':    _ownerEmail.text,
      'specs':          specsJson,
    };

    final endpoint = _isEdit
        ? '/products/${widget.product!['id']}'
        : '/products';

    final res = await ApiService.postMultipart(
      endpoint,
      fields,
      file: _pickedImage,
      fieldName: 'image',
    );

    setState(() => _saving = false);
    if (!mounted) return;

    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Product updated' : 'Product added'),
          backgroundColor: _kGreen,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'An error occurred'),
          backgroundColor: _kRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Old: manual URL construction — broken on Laravel Cloud
    // final existingImageUrl = widget.product?['image'] != null
    //     ? '${ApiService.storageUrl}/${widget.product!['image']}'
    //     : null;
    // Now: API returns full URL via Storage::url() accessor
    final existingImageUrl = widget.product?['image'] as String?;

    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: cs.onSurface.withValues(alpha: 0.54)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Edit Product' : 'New Product',
          style: const TextStyle(
              color: _kGold, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Image picker
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _pickedImage != null ? _kGold : cs.outline,
                    width: _pickedImage != null ? 2 : 1,
                  ),
                ),
                child: _pickedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          _pickedImage!.path,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => _imageFallback(),
                        ),
                      )
                    : existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(existingImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, e, st) =>
                                        _imageFallback()),
                                Container(
                                  color: Colors.black38,
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.camera_alt_outlined,
                                            color: Colors.white70,
                                            size: 32),
                                        SizedBox(height: 6),
                                        Text('Tap to change image',
                                            style: TextStyle(
                                                color: Colors.white70,
                                                fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _imageFallback(),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Product Info'),
            _field(_name, 'Product Name', required: true),
            Row(
              children: [
                Expanded(
                    child: _field(_price, 'Price',
                        keyboardType: TextInputType.number,
                        required: true)),
                const SizedBox(width: 10),
                Expanded(
                    child: _field(_unit, 'Unit (e.g. DZD/L)',
                        required: true)),
              ],
            ),
            Row(
              children: [
                Expanded(
                    child: _field(_region, 'Region', required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_badge, 'Badge')),
              ],
            ),
            _field(_description, 'Description', maxLines: 3, required: true),
            const SizedBox(height: 8),

            _sectionLabel('Owner Info'),
            _field(_ownerName, 'Name', required: true),
            _field(_ownerLocation, 'Location', required: true),
            _field(_ownerPhone, 'Phone',
                keyboardType: TextInputType.phone),
            _field(_ownerEmail, 'Email',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _sectionLabel('Specs', bottomPad: false),
                TextButton.icon(
                  onPressed: () => setState(() => _specs.add({
                        'label': TextEditingController(),
                        'value': TextEditingController(),
                      })),
                  icon: const Icon(Icons.add, size: 16),
                  label:
                      const Text('Add', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: _kGold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._specs.asMap().entries.map((e) {
              final i = e.key;
              final s = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                        child: _field(s['label']!, 'Label',
                            compact: true)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _field(s['value']!, 'Value',
                            compact: true)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline,
                          color: _kRed, size: 20),
                      onPressed: () =>
                          setState(() => _specs.removeAt(i)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2.5),
                      )
                    : Text(
                        _isEdit ? 'Save Changes' : 'Add Product',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _imageFallback() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate_outlined, color: cs.onSurface.withValues(alpha: 0.54), size: 40),
        const SizedBox(height: 8),
        Text('Tap to add product image',
            style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12)),
      ],
    );
  }

  Widget _sectionLabel(String text, {bool bottomPad = true}) {
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad ? 10 : 0),
      child: Text(
        text,
        style: const TextStyle(
            color: _kGold, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    bool required = false,
    bool compact = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 10),
      child: TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: cs.onSurface, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
          filled: true,
          fillColor: cs.surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: cs.outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kGold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _kRed, width: 1.5),
          ),
        ),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? 'This field is required' : null
            : null,
      ),
    );
  }
}
