import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

// ── Colours ───────────────────────────────────────────────────────────────
const _kBg     = Color(0xFF07080F);
const _kCard   = Color(0xFF161B22);
const _kBorder = Color(0xFF30363D);
const _kGreen  = Color(0xFF3FB950);
const _kMuted  = Color(0xFF8B949E);
const _kRed    = Color(0xFFDA3633);
const _kAmber  = Color(0xFFF0A500);

// OilTrade's CCP account number shown to buyers for payment
const _kZitappCcp = '0012345678 / 12';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _litersCtrl  = TextEditingController();
  final _addressCtrl = TextEditingController();

  DateTime? _deliveryDate;
  double?   _lat;
  double?   _lng;

  String _selectedQuality = 'Good Quality'; // 'Good Quality' | 'Medium'

  bool _locating    = false;
  bool _checking    = false;   // stock check in progress
  bool _submitting  = false;

  // Step: 'form' → 'payment' → 'done'
  String _step = 'form';
  bool   _waitlisted = false;

  // Payment step
  XFile?  _receiptPhoto;
  String? _submitError;

  @override
  void dispose() {
    _litersCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ───────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deliveryDate ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kGreen,
            surface: _kCard,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deliveryDate = picked);
  }

  // ── Geolocator ───────────────────────────────────────────────────────
  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      final svcEnabled = await Geolocator.isLocationServiceEnabled();
      if (!svcEnabled) {
        _showSnack(AppLocalizations.of(context).get('location_disabled'), error: true);
        setState(() => _locating = false);
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showSnack(AppLocalizations.of(context).get('location_permission_denied'), error: true);
        setState(() => _locating = false);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      String address =
          '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      try {
        final marks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          final parts = [
            m.street,
            m.subLocality,
            m.locality,
            m.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).toList();
          if (parts.isNotEmpty) address = parts.join(', ');
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _addressCtrl.text = address;
        _locating = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('${AppLocalizations.of(context).get('location_error_prefix')}$e', error: true);
      setState(() => _locating = false);
    }
  }

  // ── Receipt photo picker ──────────────────────────────────────────────
  Future<void> _pickReceiptPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (picked != null) setState(() => _receiptPhoto = picked);
  }

  void _showReceiptSourceSheet() {
    final surfaceColor = Theme.of(context).colorScheme.surface;
    showModalBottomSheet(
      context: context,
      backgroundColor: surfaceColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _kAmber),
              title: Text(AppLocalizations.of(context).get('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickReceiptPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: _kAmber),
              title: Text(AppLocalizations.of(context).get('choose_from_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickReceiptPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── "Place Order" pressed: check stock ───────────────────────────────
  Future<void> _checkStock() async {
    if (!_formKey.currentState!.validate()) return;
    if (_deliveryDate == null) {
      _showSnack(AppLocalizations.of(context).get('val_select_delivery_date'), error: true);
      return;
    }

    setState(() {
      _checking    = true;
      _submitError = null;
    });

    final liters = _litersCtrl.text.trim();
    final res = await ApiService.get('/purchase-orders/check?liters=$liters');

    if (!mounted) return;
    setState(() => _checking = false);

    if (res['success'] == true) {
      final data      = res['data'] ?? {};
      final sufficient = data['sufficient'] == true;

      if (!sufficient) {
        // Insufficient stock → submit directly as waitlist
        await _submitOrder(withReceipt: false);
      } else {
        // Sufficient → show payment screen
        setState(() => _step = 'payment');
      }
    } else {
      setState(() => _submitError = res['message'] ?? 'Stock check failed');
    }
  }

  // ── Submit order (with or without receipt) ────────────────────────────
  Future<void> _submitOrder({required bool withReceipt}) async {
    setState(() {
      _submitting  = true;
      _submitError = null;
    });

    final dateStr = '${_deliveryDate!.year}-'
        '${_deliveryDate!.month.toString().padLeft(2, '0')}-'
        '${_deliveryDate!.day.toString().padLeft(2, '0')}';

    Map<String, dynamic> res;

    if (withReceipt && _receiptPhoto != null) {
      // multipart POST with receipt image
      final fields = <String, String>{
        'liters':        _litersCtrl.text.trim(),
        'quality':       _selectedQuality,
        'delivery_date': dateStr,
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_lat != null) 'latitude':  _lat.toString(),
        if (_lng != null) 'longitude': _lng.toString(),
      };
      res = await ApiService.postMultipart(
        '/purchase-orders',
        fields,
        file: _receiptPhoto,
        fieldName: 'receipt_photo',
      );
    } else {
      // JSON POST without receipt (waitlist path)
      final body = <String, dynamic>{
        'liters':        _litersCtrl.text.trim(),
        'quality':       _selectedQuality,
        'delivery_date': dateStr,
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_lat != null) 'latitude':  _lat.toString(),
        if (_lng != null) 'longitude': _lng.toString(),
      };
      res = await ApiService.post('/purchase-orders', body);
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res['success'] == true) {
      final data   = res['data'] ?? {};
      final isWait = data['waitlist'] == true ||
          (data['order'] as Map<String, dynamic>?)?['status'] == 'waitlist';
      setState(() {
        _waitlisted = isWait;
        _step       = 'done';
      });
    } else {
      setState(() => _submitError = res['message'] ?? 'An error occurred');
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? _kRed : _kGreen,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: cs.onSurface.withValues(alpha: 0.54)),
          onPressed: () {
            if (_step == 'payment') {
              setState(() { _step = 'form'; _submitError = null; });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _step == 'payment' ? AppLocalizations.of(context).get('payment') : AppLocalizations.of(context).get('place_oil_order'),
          style: const TextStyle(
              color: _kGreen, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        centerTitle: true,
      ),
      body: switch (_step) {
        'done'    => _buildDone(),
        'payment' => _buildPayment(),
        _         => _buildForm(),
      },
    );
  }

  // ── Done state ────────────────────────────────────────────────────────
  Widget _buildDone() {
    final color  = _waitlisted ? const Color(0xFF58A6FF) : _kGreen;
    final icon   = _waitlisted
        ? Icons.access_time_rounded
        : Icons.check_circle_outline_rounded;
    final title  = _waitlisted ? AppLocalizations.of(context).get('added_to_waitlist') : AppLocalizations.of(context).get('order_submitted');
    final body   = _waitlisted
        ? AppLocalizations.of(context).get('waitlist_body')
        : AppLocalizations.of(context).get('order_submitted_body');
    final chip   = _waitlisted ? AppLocalizations.of(context).get('status_waitlisted') : AppLocalizations.of(context).get('status_pending_verification');

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.12),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Icon(icon, color: color, size: 44),
            ),
            const SizedBox(height: 24),
            Text(title,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(body,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 14, height: 1.6),
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(chip,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(AppLocalizations.of(context).get('ok'),
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Payment step ──────────────────────────────────────────────────────
  Widget _buildPayment() {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _kAmber.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kAmber.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.payment_outlined, color: _kAmber, size: 20),
                  const SizedBox(width: 10),
                  Text(AppLocalizations.of(context).get('pay_via_baridi'),
                      style: const TextStyle(
                          color: _kAmber,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context).get('pay_transfer_instruction'),
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // CCP account
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cs.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).get('oiltrade_ccp_account'),
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.54),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.account_balance_outlined,
                      color: _kAmber, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    _kZitappCcp,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.of(context).get('amount_to_pay')}: ${((double.tryParse(_litersCtrl.text) ?? 0) * (_selectedQuality == 'Good Quality' ? 110 : 100)).toStringAsFixed(0)} DZD',
                style: const TextStyle(color: _kGreen, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Receipt upload
        Text(AppLocalizations.of(context).get('upload_payment_receipt'),
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.54),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showReceiptSourceSheet,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _receiptPhoto == null
                    ? cs.outline
                    : _kAmber.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _receiptPhoto == null
                      ? Icons.upload_file_outlined
                      : Icons.check_circle_outline,
                  color: _receiptPhoto == null ? cs.onSurface.withValues(alpha: 0.54) : _kAmber,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _receiptPhoto == null
                        ? AppLocalizations.of(context).get('tap_to_upload_receipt')
                        : _receiptPhoto!.name,
                    style: TextStyle(
                      color: _receiptPhoto == null ? cs.onSurface.withValues(alpha: 0.54) : cs.onSurface,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_receiptPhoto != null)
                  GestureDetector(
                    onTap: () => setState(() => _receiptPhoto = null),
                    child: Icon(Icons.close,
                        size: 16, color: cs.onSurface.withValues(alpha: 0.54)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          AppLocalizations.of(context).get('receipt_note'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 12, height: 1.5),
        ),

        if (_submitError != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kRed.withValues(alpha: 0.4)),
            ),
            child: Text(_submitError!,
                style: const TextStyle(color: _kRed, fontSize: 13)),
          ),
        ],

        const SizedBox(height: 28),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (_submitting || _receiptPhoto == null)
                ? null
                : () => _submitOrder(withReceipt: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAmber,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5),
                  )
                : Text(
                    AppLocalizations.of(context).get('ive_paid_submit'),
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _submitting ? null : () => setState(() => _step = 'form'),
            child: Text(AppLocalizations.of(context).get('back_to_order_details'),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 13)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Form step ─────────────────────────────────────────────────────────
  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kGreen.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.water_drop_rounded, color: _kGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).get('order_form_banner'),
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 12, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (_submitError != null) ...[
            _errorBanner(icon: Icons.error_outline, msg: _submitError!),
            const SizedBox(height: 16),
          ],

          // Quantity
          _sectionLabel(AppLocalizations.of(context).get('required_quantity')),
          TextFormField(
            controller: _litersCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: _inputDeco(
              label: AppLocalizations.of(context).get('quantity'),
              suffixText: 'L',
              icon: Icons.water_drop_outlined,
            ),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return AppLocalizations.of(context).get('required');
              final n = double.tryParse(v);
              if (n == null || n <= 0) return AppLocalizations.of(context).get('val_quantity_valid');
              if (n < 20) return AppLocalizations.of(context).get('val_min_20l');
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Oil quality
          _sectionLabel(AppLocalizations.of(context).get('oil_quality')),
          Row(
            children: [
              _QualityCard(
                label: AppLocalizations.of(context).get('good_quality'),
                price: 110,
                selected: _selectedQuality == 'Good Quality',
                onTap: () => setState(() => _selectedQuality = 'Good Quality'),
              ),
              const SizedBox(width: 10),
              _QualityCard(
                label: AppLocalizations.of(context).get('medium'),
                price: 100,
                selected: _selectedQuality == 'Medium',
                onTap: () => setState(() => _selectedQuality = 'Medium'),
              ),
            ],
          ),
          if (_selectedQuality.isNotEmpty) ...[
            const SizedBox(height: 8),
            Builder(builder: (ctx) {
              final liters = double.tryParse(_litersCtrl.text) ?? 0;
              final price = _selectedQuality == 'Good Quality' ? 110 : 100;
              if (liters <= 0) return const SizedBox.shrink();
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${AppLocalizations.of(context).get('estimated_total')}: ${(liters * price).toStringAsFixed(0)} DZD',
                  style: const TextStyle(color: _kGreen, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              );
            }),
          ],
          const SizedBox(height: 20),

          // Delivery date
          _sectionLabel(AppLocalizations.of(context).get('delivery_date')),
          GestureDetector(
            onTap: _pickDate,
            child: _chip(
              icon: Icons.calendar_today_outlined,
              label: _deliveryDate == null
                  ? AppLocalizations.of(context).get('select_date')
                  : '${_deliveryDate!.year}-'
                      '${_deliveryDate!.month.toString().padLeft(2, '0')}-'
                      '${_deliveryDate!.day.toString().padLeft(2, '0')}',
              active: _deliveryDate != null,
            ),
          ),
          const SizedBox(height: 20),

          // Delivery location
          _sectionLabel(AppLocalizations.of(context).get('delivery_location')),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _addressCtrl,
                  maxLines: 2,
                  decoration: _inputDeco(
                    label: AppLocalizations.of(context).get('address_label'),
                    icon: Icons.location_on_outlined,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _locating ? null : _getLocation,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _kGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _kGreen.withValues(alpha: 0.35)),
                  ),
                  child: _locating
                      ? const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                color: _kGreen, strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.my_location_rounded,
                          color: _kGreen, size: 22),
                ),
              ),
            ],
          ),
          if (_lat != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: _kGreen.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gps_fixed, color: _kGreen, size: 13),
                    const SizedBox(width: 6),
                    Text(
                      '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                      style: const TextStyle(
                          color: _kGreen,
                          fontSize: 11,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),

          // Submit
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _checking ? null : _checkStock,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _checking
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2.5),
                    )
                  : Text(
                      AppLocalizations.of(context).get('place_order_btn'),
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────
  Widget _errorBanner({required IconData icon, required String msg}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kRed.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: _kRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    color: _kRed, fontSize: 13, height: 1.4)),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    String? suffixText,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      suffixText: suffixText,
      prefixIcon:
          icon != null ? Icon(icon, color: cs.onSurface.withValues(alpha: 0.54), size: 18) : null,
      labelStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
      suffixStyle: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
      filled: true,
      fillColor: cs.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kRed),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kRed, width: 1.5),
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required bool active,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: active ? _kGreen.withValues(alpha: 0.1) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? _kGreen.withValues(alpha: 0.5) : cs.outline,
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: active ? _kGreen : cs.onSurface.withValues(alpha: 0.54), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                  color: active ? cs.onSurface : cs.onSurface.withValues(alpha: 0.54), fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(
            color: _kGreen, fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  final String label;
  final int    price;
  final bool   selected;
  final VoidCallback onTap;

  const _QualityCard({
    required this.label,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? _kAmber.withValues(alpha: 0.1) : cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? _kAmber : cs.outline,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: selected ? _kAmber : cs.onSurface.withValues(alpha: 0.3),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected ? cs.onSurface : cs.onSurface.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$price DZD/L',
                style: TextStyle(
                  color: selected ? _kAmber : cs.onSurface.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
