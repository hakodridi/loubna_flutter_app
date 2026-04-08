import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import '../../services/api_service.dart';
import 'register_screen.dart';
import 'otp_screen.dart';
import 'forgot_password_screen.dart';
import '../seller/seller_home_screen.dart';
import '../buyer/buyer_home_screen.dart';
import '../delivery/delivery_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.login(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role') ?? '';
      _routeByRole(role);
    } else {
      final msg = result['message'] ?? '';
      if (msg.toString().toLowerCase().contains('not verified') ||
          msg.toString().toLowerCase().contains('email')) {
        _showUnverifiedDialog();
      } else {
        setState(() => _error = msg);
      }
    }
  }

  void _routeByRole(String role) {
    Widget home;
    switch (role) {
      case 'seller':
        home = const SellerHomeScreen();
      case 'buyer':
        home = const BuyerHomeScreen();
      case 'delivery':
        home = const DeliveryHomeScreen();
      default:
        setState(() => _error = AppLocalizations.of(context).get('unknown_role'));
        return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => home),
    );
  }

  void _showUnverifiedDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
        backgroundColor: cs.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF0A500)),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(ctx).get('email_not_verified'), style: const TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          AppLocalizations.of(ctx).get('resend_otp_dialog'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(ctx).get('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _resendAndGoToOtp();
            },
            child: Text(AppLocalizations.of(ctx).get('send_otp')),
          ),
        ],
      );
      },
    );
  }

  Future<void> _resendAndGoToOtp() async {
    final email = _emailCtrl.text.trim();
    await ApiService.post(
      '/auth/resend-otp',
      {'email': email},
      withAuth: false,
    );
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OtpScreen(email: email),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  const Center(
                    child: Text(
                      'OilTrade',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0A500),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      AppLocalizations.of(context).get('sign_in_subtitle'),
                      style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 14),
                    ),
                  ),
                  const SizedBox(height: 40),
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
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).get('email'),
                      prefixIcon: Icon(
                        Icons.email_outlined,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? AppLocalizations.of(context).get('val_email') : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).get('password'),
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: cs.onSurface.withValues(alpha: 0.38),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: cs.onSurface.withValues(alpha: 0.38),
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? AppLocalizations.of(context).get('val_password_required') : null,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ForgotPasswordScreen(),
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        AppLocalizations.of(context).get('forgot_password'),
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurface.withValues(alpha: 0.54),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _login,
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(AppLocalizations.of(context).get('sign_in')),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context).get('no_account'),
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: Text(AppLocalizations.of(context).get('sign_up')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
