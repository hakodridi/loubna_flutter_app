import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/app_localizations.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  /// If provided, the last slide shows a single "Get Started" button that
  /// navigates here — used after new account registration.
  final Widget? destination;

  const OnboardingScreen({super.key, this.destination});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide(
      titleKey: 'onboarding_slide1_title',
      subtitleKey: 'onboarding_slide1_subtitle',
      descriptionKey: 'onboarding_slide1_desc',
      accent: Color(0xFFF0A500),
    ),
    _Slide(
      titleKey: 'onboarding_slide2_title',
      subtitleKey: 'onboarding_slide2_subtitle',
      descriptionKey: 'onboarding_slide2_desc',
      accent: Color(0xFFF0A500),
    ),
    _Slide(
      titleKey: 'onboarding_slide3_title',
      subtitleKey: 'onboarding_slide3_subtitle',
      descriptionKey: 'onboarding_slide3_desc',
      accent: Color(0xFF3FB950),
    ),
  ];

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  void _goLogin() async {
    await _finish();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _goRegister() async {
    await _finish();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _getStarted() async {
    await _finish();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => widget.destination!),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed:
                    widget.destination != null ? _getStarted : _goLogin,
                child: Text(
                  AppLocalizations.of(context).get('onboarding_skip'),
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 13),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _page == i ? _slides[i].accent : cs.onSurface.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: isLast
                  ? widget.destination != null
                      // Post-registration: single "Get Started" button
                      ? SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _getStarted,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF0A500),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14)),
                            ),
                            child: Text(
                              AppLocalizations.of(context).get('onboarding_get_started'),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        )
                      // Normal flow: Create Account + Sign In
                      : Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _goRegister,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFF0A500),
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).get('create_account'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton(
                                onPressed: _goLogin,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: cs.onSurface.withValues(alpha: 0.7),
                                  side: BorderSide(
                                      color: cs.onSurface.withValues(alpha: 0.24)),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                child: Text(
                                  AppLocalizations.of(context).get('sign_in'),
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _next,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _slides[_page].accent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          AppLocalizations.of(context).get('onboarding_next'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Slide data ──────────────────────────────────────────────────────────────
class _Slide {
  final String titleKey;
  final String subtitleKey;
  final String descriptionKey;
  final Color accent;

  const _Slide({
    required this.titleKey,
    required this.subtitleKey,
    required this.descriptionKey,
    required this.accent,
  });
}

// ── Slide page widget ────────────────────────────────────────────────────────
class _SlidePage extends StatelessWidget {
  final _Slide slide;
  const _SlidePage({required this.slide});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: slide.accent.withValues(alpha: 0.08),
              border: Border.all(
                  color: slide.accent.withValues(alpha: 0.2), width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/logo.jpg',
                width: 160,
                height: 160,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Subtitle chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: slide.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: slide.accent.withValues(alpha: 0.3)),
            ),
            child: Text(
              AppLocalizations.of(context).get(slide.subtitleKey),
              style: TextStyle(
                  color: slide.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            AppLocalizations.of(context).get(slide.titleKey),
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          Text(
            AppLocalizations.of(context).get(slide.descriptionKey),
            style: TextStyle(
              color: cs.onSurface.withValues(alpha: 0.54),
              fontSize: 14,
              height: 1.7,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        ),
      ),
    );
  }
}
