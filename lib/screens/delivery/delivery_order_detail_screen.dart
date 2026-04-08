import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../services/app_localizations.dart';
import '../../services/notification_service.dart';

class DeliveryOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final String orderType; // 'collection' or 'purchase'

  const DeliveryOrderDetailScreen({
    super.key,
    required this.order,
    required this.orderType,
  });

  @override
  State<DeliveryOrderDetailScreen> createState() =>
      _DeliveryOrderDetailScreenState();
}

class _DeliveryOrderDetailScreenState
    extends State<DeliveryOrderDetailScreen> {
  bool _actionLoading = false;
  String? _error;
  late Map<String, dynamic> _order;

  @override
  void initState() {
    super.initState();
    _order = Map<String, dynamic>.from(widget.order);
  }

  bool get _isCollection => widget.orderType == 'collection';
  String get _endpoint =>
      _isCollection ? '/collection-orders' : '/purchase-orders';

  Future<void> _performAction(String action) async {
    setState(() {
      _actionLoading = true;
      _error = null;
    });

    final result =
        await ApiService.patch('$_endpoint/${_order['id']}/$action', {});

    if (!mounted) return;
    setState(() => _actionLoading = false);

    if (result['success'] == true) {
      final newStatus = _statusFor(action);
      setState(() => _order['status'] = newStatus);

      final l = AppLocalizations.of(context);
      final msg = switch (action) {
        'accept' => l.get('toast_task_accepted'),
        'reject' => l.get('toast_task_rejected'),
        'start' => _isCollection ? l.get('toast_pickup_started') : l.get('toast_delivery_started'),
        'complete' => l.get('toast_task_completed'),
        _ => l.get('toast_done'),
      };

      // Fire outside-app notification
      final notifTitle = switch (action) {
        'accept' => l.get('notif_task_accepted'),
        'reject' => l.get('notif_task_rejected'),
        'start'  => _isCollection ? l.get('notif_pickup_started') : l.get('notif_delivery_started'),
        'complete' => l.get('notif_task_completed'),
        _ => l.get('notif_oiltrade'),
      };
      NotificationService.show(
        id: _order['id'] ?? 0,
        title: notifTitle,
        body: '${_isCollection ? l.get('notif_collection_label') : l.get('notif_purchase_label')} #${_order['id']} — $msg',
      );

      final color = action == 'reject' ? Colors.redAccent : const Color(0xFF3FB950);
      final icon  = action == 'reject' ? Icons.cancel_outlined : Icons.check_circle_outline;
      showDialog(
        context: context,
        barrierColor: Colors.black26,
        barrierDismissible: false,
        builder: (ctx) {
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (ctx.mounted) Navigator.of(ctx).pop();
          });
          return Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20, offset: const Offset(0, 6))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      msg,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (action == 'reject' || action == 'complete') {
        Future.delayed(
          const Duration(milliseconds: 800),
          () { if (mounted) Navigator.pop(context); },
        );
      }
    } else {
      setState(() => _error = result['message'] ?? 'Action failed');
    }
  }

  String _statusFor(String action) => switch (action) {
        'accept' => 'accepted',
        'reject' => 'rejected',
        'start' => 'in_transit',
        'complete' => 'completed',
        _ => _order['status'] ?? 'pending',
      };

  Future<void> _confirmReject() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
        backgroundColor: cs.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(ctx).get('reject_task')),
        content: Text(
          AppLocalizations.of(ctx).get('reject_task_confirm'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(AppLocalizations.of(ctx).get('reject'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
      },
    );
    if (ok == true) _performAction('reject');
  }

  Future<void> _confirmComplete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
        backgroundColor: cs.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(AppLocalizations.of(ctx).get('confirm_delivery')),
        content: Text(
          AppLocalizations.of(ctx).get('confirm_delivery_body'),
          style: TextStyle(color: cs.onSurface.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx).get('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3FB950)),
            child: Text(AppLocalizations.of(ctx).get('confirm'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      );
      },
    );
    if (ok == true) _performAction('complete');
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = _order['status'] as String? ?? 'pending';
    final contact =
        _isCollection ? _order['seller'] : _order['buyer'];
    final contactLabel = _isCollection ? l.get('seller') : l.get('buyer');

    // Location data (the address of the other party)
    final pickupAddress = _isCollection
        ? (_order['address'] as String? ?? l.get('not_specified'))
        : l.get('central_depot_pickup');
    final deliveryAddress = _isCollection
        ? l.get('central_depot_dropoff')
        : (_order['address'] as String? ?? l.get('not_specified'));

    final lat = (_order['latitude'] as num?)?.toDouble();
    final lng = (_order['longitude'] as num?)?.toDouble();
    final hasCoords = lat != null && lng != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isCollection
            ? 'Collection #${_order['id']}'
            : 'Purchase #${_order['id']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Status banner ────────────────────────────────────────────
            _StatusBanner(
              status: status,
              isCollection: _isCollection,
              liters: _order['liters'],
            ),
            const SizedBox(height: 14),

            // ── Pickup Location (collection only) ───────────────────────
            if (_isCollection) ...[
              _LocationCard(
                title: l.get('pickup_location'),
                address: pickupAddress,
                lat: lat,
                lng: lng,
                hasCoords: hasCoords,
                onOpenMaps: () => _openMaps(lat!, lng!),
              ),
              const SizedBox(height: 10),
            ],

            // ── Delivery Location ────────────────────────────────────────
            _LocationCard(
              title: l.get('delivery_location'),
              address: deliveryAddress,
              lat: _isCollection ? null : lat,
              lng: _isCollection ? null : lng,
              hasCoords: !_isCollection && hasCoords,
              onOpenMaps: () => _openMaps(lat!, lng!),
            ),
            const SizedBox(height: 10),

            // ── Contact Info ─────────────────────────────────────────────
            if (contact != null)
              _ContactCard(contact: contact, label: contactLabel),
            const SizedBox(height: 10),

            // ── Schedule ─────────────────────────────────────────────────
            _ScheduleCard(order: _order, isCollection: _isCollection),
            const SizedBox(height: 16),

            // ── Error ────────────────────────────────────────────────────
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Text(_error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13)),
              ),

            // ── Action Buttons ───────────────────────────────────────────
            _buildActions(status),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(String status) {
    if (_actionLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: Color(0xFF58A6FF)),
        ),
      );
    }

    switch (status) {
      case 'assigned':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _confirmReject,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.close, size: 18),
                label: Text(AppLocalizations.of(context).get('reject')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () => _performAction('accept'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58A6FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.check, size: 18),
                label: Text(AppLocalizations.of(context).get('accept_task'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );

      case 'accepted':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _performAction('start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFAB7AE0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(
              _isCollection
                  ? AppLocalizations.of(context).get('started_pickup')
                  : AppLocalizations.of(context).get('started_delivery'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );

      case 'in_transit':
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _confirmComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3FB950),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(AppLocalizations.of(context).get('delivery_completed'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );

      case 'completed':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF3FB950).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: const Color(0xFF3FB950).withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF3FB950), size: 22),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).get('task_completed'),
                style: const TextStyle(
                  color: Color(0xFF3FB950),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  final String status;
  final bool isCollection;
  final dynamic liters;

  const _StatusBanner(
      {required this.status,
      required this.isCollection,
      required this.liters});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final Color color;
    final String label;
    switch (status) {
      case 'assigned':
        color = const Color(0xFFF0A500);
        label = l.get('assigned');
      case 'accepted':
        color = const Color(0xFF58A6FF);
        label = l.get('accepted');
      case 'in_transit':
        color = const Color(0xFFAB7AE0);
        label = l.get('in_transit');
      case 'completed':
        color = const Color(0xFF3FB950);
        label = l.get('completed');
      case 'rejected':
        color = Colors.redAccent;
        label = l.get('rejected');
      default:
        color = const Color(0xFF8B949E);
        label = l.statusLabel(status);
    }

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCollection
                  ? Icons.water_drop_outlined
                  : Icons.local_shipping_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCollection
                      ? AppLocalizations.of(context).get('collection_task')
                      : AppLocalizations.of(context).get('purchase_task'),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  '$liters L',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.54), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(
              label,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LocationCard extends StatelessWidget {
  final String title;
  final String address;
  final double? lat;
  final double? lng;
  final bool hasCoords;
  final VoidCallback onOpenMaps;

  const _LocationCard({
    required this.title,
    required this.address,
    required this.lat,
    required this.lng,
    required this.hasCoords,
    required this.onOpenMaps,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF58A6FF).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.location_on_outlined,
                color: Color(0xFF58A6FF), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.38),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(address,
                    style: TextStyle(
                        color: cs.onSurface, fontSize: 13)),
              ],
            ),
          ),
          if (hasCoords)
            GestureDetector(
              onTap: onOpenMaps,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF58A6FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          const Color(0xFF58A6FF).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined,
                        size: 14, color: Color(0xFF58A6FF)),
                    const SizedBox(width: 4),
                    Text(AppLocalizations.of(context).get('map'),
                        style: const TextStyle(
                            color: Color(0xFF58A6FF),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final dynamic contact;
  final String label;

  const _ContactCard({required this.contact, required this.label});

  @override
  Widget build(BuildContext context) {
    final name = contact['name'] as String? ?? '—';
    final phone = contact['phone'] as String? ?? contact['phone_number'] as String? ?? '—';
    final wilaya = contact['wilaya'] as String? ?? '—';
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label ${AppLocalizations.of(context).get('information')}',
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 15, color: cs.onSurface.withValues(alpha: 0.54)),
              const SizedBox(width: 8),
              Text(name,
                  style: TextStyle(
                      color: cs.onSurface, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.phone_outlined,
                  size: 15, color: cs.onSurface.withValues(alpha: 0.54)),
              const SizedBox(width: 8),
              Text(phone,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.location_city_outlined,
                  size: 15, color: cs.onSurface.withValues(alpha: 0.54)),
              const SizedBox(width: 8),
              Text(wilaya,
                  style: TextStyle(
                      color: cs.onSurface.withValues(alpha: 0.7), fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ScheduleCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final bool isCollection;

  const _ScheduleCard(
      {required this.order, required this.isCollection});

  @override
  Widget build(BuildContext context) {
    final date = isCollection
        ? order['pickup_date']
        : order['delivery_date'];
    final time = isCollection
        ? order['pickup_time']
        : order['delivery_time'];
    final notes = order['notes'] as String?;
    final totalPrice = order['total_price'];

    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).get('schedule_details'),
            style: TextStyle(
                color: cs.onSurface.withValues(alpha: 0.38),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          _Row(
              icon: Icons.calendar_today_outlined,
              label: AppLocalizations.of(context).get('date_label'),
              value: date?.toString() ?? '—'),
          if (time != null)
            _Row(
                icon: Icons.schedule,
                label: AppLocalizations.of(context).get('time_label'),
                value: time.toString()),
          _Row(
              icon: Icons.water_drop_outlined,
              label: AppLocalizations.of(context).get('volume_label'),
              value: '${order['liters']} ${AppLocalizations.of(context).get('liter_unit')}'),
          if (totalPrice != null)
            _Row(
                icon: Icons.payments_outlined,
                label: AppLocalizations.of(context).get('total_label'),
                value: '$totalPrice DZD'),
          if (notes != null && notes.isNotEmpty)
            _Row(
                icon: Icons.notes_outlined,
                label: AppLocalizations.of(context).get('notes_label'),
                value: notes),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Row(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: cs.onSurface.withValues(alpha: 0.38)),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(label,
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.38), fontSize: 12)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: cs.onSurface, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
