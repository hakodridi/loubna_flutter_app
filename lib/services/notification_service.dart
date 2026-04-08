import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Key written to SharedPreferences when the user taps the "Reorder" action.
const kPendingReorderKey = 'pending_reorder_type';

/// Represents one in-app event returned to the home screen for display.
class OrderEvent {
  final String title;
  final String body;
  final bool isSuccess; // green for approved/accepted, red for rejected
  const OrderEvent({required this.title, required this.body, required this.isSuccess});
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _prefKey = 'notifications_enabled';

  static bool get _supported => !kIsWeb;

  static Future<void> init() async {
    if (!_supported || _initialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );
    _initialized = true;
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'reorder' ||
        response.payload?.startsWith('reorder:') == true) {
      final type = response.payload?.replaceFirst('reorder:', '') ?? 'collection';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kPendingReorderKey, type);
    }
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? true;
  }

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  static Future<String> _lang() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('app_language') ?? 'en';
  }

  static Future<Map<String, String>> _bi(
      String enTitle, String arTitle, String enBody, String arBody,
      {String liters = ''}) async {
    final isAr = (await _lang()) == 'ar';
    return {
      'title': isAr ? arTitle : enTitle,
      'body': (isAr ? arBody : enBody).replaceAll('{liters}', liters),
    };
  }

  // ── OS notification ──────────────────────────────────────────────────────

  static Future<void> show({
    required String title,
    required String body,
    int id = 0,
    String? payload,
    bool withReorderAction = false,
    String reorderType = 'collection',
  }) async {
    if (!_supported) return;
    if (!await isEnabled()) return;
    if (!_initialized) await init();

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.areNotificationsEnabled() ?? false;
    if (!granted) await androidPlugin?.requestNotificationsPermission();

    final lang = await _lang();
    final reorderLabel = lang == 'ar' ? 'إعادة الطلب' : 'Reorder';

    final actions = withReorderAction
        ? [AndroidNotificationAction('reorder', reorderLabel, showsUserInterface: true)]
        : <AndroidNotificationAction>[];

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        'oiltrade_orders',
        'Order Updates',
        channelDescription: 'Notifications for order and delivery status updates',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        actions: actions,
      ),
    );
    await _plugin.show(
      id,
      title,
      body,
      details,
      payload: payload ?? (withReorderAction ? 'reorder:$reorderType' : null),
    );
  }

  // ── Collection order polling ─────────────────────────────────────────────
  /// Returns the list of [OrderEvent]s that fired this call (for in-app toast display).
  static Future<List<OrderEvent>> checkCollectionOrders(List<dynamic> orders) async {
    final events = <OrderEvent>[];
    if (!await isEnabled()) return events;
    final prefs = await SharedPreferences.getInstance();

    for (final order in orders) {
      final id     = order['id']?.toString();
      final status = order['status']?.toString() ?? '';
      final liters = order['liters']?.toString() ?? '';
      if (id == null) continue;

      // ── 1. Admin approved ───────────────────────────────────────────────
      final approvedKey = 'notified_collection_approved_$id';
      if (!(prefs.getBool(approvedKey) ?? false)) {
        if (status == 'assigned' || status == 'pending') {
          final bi = await _bi(
            'Collection Order Approved ✓',
            'تمت الموافقة على طلب التجميع ✓',
            'Your collection order of {liters}L has been approved. A delivery agent will be assigned shortly.',
            'تمت الموافقة على طلب تجميعك ({liters} لتر). سيتم تعيين عامل توصيل قريباً.',
            liters: liters,
          );
          events.add(OrderEvent(title: bi['title']!, body: bi['body']!, isSuccess: true));
          await show(id: _stableId('col_appr', id), title: bi['title']!, body: bi['body']!);
          await prefs.setBool(approvedKey, true);
        }
      }

      // ── 2. Admin rejected ───────────────────────────────────────────────
      final rejectedKey = 'notified_collection_rejected_$id';
      if (!(prefs.getBool(rejectedKey) ?? false)) {
        if (status == 'rejected') {
          final bi = await _bi(
            'Collection Order Rejected',
            'تم رفض طلب التجميع',
            'Your collection request of {liters}L was rejected by the admin.',
            'تم رفض طلب تجميعك ({liters} لتر) من قِبل الإدارة.',
            liters: liters,
          );
          events.add(OrderEvent(title: bi['title']!, body: bi['body']!, isSuccess: false));
          await show(
            id: _stableId('col_rej', id),
            title: bi['title']!,
            body: bi['body']!,
            withReorderAction: true,
            reorderType: 'collection',
          );
          await prefs.setBool(rejectedKey, true);
        }
      }

      // ── 3. Agent accepted ───────────────────────────────────────────────
      final acceptedKey = 'notified_collection_accepted_$id';
      if (!(prefs.getBool(acceptedKey) ?? false)) {
        if (status == 'accepted' || status == 'in_transit' || status == 'completed') {
          final bi = await _bi(
            'Delivery Agent On The Way',
            'عامل التوصيل في الطريق',
            'Your collection order of {liters}L has been accepted by the delivery agent.',
            'قَبِل عامل التوصيل طلب تجميعك ({liters} لتر). هو في الطريق إليك.',
            liters: liters,
          );
          events.add(OrderEvent(title: bi['title']!, body: bi['body']!, isSuccess: true));
          await show(id: _stableId('col_acc', id), title: bi['title']!, body: bi['body']!);
          await prefs.setBool(acceptedKey, true);
        }
      }
    }
    return events;
  }

  // ── Purchase order polling ───────────────────────────────────────────────
  /// Returns the list of [OrderEvent]s that fired this call (for in-app toast display).
  static Future<List<OrderEvent>> checkPurchaseOrders(List<dynamic> orders) async {
    final events = <OrderEvent>[];
    if (!await isEnabled()) return events;
    final prefs = await SharedPreferences.getInstance();

    for (final order in orders) {
      final id     = order['id']?.toString();
      final status = order['status']?.toString() ?? '';
      final liters = order['liters']?.toString() ?? '';
      if (id == null) continue;

      // ── 1. Admin approved ───────────────────────────────────────────────
      final approvedKey = 'notified_purchase_approved_$id';
      if (!(prefs.getBool(approvedKey) ?? false)) {
        if (status == 'assigned') {
          final bi = await _bi(
            'Purchase Order Approved ✓',
            'تمت الموافقة على طلب الشراء ✓',
            'Your purchase order of {liters}L has been approved. A delivery agent has been assigned.',
            'تمت الموافقة على طلب شرائك ({liters} لتر). تم تعيين عامل توصيل.',
            liters: liters,
          );
          events.add(OrderEvent(title: bi['title']!, body: bi['body']!, isSuccess: true));
          await show(id: _stableId('pur_appr', id), title: bi['title']!, body: bi['body']!);
          await prefs.setBool(approvedKey, true);
        }
      }

      // ── 2. Admin rejected ───────────────────────────────────────────────
      final rejectedKey = 'notified_purchase_rejected_$id';
      if (!(prefs.getBool(rejectedKey) ?? false)) {
        if (status == 'rejected' || status == 'expired') {
          final bi = await _bi(
            'Purchase Order Rejected',
            'تم رفض طلب الشراء',
            'Your purchase order of {liters}L was rejected.',
            'تم رفض طلب شرائك ({liters} لتر).',
            liters: liters,
          );
          events.add(OrderEvent(title: bi['title']!, body: bi['body']!, isSuccess: false));
          await show(
            id: _stableId('pur_rej', id),
            title: bi['title']!,
            body: bi['body']!,
            withReorderAction: true,
            reorderType: 'purchase',
          );
          await prefs.setBool(rejectedKey, true);
        }
      }

      // ── 3. Agent accepted ───────────────────────────────────────────────
      final acceptedKey = 'notified_purchase_accepted_$id';
      if (!(prefs.getBool(acceptedKey) ?? false)) {
        if (status == 'accepted' || status == 'in_transit' || status == 'completed') {
          final bi = await _bi(
            'Delivery Agent Accepted Your Order',
            'قَبِل عامل التوصيل طلبك',
            'Your purchase order of {liters}L has been accepted by the delivery agent.',
            'قَبِل عامل التوصيل طلب شرائك ({liters} لتر).',
            liters: liters,
          );
          events.add(OrderEvent(title: bi['title']!, body: bi['body']!, isSuccess: true));
          await show(id: _stableId('pur_acc', id), title: bi['title']!, body: bi['body']!);
          await prefs.setBool(acceptedKey, true);
        }
      }
    }
    return events;
  }

  static int _stableId(String prefix, String orderId) =>
      '$prefix$orderId'.hashCode.abs() % 100000;
}
