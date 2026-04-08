import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/app_localizations.dart';
import '../seller/seller_home_screen.dart';
import '../buyer/buyer_home_screen.dart';
import '../delivery/delivery_home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;
  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _loading = false;
  bool _resending = false;
  String? _error;
  String? _successMsg;
  int _secondsLeft = 300; // 5 minutes
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
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

  String get _otpValue =>
      _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final otp = _otpValue;
    if (otp.length < 6) {
      setState(() => _error = AppLocalizations.of(context).get('enter_all_digits'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AuthService.verifyOtp(
      email: widget.email,
      otp: otp,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result['success'] == true) {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role') ?? '';
      _routeByRole(role);
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('invalid_otp'));
    }
  }

  Future<void> _routeByRole(String role) async {
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
    // Only show onboarding once. After the first time it's skipped/finished,
    // go directly to the home screen on every subsequent login.
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
          builder: (_) => onboardingDone
              ? home
              : OnboardingScreen(destination: home)),
      (_) => false,
    );
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    setState(() {
      _resending = true;
      _error = null;
      _successMsg = null;
    });
    final result = await AuthService.resendOtp(widget.email);
    if (!mounted) return;
    setState(() => _resending = false);

    if (result['success'] == true) {
      setState(() => _successMsg = AppLocalizations.of(context).get('otp_resent'));
      _startTimer();
      for (final c in _controllers) c.clear();
      _focusNodes[0].requestFocus();
    } else {
      setState(() => _error = result['message'] ?? AppLocalizations.of(context).get('failed_to_resend_otp'));
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    if (_otpValue.length == 6) {
      _verify();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).get('verify_email')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      size: 52,
                      color: Color(0xFFF0A500),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context).get('check_email'),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${AppLocalizations.of(context).get('otp_sent_to')}\n${widget.email}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.54),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 46,
                    height: 54,
                    child: TextFormField(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF0A500),
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: cs.outline,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFFF0A500),
                            width: 2,
                          ),
                        ),
                        filled: true,
                        fillColor: cs.surface,
                      ),
                      onChanged: (v) => _onDigitChanged(i, v),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // Error/success
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
              if (_successMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3FB950).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF3FB950).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    _successMsg!,
                    style: const TextStyle(
                      color: Color(0xFF3FB950),
                      fontSize: 13,
                    ),
                  ),
                ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _verify,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Text(AppLocalizations.of(context).get('verify')),
                ),
              ),
              const SizedBox(height: 20),

              // Timer & resend
              Center(
                child: _canResend
                    ? TextButton.icon(
                        onPressed: _resending ? null : _resend,
                        icon: _resending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF0A500),
                                ),
                              )
                            : const Icon(Icons.refresh, size: 16),
                        label: Text(AppLocalizations.of(context).get('resend_otp')),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: cs.onSurface.withValues(alpha: 0.38),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${AppLocalizations.of(context).get('resend_in')} $_timerLabel',
                            style: TextStyle(
                              color: cs.onSurface.withValues(alpha: 0.38),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

