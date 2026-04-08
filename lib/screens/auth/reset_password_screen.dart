import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../seller/seller_home_screen.dart';
import '../buyer/buyer_home_screen.dart';
import '../delivery/delivery_home_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  // Step 1 = verify OTP, Step 2 = set new password
  int _step = 1;
  String _verifiedOtp = '';

  // OTP
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  int _secondsLeft = 300;
  Timer? _timer;
  bool _canResend = false;
  bool _resending = false;

  // Password
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  bool _loading = false;
  String? _error;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) c.dispose();
    for (final f in _otpFocusNodes) f.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _secondsLeft = 300;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
        setState(() => _canResend = true);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String get _timerLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _otpValue => _otpControllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() { _resending = true; _error = null; _successMsg = null; });
    final result = await AuthService.forgotPassword(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);
    if (result['success'] == true) {
      setState(() => _successMsg = AppLocalizations.of(context).get('code_resent'));
      _startTimer();
      for (final c in _otpControllers) c.clear();
      _otpFocusNodes[0].requestFocus();
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('resend_code'));
    }
  }

  // ── Step 1: verify OTP ────────────────────────────────────────────────────

  Future<void> _verifyOtp() async {
    final otp = _otpValue;
    if (otp.length < 6) {
      setState(() => _error = AppLocalizations.of(context).get('enter_all_digits'));
      return;
    }
    setState(() { _loading = true; _error = null; });

    final result = await AuthService.verifyResetOtp(
      email: widget.email,
      otp: otp,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      _timer?.cancel();
      setState(() {
        _verifiedOtp = otp;
        _step = 2;
        _error = null;
        _successMsg = null;
      });
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('invalid_otp'));
    }
  }

  // ── Step 2: set new password ──────────────────────────────────────────────

  Future<void> _resetPassword() async {
    if (_passCtrl.text.length < 8) {
      setState(() => _error = AppLocalizations.of(context).get('password_min'));
      return;
    }
    if (_passCtrl.text != _confirmCtrl.text) {
      setState(() => _error = AppLocalizations.of(context).get('password_mismatch'));
      return;
    }
    setState(() { _loading = true; _error = null; });

    final result = await AuthService.resetPassword(
      email: widget.email,
      otp: _verifiedOtp,
      password: _passCtrl.text,
      passwordConfirmation: _confirmCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      // Auto-login with the new password
      final loginResult = await AuthService.login(
        email: widget.email,
        password: _passCtrl.text,
      );
      if (!mounted) return;

      if (loginResult['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final role = prefs.getString('role') ?? '';
        Widget home;
        switch (role) {
          case 'seller':
            home = const SellerHomeScreen();
          case 'buyer':
            home = const BuyerHomeScreen();
          case 'delivery':
            home = const DeliveryHomeScreen();
          default:
            setState(() => _error = AppLocalizations.of(context).get('password_reset_manual'));
            return;
        }
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => home),
          (_) => false,
        );
      } else {
        // Login failed for some reason — go to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (_) => false,
        );
      }
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('failed_to_reset_password'));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _errorBox() => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
      );

  Widget _successBox() => Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF3FB950).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF3FB950).withValues(alpha: 0.4)),
        ),
        child: Text(_successMsg!, style: const TextStyle(color: Color(0xFF3FB950), fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_step == 1 ? AppLocalizations.of(context).get('enter_reset_code') : AppLocalizations.of(context).get('new_password')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () {
            if (_step == 2) {
              setState(() { _step = 1; _error = null; });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: _step == 1 ? _buildStep1(cs) : _buildStep2(cs),
        ),
      ),
    );
  }

  // ── Step 1 UI ─────────────────────────────────────────────────────────────

  Widget _buildStep1(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              const Icon(Icons.mark_email_read_outlined, size: 52, color: Color(0xFFF0A500)),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).get('enter_reset_code'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '${AppLocalizations.of(context).get('otp_sent_to')}\n${widget.email}',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // OTP boxes
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) => SizedBox(
            width: 46, height: 54,
            child: TextFormField(
              controller: _otpControllers[i],
              focusNode: _otpFocusNodes[i],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              maxLength: 1,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF0A500)),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: cs.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFF0A500), width: 2),
                ),
                filled: true,
                fillColor: cs.surface,
              ),
              onChanged: (v) => _onDigitChanged(i, v),
            ),
          )),
        ),
        const SizedBox(height: 24),

        if (_error != null) _errorBox(),
        if (_successMsg != null) _successBox(),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _verifyOtp,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text(AppLocalizations.of(context).get('verify_code')),
          ),
        ),
        const SizedBox(height: 20),

        Center(
          child: _canResend
              ? TextButton.icon(
                  onPressed: _resending ? null : _resend,
                  icon: _resending
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF0A500)))
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(AppLocalizations.of(context).get('resend_code')),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.timer_outlined, size: 16, color: cs.onSurface.withValues(alpha: 0.38)),
                    const SizedBox(width: 6),
                    Text('${AppLocalizations.of(context).get('resend_in')} $_timerLabel',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 13)),
                  ],
                ),
        ),
      ],
    );
  }

  // ── Step 2 UI ─────────────────────────────────────────────────────────────

  Widget _buildStep2(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(16)),
          child: Column(
            children: [
              const Icon(Icons.lock_reset_rounded, size: 52, color: Color(0xFF3FB950)),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context).get('set_new_password'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).get('code_verified_subtitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).get('new_password'),
            prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withValues(alpha: 0.38)),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility,
                  color: cs.onSurface.withValues(alpha: 0.38)),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).get('confirm_password'),
            prefixIcon: Icon(Icons.lock_outline, color: cs.onSurface.withValues(alpha: 0.38)),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  color: cs.onSurface.withValues(alpha: 0.38)),
              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
        ),
        const SizedBox(height: 24),

        if (_error != null) _errorBox(),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _resetPassword,
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text(AppLocalizations.of(context).get('reset_password')),
          ),
        ),
      ],
    );
  }
}
