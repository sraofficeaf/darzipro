import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import 'app_providers.dart';
import '../../core/constants/app_enums.dart';
import '../../core/widgets/shared_widgets.dart';

class ReminderModel {
  final String id;
  final String orderId;
  final String customerName;
  final String tokenNumber;
  final String message;
  final String type; // 'due', 'delayed', 'custom'
  final bool isRead;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.tokenNumber,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.createdAt,
  });

  ReminderModel copyWith({
    String? id,
    String? orderId,
    String? customerName,
    String? tokenNumber,
    String? message,
    String? type,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      customerName: customerName ?? this.customerName,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class RemindersNotifier extends StateNotifier<List<ReminderModel>> {
  RemindersNotifier() : super([]);

  void updateReminders(List<OrderModel> orders) {
    final List<ReminderModel> list = [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final order in orders) {
      if (order.status == OrderStatus.delivered || order.status == OrderStatus.cancelled) {
        continue;
      }

      // Ready for pickup (teal icon ✅, title "Ready: [CustomerName]", sub "Order T-XXXX")
      if (order.status == OrderStatus.ready) {
        list.add(ReminderModel(
          id: 'rem_ready_${order.id}',
          orderId: order.id,
          customerName: order.customerName,
          tokenNumber: order.tokenNumber,
          message: 'Order ${order.tokenNumber}',
          type: 'ready',
          createdAt: DateTime.now(),
        ));
        continue;
      }

      // Overdue or Today delivery
      if (order.deliveryDate != null) {
        final deliveryDate = DateTime(order.deliveryDate!.year, order.deliveryDate!.month, order.deliveryDate!.day);
        if (deliveryDate.isBefore(today)) {
          // Overdue delivery (red icon 🚨, title "Overdue: [CustomerName]", sub "Was due [date]")
          list.add(ReminderModel(
            id: 'rem_overdue_${order.id}',
            orderId: order.id,
            customerName: order.customerName,
            tokenNumber: order.tokenNumber,
            message: 'Was due ${formatDateShort(order.deliveryDate!)}',
            type: 'overdue',
            createdAt: DateTime.now(),
          ));
        } else if (deliveryDate.isAtSameMomentAs(today)) {
          // Delivery today (gold icon ⏰, title "Due Today: [CustomerName]")
          list.add(ReminderModel(
            id: 'rem_today_${order.id}',
            orderId: order.id,
            customerName: order.customerName,
            tokenNumber: order.tokenNumber,
            message: 'Due today',
            type: 'today',
            createdAt: DateTime.now(),
          ));
        }
      }
    }

    // Retain read status for existing reminders
    final Map<String, bool> readStatuses = {for (final r in state) r.id: r.isRead};
    state = list.map((r) {
      if (readStatuses.containsKey(r.id)) {
        return r.copyWith(isRead: readStatuses[r.id]);
      }
      return r;
    }).toList();
  }

  void markAsRead(String id) {
    state = [
      for (final r in state)
        if (r.id == id) r.copyWith(isRead: true) else r
    ];
  }

  void removeReminder(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void clearAll() {
    state = [];
  }
}

final remindersProvider = StateNotifierProvider<RemindersNotifier, List<ReminderModel>>((ref) {
  final notifier = RemindersNotifier();
  ref.listen<AsyncValue<List<OrderModel>>>(ordersProvider, (previous, next) {
    next.whenData((orders) {
      notifier.updateReminders(orders);
    });
  }, fireImmediately: true);
  return notifier;
});

