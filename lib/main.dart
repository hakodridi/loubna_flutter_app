import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/notification_service.dart';
import 'services/app_localizations.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/buyer/buyer_home_screen.dart';
import 'screens/delivery/delivery_home_screen.dart';
import 'screens/seller/seller_home_screen.dart';

/// Global notifier — any widget can read or toggle the current theme mode.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

/// Global navigator key — used by NotificationService to navigate on notification tap.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  await NotificationService.init();
  await AppLocalizations.loadSavedLocale();
  runApp(const OilTrade());
}

class OilTrade extends StatelessWidget {
  const OilTrade({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => ValueListenableBuilder<Locale>(
        valueListenable: localeNotifier,
        builder: (context, locale, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'OilTrade',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppLocalizationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],

        // ── Dark theme ────────────────────────────────────────────────────
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF07080F),
          cardColor: const Color(0xFF161B22),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFF0A500),
            secondary: Color(0xFF3FB950),
            surface: Color(0xFF161B22),
            onSurface: Colors.white,
            surfaceContainerHighest: Color(0xFF0D1117),
            outline: Color(0xFF30363D),
            outlineVariant: Color(0xFF30363D),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF161B22),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFF161B22),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF30363D))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF0A500), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
            labelStyle: const TextStyle(color: Colors.white54),
            hintStyle: const TextStyle(color: Colors.white30),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0A500), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFFF0A500))),
        ),

        // ── Light theme ───────────────────────────────────────────────────
        theme: ThemeData(
          brightness: Brightness.light,
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          cardColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: Color(0xFFF0A500),
            secondary: Color(0xFF3FB950),
            surface: Colors.white,
            onSurface: Color(0xFF1C2128),
            surfaceContainerHighest: Color(0xFFEEF1F4),
            outline: Color(0xFFD0D7DE),
            outlineVariant: Color(0xFFE8ECEF),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1C2128),
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: Color(0xFF1C2128)),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD0D7DE))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF0A500), width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.5)),
            labelStyle: const TextStyle(color: Colors.black54),
            hintStyle: const TextStyle(color: Colors.black38),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF0A500), foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 16), textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
          textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: const Color(0xFFF0A500))),
        ),

        home: const SplashRouter(),
      ),
      ),
    );
  }
}

class SplashRouter extends StatefulWidget {
  const SplashRouter({super.key});

  @override
  State<SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<SplashRouter>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _route();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _route() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final role = prefs.getString('role');

    final onboardingDone = prefs.getBool('onboarding_done') ?? false;
    if (!onboardingDone) {
      _go(const OnboardingScreen());
      return;
    }

    if (token == null || role == null) {
      _go(const LoginScreen());
      return;
    }
    switch (role) {
      case 'seller':
        _go(const SellerHomeScreen());
      case 'buyer':
        _go(const BuyerHomeScreen());
      case 'delivery':
        _go(const DeliveryHomeScreen());
      case 'admin':
        _go(const AdminHomeScreen());
      default:
        _go(const LoginScreen());
    }
  }

  void _go(Widget screen) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF0A500).withValues(alpha: 0.35),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'OilTrade',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF0A500),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Used Cooking Oil Trading Platform',
                style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 15),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  color: Color(0xFFF0A500),
                  strokeWidth: 2.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
