import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import 'otp_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _ccpCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  String _selectedRole = 'seller';
  String _selectedWilaya = 'Alger';
  String _selectedSellerType = 'house';

  int _passStrength = 0; // 0-4

  static const List<String> _wilayas = [
    'Adrar', 'Chlef', 'Laghouat', 'Oum El Bouaghi', 'Batna', 'Béjaïa',
    'Biskra', 'Béchar', 'Blida', 'Bouira', 'Tamanrasset', 'Tébessa',
    'Tlemcen', 'Tiaret', 'Tizi Ouzou', 'Alger', 'Djelfa', 'Jijel',
    'Sétif', 'Saïda', 'Skikda', 'Sidi Bel Abbès', 'Annaba', 'Guelma',
    'Constantine', 'Médéa', 'Mostaganem', 'M\'Sila', 'Mascara', 'Ouargla',
    'Oran', 'El Bayadh', 'Illizi', 'Bordj Bou Arréridj', 'Boumerdès',
    'El Tarf', 'Tindouf', 'Tissemsilt', 'El Oued', 'Khenchela',
    'Souk Ahras', 'Tipaza', 'Mila', 'Aïn Defla', 'Naâma', 'Aïn Témouchent',
    'Ghardaïa', 'Relizane', 'Timimoun', 'Bordj Badji Mokhtar',
    'Ouled Djellal', 'Béni Abbès', 'In Salah', 'In Guezzam', 'Touggourt',
    'Djanet', 'El M\'Ghair', 'El Meniaa',
  ];

  static const Map<String, Map<String, dynamic>> _roles = {
    'seller': {
      'label': 'Seller',
      'icon': Icons.store_outlined,
      'color': Color(0xFFF0A500),
      'desc': 'Sell used cooking oil',
    },
    'buyer': {
      'label': 'Buyer',
      'icon': Icons.shopping_cart_outlined,
      'color': Color(0xFF3FB950),
      'desc': 'Purchase collected oil',
    },
    'delivery': {
      'label': 'Delivery Agent',
      'icon': Icons.local_shipping_outlined,
      'color': Color(0xFF58A6FF),
      'desc': 'Handle order deliveries',
    },
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _ccpCtrl.dispose();
    _capacityCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _calcStrength(String pass) {
    int strength = 0;
    if (pass.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(pass)) strength++;
    if (RegExp(r'[0-9]').hasMatch(pass)) strength++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(pass)) strength++;
    setState(() => _passStrength = strength);
  }

  Color _strengthColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (_passStrength) {
      case 1:
        return Colors.redAccent;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return const Color(0xFF3FB950);
      default:
        return cs.outlineVariant;
    }
  }

  String _strengthLabel(BuildContext context) {
    switch (_passStrength) {
      case 1:
        return AppLocalizations.of(context).get('strength_weak');
      case 2:
        return AppLocalizations.of(context).get('strength_fair');
      case 3:
        return AppLocalizations.of(context).get('strength_good');
      case 4:
        return AppLocalizations.of(context).get('strength_strong');
      default:
        return '';
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.register(
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      password: _passCtrl.text,
      wilaya: _selectedWilaya,
      role: _selectedRole,
      ccp: (_selectedRole == 'seller' || _selectedRole == 'delivery') ? _ccpCtrl.text.trim() : null,
      sellerType: _selectedRole == 'seller' ? _selectedSellerType : null,
      capacityLiters: _selectedRole == 'delivery'
          ? double.tryParse(_capacityCtrl.text.trim())
          : null,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(email: _emailCtrl.text.trim()),
        ),
      );
    } else {
      String msg = result['message'] ?? 'Registration failed';
      final errors = result['errors'];
      if (errors != null && errors is Map) {
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          msg = firstError.first.toString();
        }
      }
      setState(() => _error = msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('create_account')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Full Name
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('name'),
                    prefixIcon: Icon(Icons.person_outline, color: cs.onSurface.withValues(alpha: 0.38)),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? AppLocalizations.of(context).get('val_name_min') : null,
                ),
                const SizedBox(height: 14),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('email'),
                    prefixIcon: Icon(Icons.email_outlined, color: cs.onSurface.withValues(alpha: 0.38)),
                  ),
                  validator: (v) =>
                      (v == null || !v.contains('@')) ? AppLocalizations.of(context).get('val_email') : null,
                ),
                const SizedBox(height: 14),

                // Phone
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('phone_number'),
                    prefixIcon: Icon(Icons.phone_outlined, color: cs.onSurface.withValues(alpha: 0.38)),
                    hintText: AppLocalizations.of(context).get('hint_phone'),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 9) ? AppLocalizations.of(context).get('valid_phone') : null,
                ),
                const SizedBox(height: 14),

                // Wilaya
                DropdownButtonFormField<String>(
                  value: _selectedWilaya,
                  dropdownColor: cs.surfaceContainerHighest,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('wilaya'),
                    prefixIcon: Icon(Icons.location_on_outlined, color: cs.onSurface.withValues(alpha: 0.38)),
                  ),
                  items: _wilayas
                      .map(
                        (w) => DropdownMenuItem(
                          value: w,
                          child: Text(w, style: const TextStyle(fontSize: 14)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedWilaya = v!),
                ),
                const SizedBox(height: 14),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  onChanged: _calcStrength,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('password'),
                    prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withValues(alpha: 0.38)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  validator: (v) =>
                      (v == null || v.length < 8) ? AppLocalizations.of(context).get('password_min') : null,
                ),

                // Password strength bar
                if (_passCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _passStrength / 4.0,
                            backgroundColor: cs.outlineVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _strengthColor(context),
                            ),
                            minHeight: 5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _strengthLabel(context),
                        style: TextStyle(
                          fontSize: 12,
                          color: _strengthColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),

                // Confirm Password
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscureConfirm,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context).get('confirm_password'),
                    prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withValues(alpha: 0.38)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  validator: (v) =>
                      v != _passCtrl.text ? AppLocalizations.of(context).get('password_mismatch') : null,
                ),
                const SizedBox(height: 20),

                // Seller type — shown for sellers only
                if (_selectedRole == 'seller') ...[
                  Text(
                    AppLocalizations.of(context).get('seller_type'),
                    style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SellerTypeCard(
                        value: 'house',
                        selected: _selectedSellerType,
                        label: AppLocalizations.of(context).get('house'),
                        desc: AppLocalizations.of(context).get('house_desc'),
                        icon: Icons.home_outlined,
                        color: const Color(0xFFF0A500),
                        onTap: () => setState(() => _selectedSellerType = 'house'),
                      ),
                      const SizedBox(width: 10),
                      _SellerTypeCard(
                        value: 'business',
                        selected: _selectedSellerType,
                        label: AppLocalizations.of(context).get('business'),
                        desc: AppLocalizations.of(context).get('business_desc'),
                        icon: Icons.storefront_outlined,
                        color: const Color(0xFFF0A500),
                        onTap: () => setState(() => _selectedSellerType = 'business'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                // CCP field — shown for sellers and delivery agents
                if (_selectedRole == 'seller' || _selectedRole == 'delivery') ...[
                  TextFormField(
                    controller: _ccpCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).get('label_ccp_baridi'),
                      prefixIcon: Icon(Icons.account_balance_outlined, color: cs.onSurface.withValues(alpha: 0.38)),
                      hintText: AppLocalizations.of(context).get('hint_ccp'),
                    ),
                    validator: (v) {
                      if ((_selectedRole == 'seller' || _selectedRole == 'delivery') && (v == null || v.trim().isEmpty)) {
                        return AppLocalizations.of(context).get('val_ccp_required');
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Capacity field — delivery agents only
                if (_selectedRole == 'delivery') ...[
                  TextFormField(
                    controller: _capacityCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).get('label_vehicle_capacity'),
                      prefixIcon: Icon(Icons.local_shipping_outlined, color: cs.onSurface.withValues(alpha: 0.38)),
                      suffixText: 'L',
                      hintText: AppLocalizations.of(context).get('hint_capacity'),
                    ),
                    validator: (v) {
                      if (_selectedRole != 'delivery') return null;
                      if (v == null || v.trim().isEmpty) return AppLocalizations.of(context).get('val_capacity_required');
                      final d = double.tryParse(v.trim());
                      if (d == null || d < 1) return AppLocalizations.of(context).get('val_capacity_min');
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Role selection
                Text(
                  AppLocalizations.of(context).get('select_role'),
                  style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: _roles.entries.map((entry) {
                    final isSelected = _selectedRole == entry.key;
                    final roleData = entry.value;
                    final color = roleData['color'] as Color;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _selectedRole = entry.key;
                          if (_selectedRole != 'seller') _ccpCtrl.clear();
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.15)
                                : cs.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color : cs.outline,
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                roleData['icon'] as IconData,
                                color: isSelected ? color : cs.onSurface.withValues(alpha: 0.38),
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppLocalizations.of(context).get(entry.key),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? color : cs.onSurface.withValues(alpha: 0.54),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(AppLocalizations.of(context).get('create_account')),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SellerTypeCard extends StatelessWidget {
  final String value;
  final String selected;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SellerTypeCard({
    required this.value,
    required this.selected,
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSelected = value == selected;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : cs.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : cs.outline,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? color : cs.onSurface.withValues(alpha: 0.38),
                  size: 26),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? color : cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurface.withValues(alpha: 0.45),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
