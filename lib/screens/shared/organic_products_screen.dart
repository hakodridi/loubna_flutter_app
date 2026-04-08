import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

// ── Colours ───────────────────────────────────────────────────────────────
const _kGreen      = Color(0xFF2D5F3F);
const _kGreenLight = Color(0xFF4E9669);
const _kSage       = Color(0xFF9DBF8A);
const _kGold       = Color(0xFFF0A500);
const _kCardBg     = Color(0xFF1C261C);
const _kBorder     = Color(0xFF2E3D2E);
const _kMuted      = Color(0xFF607060);

// ── Main screen ───────────────────────────────────────────────────────────
class OrganicProductsScreen extends StatefulWidget {
  const OrganicProductsScreen({super.key});

  @override
  State<OrganicProductsScreen> createState() => _OrganicProductsScreenState();
}

class _OrganicProductsScreenState extends State<OrganicProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
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
        _error = res['message'] ?? AppLocalizations.of(context).get('failed_to_load_products');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: _kGreen,
          automaticallyImplyLeading: false,
          title: Text(
            AppLocalizations.of(context).get('organic_products'),
            style: const TextStyle(
              color: _kSage,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          centerTitle: true,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _kGreenLight))
            : _error != null
                ? _ErrorView(message: _error!, onRetry: _fetch)
                : RefreshIndicator(
                    color: _kGreenLight,
                    onRefresh: _fetch,
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        // ── Info banner ───────────────────────────────────
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _kGreen.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _kGreen.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).get('certified_products'),
                                style: const TextStyle(
                                  color: _kGreenLight,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context).get('products_tap_hint'),
                                style: TextStyle(
                                    color: _kMuted, fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),

                        if (_products.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Center(
                              child: Text(
                                AppLocalizations.of(context).get('no_products'),
                                style: const TextStyle(color: _kMuted, fontSize: 15),
                              ),
                            ),
                          )
                        else
                          ..._products.map((p) => _ProductCard(
                                product: p,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        _ProductDetailPage(product: p),
                                  ),
                                ),
                              )),

                        // ── Footer CTA ────────────────────────────────────
                        Container(
                          margin: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A3A2A), Color(0xFF0D1F15)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: _kGreen.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context).get('list_product_cta'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                AppLocalizations.of(context).get('list_product_body'),
                                style: const TextStyle(
                                    color: _kMuted, fontSize: 12, height: 1.5),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: _kGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _kGreen.withValues(alpha: 0.4)),
                                ),
                                child: const Text(
                                  'startuup634@gmail.com',
                                  style: TextStyle(
                                    color: _kSage,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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

// ── Error view ────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, color: _kMuted, size: 48),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kMuted, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: _kSage,
              ),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context).get('retry')),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final badge = (p['badge'] as String?) ?? 'جديد ✦';
    final badgeGreen = badge.contains('✓');
    final badgeColor = badgeGreen ? _kGreenLight : _kGold;
    final badgeBg = badgeGreen
        ? _kGreen.withValues(alpha: 0.15)
        : _kGold.withValues(alpha: 0.15);
    // Old: manual URL construction — broken on Laravel Cloud
    // final imageUrl =
    //     p['image'] != null ? '${ApiService.storageUrl}/${p['image']}' : null;
    // Now: API returns full URL via Storage::url() accessor
    final imageUrl = p['image'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Image area ───────────────────────────────────────────────
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: SizedBox(
                height: 140,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, e, st) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    // Badge overlay
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.6)),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Info area ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p['name'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${p['price']} ${p['unit'] ?? ''}',
                        style: const TextStyle(
                          color: _kSage,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    p['description'] ?? '',
                    style: const TextStyle(
                        color: _kMuted, fontSize: 11, height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 13, color: _kMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${p['owner_name'] ?? ''} • ${p['region'] ?? ''}',
                          style: const TextStyle(color: _kMuted, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Icon(Icons.chevron_left_rounded,
                          size: 16, color: _kMuted),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kGreen.withValues(alpha: 0.4), _kCardBg],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: const Center(
        child: Icon(Icons.eco_rounded, size: 48, color: _kGreenLight),
      ),
    );
  }
}

// ── Product detail page ───────────────────────────────────────────────────
class _ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductDetailPage({required this.product});

  @override
  Widget build(BuildContext context) {
    final p = product;
    final badge = (p['badge'] as String?) ?? 'جديد ✦';
    final badgeGreen = badge.contains('✓');
    final badgeColor = badgeGreen ? _kGreenLight : _kGold;
    final badgeBg = badgeGreen
        ? _kGreen.withValues(alpha: 0.15)
        : _kGold.withValues(alpha: 0.15);
    // Old: manual URL construction — broken on Laravel Cloud
    // final imageUrl =
    //     p['image'] != null ? '${ApiService.storageUrl}/${p['image']}' : null;
    // Now: API returns full URL via Storage::url() accessor
    final imageUrl = p['image'] as String?;

    final specs = p['specs'];
    final specsList = specs is List ? specs : [];

    return Scaffold(
        appBar: AppBar(
          backgroundColor: _kGreen,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _kSage),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            p['name'] ?? '',
            style: const TextStyle(
              color: _kSage,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Main image ──────────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 220,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, st) => _imgPlaceholder(),
                        )
                      : _imgPlaceholder(),
                ),
              ),
              const SizedBox(height: 16),

              // ── Name + badge + price ──────────────────────────────────
              Builder(builder: (context) {
              final cs = Theme.of(context).colorScheme;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p['name'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: badgeColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                                color: badgeColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${p['price']}',
                        style: const TextStyle(
                          color: _kSage,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        p['unit'] ?? '',
                        style: const TextStyle(color: _kMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              );
              }),
              const SizedBox(height: 16),

              // ── Specs chips ────────────────────────────────────────────
              if (specsList.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: specsList.map<Widget>((s) {
                    final label = s is Map ? (s['label'] ?? '') : '';
                    final value = s is Map ? (s['value'] ?? '') : '';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: _kGreen.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '$label: $value',
                        style: const TextStyle(
                          color: _kSage,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],

              // ── Description card ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).get('product_description'),
                      style: const TextStyle(
                          color: _kMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      p['description'] ?? '',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Owner info card ────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).get('owner_info'),
                      style: const TextStyle(
                        color: _kGreenLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Builder(builder: (ctx) => Text(
                      p['owner_name'] ?? '',
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.onSurface,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text('📍', style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 4),
                        Text(
                          p['owner_location'] ?? '',
                          style:
                              const TextStyle(color: _kMuted, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if ((p['owner_phone'] as String?)?.isNotEmpty == true)
                      _contactRow(
                        Icons.phone_outlined,
                        _kGreenLight,
                        p['owner_phone'],
                        const Color(0xFF0E1A0E),
                      ),
                    if ((p['owner_email'] as String?)?.isNotEmpty == true)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _contactRow(
                          Icons.email_outlined,
                          const Color(0xFF4A7FA5),
                          p['owner_email'],
                          const Color(0xFF0E1A24),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      AppLocalizations.of(context).get('contact_owner_hint'),
                      style: const TextStyle(
                          color: _kMuted, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: _kCardBg,
      child: const Center(
        child: Icon(Icons.eco_rounded, size: 72, color: _kGreenLight),
      ),
    );
  }

  Widget _contactRow(
      IconData icon, Color color, String? text, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(
            text ?? '',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
