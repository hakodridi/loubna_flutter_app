import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';

class RequestCollectionScreen extends StatefulWidget {
  const RequestCollectionScreen({super.key});

  @override
  State<RequestCollectionScreen> createState() =>
      _RequestCollectionScreenState();
}

class _RequestCollectionScreenState extends State<RequestCollectionScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _addressCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  final _litersCtrl  = TextEditingController();

  bool _loading     = false;
  bool _locLoading  = false;
  String? _error;
  bool _success     = false;

  DateTime? _pickupDate;
  XFile?    _oilPhoto;
  String    _quality   = 'Good Quality';
  double?   _latitude;
  double?   _longitude;

  // Pickup location (for small orders < 15L)
  List<Map<String, dynamic>> _pickupLocations = [];
  Map<String, dynamic>? _selectedLocation;
  bool _locationsLoading = false;

  String _sellerType = 'house'; // 'house' | 'business'

  static const _accent = Color(0xFFF0A500);

  // Returns buy price per litre based on seller type + quality
  int _buyPrice(String quality) {
    final isGood = quality == 'Good Quality';
    if (_sellerType == 'business') return isGood ? 80 : 70;
    return isGood ? 60 : 50;
  }

  bool get _isSmallOrder {
    final v = double.tryParse(_litersCtrl.text.trim());
    return v != null && v > 0 && v < 15.0;
  }

  @override
  void initState() {
    super.initState();
    _loadPickupLocations();
    _loadSellerType();
    _litersCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadSellerType() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('seller_type') ?? 'house';
    if (mounted) setState(() => _sellerType = t.isEmpty ? 'house' : t);
  }

  @override
  void dispose() {
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _litersCtrl.dispose();
    super.dispose();
  }

  // ── Load pickup locations from backend ────────────────────────────────────
  Future<void> _loadPickupLocations() async {
    setState(() => _locationsLoading = true);
    try {
      final result = await ApiService.get('/pickup-locations');
      if (result['success'] == true) {
        final data = result['data'];
        if (data is List) {
          setState(() {
            _pickupLocations = data.cast<Map<String, dynamic>>();
          });
        }
      }
    } catch (_) {
      // Silently fail — user will see empty list
    } finally {
      setState(() => _locationsLoading = false);
    }
  }

  // ── Date picker ───────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(primary: _accent)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _pickupDate = d);
  }

  // ── Geolocator ────────────────────────────────────────────────────────────
  Future<void> _useCurrentLocation() async {
    setState(() => _locLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _setLocError('Location services are disabled.');
        return;
      }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          _setLocError('Location permission denied.');
          return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        _setLocError('Location permission permanently denied.');
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      try {
        final placemarks =
            await placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (placemarks.isNotEmpty) {
          final p = placemarks.first;
          final parts = [
            p.street,
            p.subLocality,
            p.locality,
            p.administrativeArea,
          ].where((s) => s != null && s.isNotEmpty).toList();
          _addressCtrl.text = parts.join(', ');
        }
      } catch (_) {
        _addressCtrl.text =
            '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}';
      }

      setState(() {
        _latitude  = pos.latitude;
        _longitude = pos.longitude;
        _locLoading = false;
      });
    } catch (e) {
      _setLocError('Could not get location: $e');
    }
  }

  void _setLocError(String msg) {
    setState(() { _locLoading = false; _error = msg; });
  }

  // ── Photo picker ──────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked != null) setState(() => _oilPhoto = picked);
  }

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: _accent),
              title: Text(AppLocalizations.of(context).get('take_photo')),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library_outlined, color: _accent),
              title: Text(AppLocalizations.of(context).get('choose_from_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickupDate == null) {
      setState(() => _error = AppLocalizations.of(context).get('val_select_pickup_date'));
      return;
    }
    if (_isSmallOrder && _selectedLocation == null) {
      setState(() => _error = AppLocalizations.of(context).get('val_select_pickup_location'));
      return;
    }
    setState(() { _loading = true; _error = null; });

    final fields = <String, String>{
      'liters':      _litersCtrl.text.trim(),
      'notes':       _notesCtrl.text.trim(),
      'pickup_date': _fmtDate(_pickupDate!),
      'quality':     _quality,
    };

    if (_isSmallOrder) {
      fields['pickup_location_id'] = _selectedLocation!['id'].toString();
    } else {
      fields['address'] = _addressCtrl.text.trim();
      if (_latitude != null)  fields['latitude']  = _latitude.toString();
      if (_longitude != null) fields['longitude'] = _longitude.toString();
    }

    final result = await ApiService.postMultipart(
      '/collection-orders',
      fields,
      file: _oilPhoto,
      fieldName: 'oil_photo',
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      setState(() => _success = true);
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('failed_to_submit'));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('request_collection')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(child: _success ? _buildSuccess() : _buildForm()),
    );
  }

  // ── Success state ─────────────────────────────────────────────────────────
  Widget _buildSuccess() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.hourglass_top_rounded,
                  color: Color(0xFF3FB950), size: 42),
            ),
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context).get('listing_submitted'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).get('listing_submitted_body'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onSurface.withValues(alpha: 0.54), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 8),
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 24),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: _accent.withValues(alpha: 0.3)),
              ),
              child: Text(
                AppLocalizations.of(context).get('status_pending_admin'),
                style: TextStyle(
                    color: _accent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).get('back_to_home')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────
  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Info banner
            _infoBanner(),
            const SizedBox(height: 20),

            if (_error != null) _errorBanner(),

            // ── Liters ──────────────────────────────────────────────────
            _sectionLabel(AppLocalizations.of(context).get('oil_quantity')),
            TextFormField(
              controller: _litersCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).get('label_quantity_min5'),
                prefixIcon:
                    const Icon(Icons.water_drop_outlined, color: Color(0xFF8B949E)),
                suffixText: 'L',
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return AppLocalizations.of(context).get('val_enter_quantity');
                final d = double.tryParse(v);
                if (d == null || d < 5) return AppLocalizations.of(context).get('val_min_5_liters');
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Oil quality ──────────────────────────────────────────────
            _sectionLabel(AppLocalizations.of(context).get('quality')),
            Row(
              children: ['Good Quality', 'Medium'].map((q) {
                final selected = _quality == q;
                final price    = _buyPrice(q);
                final cs       = Theme.of(context).colorScheme;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _quality = q),
                    child: Container(
                      margin: EdgeInsets.only(
                          right: q == 'Good Quality' ? 8 : 0),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: selected
                            ? _accent.withValues(alpha: 0.1)
                            : cs.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected ? _accent : cs.outline,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.check_circle
                                    : Icons.circle_outlined,
                                color: selected
                                    ? _accent
                                    : cs.onSurface.withValues(alpha: 0.3),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  q == 'Good Quality'
                                      ? AppLocalizations.of(context).get('good_quality')
                                      : AppLocalizations.of(context).get('medium'),
                                  style: TextStyle(
                                    color: selected
                                        ? cs.onSurface
                                        : cs.onSurface.withValues(alpha: 0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$price DZD/${AppLocalizations.of(context).get('liters')}',
                            style: TextStyle(
                              color: selected
                                  ? _accent
                                  : cs.onSurface.withValues(alpha: 0.45),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            Builder(builder: (ctx) {
              final liters = double.tryParse(_litersCtrl.text.trim()) ?? 0;
              if (liters <= 0) return const SizedBox(height: 20);
              final est = (liters * _buyPrice(_quality)).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 20),
                child: Text(
                  '${AppLocalizations.of(context).get('estimated_earnings')}: $est DZD',
                  style: const TextStyle(
                      color: Color(0xFF3FB950),
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
              );
            }),

            // ── Pickup date ───────────────────────────────────────────────
            _sectionLabel(AppLocalizations.of(context).get('pickup_date')),
            _datePicker(),
            const SizedBox(height: 20),

            // ── Location (conditional) ────────────────────────────────────
            _sectionLabel(AppLocalizations.of(context).get('pickup_address')),
            if (_isSmallOrder)
              _buildPickupLocationSelector()
            else
              _buildAddressSection(),
            const SizedBox(height: 20),

            // ── Oil photo ────────────────────────────────────────────────
            _sectionLabel(AppLocalizations.of(context).get('oil_photo')),
            _photoPickerTile(),
            const SizedBox(height: 20),

            // ── Notes ────────────────────────────────────────────────────
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context).get('notes'),
                prefixIcon: const Icon(Icons.notes_outlined, color: Color(0xFF8B949E)),
                alignLabelWithHint: true,
                hintText: AppLocalizations.of(context).get('notes'),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _submit,
                icon: _loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.send_outlined),
                label: Text(_loading
                    ? AppLocalizations.of(context).get('submitting')
                    : AppLocalizations.of(context).get('submit_listing')),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ── Pickup location selector (small orders < 15L) ─────────────────────────
  Widget _buildPickupLocationSelector() {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Info banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF58A6FF).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF58A6FF).withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF58A6FF), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).get('orders_under_15l_info'),
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (_locationsLoading)
          const Center(child: Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
          ))
        else if (_pickupLocations.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cs.outline),
            ),
            child: Text(
              AppLocalizations.of(context).get('no_pickup_locations'),
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.45), fontSize: 13),
            ),
          )
        else
          ..._pickupLocations.map((loc) => _pickupLocationTile(loc)),
      ],
    );
  }

  Widget _pickupLocationTile(Map<String, dynamic> loc) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = _selectedLocation?['id'] == loc['id'];
    return GestureDetector(
      onTap: () => setState(() => _selectedLocation = loc),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? _accent.withValues(alpha: 0.08) : cs.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _accent : cs.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.location_on_outlined,
              color: isSelected ? _accent : cs.onSurface.withValues(alpha: 0.38),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc['name'] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: isSelected ? _accent : cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc['address'] ?? '',
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withValues(alpha: 0.54),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: _accent, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Address section (large orders ≥ 15L) ─────────────────────────────────
  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _addressCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).get('label_address'),
            prefixIcon: const Icon(Icons.location_on_outlined,
                color: Color(0xFF8B949E)),
            alignLabelWithHint: true,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? AppLocalizations.of(context).get('val_enter_address')
              : null,
        ),
        const SizedBox(height: 8),
        _locationButton(),
        if (_latitude != null) ...[
          const SizedBox(height: 6),
          _coordChip(),
        ],
      ],
    );
  }

  // ── Sub-widgets ───────────────────────────────────────────────────────────

  Widget _infoBanner() {
    final cs = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                AppLocalizations.of(context).get('listing_review_info'),
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.6), fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
  }

  Widget _errorBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        child: Text(_error!,
            style:
                const TextStyle(color: Colors.redAccent, fontSize: 13)),
      );

  Widget _sectionLabel(String text) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.54),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );
  }

  Widget _datePicker() {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _pickupDate == null
                  ? cs.outline
                  : _accent.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 16,
                  color:
                      _pickupDate == null ? cs.onSurface.withValues(alpha: 0.38) : _accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _pickupDate == null
                      ? AppLocalizations.of(context).get('select_date')
                      : '${_pickupDate!.day}/${_pickupDate!.month}/${_pickupDate!.year}',
                  style: TextStyle(
                    fontSize: 12,
                    color: _pickupDate == null
                        ? cs.onSurface.withValues(alpha: 0.38)
                        : cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Widget _locationButton() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _locLoading ? null : _useCurrentLocation,
          style: OutlinedButton.styleFrom(
            foregroundColor: _accent,
            side: BorderSide(color: _accent.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          icon: _locLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _accent))
              : const Icon(Icons.my_location, size: 16),
          label: Text(
            _locLoading
                ? AppLocalizations.of(context).get('getting_location')
                : AppLocalizations.of(context).get('use_current_location'),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );

  Widget _coordChip() => Row(
        children: [
          const Icon(Icons.location_on, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
            style: const TextStyle(color: Colors.green, fontSize: 11),
          ),
        ],
      );

  Widget _photoPickerTile() {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
        onTap: _showPhotoSourceSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _oilPhoto == null
                  ? cs.outline
                  : _accent.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _oilPhoto == null
                    ? Icons.add_photo_alternate_outlined
                    : Icons.check_circle_outline,
                color: _oilPhoto == null ? cs.onSurface.withValues(alpha: 0.38) : _accent,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _oilPhoto == null
                      ? AppLocalizations.of(context).get('upload_oil_photo')
                      : _oilPhoto!.name,
                  style: TextStyle(
                    color: _oilPhoto == null
                        ? cs.onSurface.withValues(alpha: 0.38)
                        : cs.onSurface,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_oilPhoto != null)
                GestureDetector(
                  onTap: () => setState(() => _oilPhoto = null),
                  child: Icon(Icons.close,
                      size: 16, color: cs.onSurface.withValues(alpha: 0.38)),
                ),
            ],
          ),
        ),
      );
  }

}
