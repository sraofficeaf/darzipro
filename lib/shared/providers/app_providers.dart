import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_enums.dart';
import '../models/models.dart';
import 'supabase_providers.dart';
import 'sync_manager.dart';
import 'license_provider.dart';

// ── Theme Provider ─────────────────────────────────────────────────────
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  final box = Hive.box('settings_box');
  final savedTheme = box.get('themeMode', defaultValue: 'light') as String;
  return savedTheme == 'dark' ? ThemeMode.dark : ThemeMode.light;
});

// ── Current Nav Section ────────────────────────────────────────────────
final navSectionProvider = StateProvider<NavSection>((ref) => NavSection.dashboard);

// ── Customers Provider ─────────────────────────────────────────────────
class CustomersNotifier extends StateNotifier<AsyncValue<List<CustomerModel>>> {
  final Ref _ref;
  final bool isCloudEnabled;

  CustomersNotifier(this._ref, {required this.isCloudEnabled}) : super(const AsyncValue.loading()) {
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    final shopId = _ref.watch(currentShopIdProvider);
    if (shopId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    final Box customersBox = Hive.box('customers_box');
    
    // Load from cache first
    dynamic cachedData;
    try {
      cachedData = customersBox.get(shopId);
      if (cachedData != null) {
        final List<dynamic> listJson = List<dynamic>.from(cachedData as List);
        final list = listJson.map((json) => CustomerModel.fromJson(Map<String, dynamic>.from(json as Map), 0)).toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.loading();
      }
    } catch (e) {
      debugPrint('Error loading cached customers: $e');
      state = const AsyncValue.loading();
    }

    if (!isCloudEnabled) {
      if (cachedData == null) {
        state = const AsyncValue.data([]);
      }
      return;
    }

    try {
      final supabase = _ref.read(supabaseClientProvider);
      
      // Parallel batch query: Fetch all customers and all order customer_ids in 2 parallel requests (zero N+1 loops)
      final results = await Future.wait([
        supabase
            .from('customers')
            .select()
            .eq('shop_id', shopId)
            .order('created_at', ascending: false),
        supabase
            .from('orders')
            .select('customer_id')
            .eq('shop_id', shopId),
      ]);

      final List<dynamic> data = results[0] as List<dynamic>;
      final List<dynamic> orderRows = results[1] as List<dynamic>;

      // Build customer order count map in memory
      final Map<String, int> orderCounts = {};
      for (final o in orderRows) {
        final cid = o['customer_id'] as String?;
        if (cid != null) {
          orderCounts[cid] = (orderCounts[cid] ?? 0) + 1;
        }
      }

      final List<CustomerModel> list = [];
      for (final json in data) {
        final count = orderCounts[json['id']] ?? 0;
        list.add(CustomerModel.fromJson(json, count));
      }

      // Save to cache (raw JSON data)
      await customersBox.put(shopId, data);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (cachedData == null) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> _updateLocalCache(List<CustomerModel> newList) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;
    final Box customersBox = Hive.box('customers_box');
    final rawList = newList.map((c) => c.toJson(shopId)).toList();
    await customersBox.put(shopId, rawList);
    state = AsyncValue.data(newList);
  }

  Future<void> refresh() async {
    await _fetchCustomers();
  }

  Future<void> addCustomer(CustomerModel customer) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final newList = [customer, ...currentList];
    
    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      final json = customer.toJson(shopId);
      try {
        await supabase.from('customers').insert(json);
        await _fetchCustomers();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: 'insert',
            table: 'customers',
            payload: json,
          );
        } else {
          await _fetchCustomers();
          rethrow;
        }
      }
    }
  }

  Future<void> updateCustomer(CustomerModel customer) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final newList = [
      for (final c in currentList) if (c.id == customer.id) customer else c
    ];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      final json = customer.toJson(shopId);
      try {
        await supabase.from('customers').update(json).eq('id', customer.id);
        await _fetchCustomers();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: 'update',
            table: 'customers',
            payload: json,
          );
        } else {
          await _fetchCustomers();
          rethrow;
        }
      }
    }
  }

  Future<void> deleteCustomer(String id) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final newList = currentList.where((c) => c.id != id).toList();

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        await supabase.from('customers').delete().eq('id', id);
        await _fetchCustomers();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: 'delete',
            table: 'customers',
            payload: {'id': id},
          );
        } else {
          await _fetchCustomers();
          rethrow;
        }
      }
    }
  }
}

final customersProvider = StateNotifierProvider<CustomersNotifier, AsyncValue<List<CustomerModel>>>((ref) {
  final license = ref.watch(licenseProvider);
  return CustomersNotifier(ref, isCloudEnabled: license.isCloudEnabled);
});

final customerSearchProvider = StateProvider<String>((ref) => '');
final customerGenderFilterProvider = StateProvider<CustomerGender?>((ref) => null);

final filteredCustomersProvider = Provider<AsyncValue<List<CustomerModel>>>((ref) {
  final customersAsync = ref.watch(customersProvider);
  final search = ref.watch(customerSearchProvider).toLowerCase();
  final genderFilter = ref.watch(customerGenderFilterProvider);

  return customersAsync.whenData((customers) {
    return customers.where((c) {
      final matchesSearch = search.isEmpty ||
          c.name.toLowerCase().contains(search) ||
          c.phone.contains(search);
      final matchesGender = genderFilter == null || c.gender == genderFilter;
      return matchesSearch && matchesGender;
    }).toList();
  });
});

// ── Orders Provider ────────────────────────────────────────────────────
class OrdersNotifier extends StateNotifier<AsyncValue<List<OrderModel>>> {
  final Ref _ref;
  final bool isCloudEnabled;

  OrdersNotifier(this._ref, {required this.isCloudEnabled}) : super(const AsyncValue.loading()) {
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final shopId = _ref.watch(currentShopIdProvider);
    if (shopId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    final Box ordersBox = Hive.box('orders_box');

    // Load from cache first
    dynamic cachedData;
    try {
      cachedData = ordersBox.get(shopId);
      if (cachedData != null) {
        final List<dynamic> listJson = List<dynamic>.from(cachedData as List);
        final List<OrderModel> list = listJson.map((json) {
          final map = Map<String, dynamic>.from(json as Map);
          final customerName = map['customers'] != null
              ? map['customers']['name'] as String? ?? 'Unknown'
              : 'Unknown';

          final List<OrderItemModel> items = (map['order_items'] as List<dynamic>?)
                  ?.map((item) => OrderItemModel.fromJson(Map<String, dynamic>.from(item as Map)))
                  .toList() ??
              [];

          final List<PaymentModel> payments = (map['payments'] as List<dynamic>?)
                  ?.map((pay) => PaymentModel.fromJson(Map<String, dynamic>.from(pay as Map)))
                  .toList() ??
              [];

          final List<String> images = (map['order_images'] as List<dynamic>?)
                  ?.map((img) => img['storage_path'] as String)
                  .toList() ??
              [];

          return OrderModel.fromJson(map, customerName, items, payments, images);
        }).toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.loading();
      }
    } catch (e) {
      debugPrint('Error loading cached orders: $e');
      state = const AsyncValue.loading();
    }

    if (!isCloudEnabled) {
      if (cachedData == null) {
        state = const AsyncValue.data([]);
      }
      return;
    }

    try {
      final supabase = _ref.read(supabaseClientProvider);
      final List<dynamic> data = await supabase
          .from('orders')
          .select('*, customers(name), order_items(*), payments(*), order_images(*)')
          .eq('shop_id', shopId)
          .order('created_at', ascending: false);

      final List<OrderModel> list = data.map((json) {
        final customerName = json['customers'] != null
            ? json['customers']['name'] as String? ?? 'Unknown'
            : 'Unknown';

        final List<OrderItemModel> items = (json['order_items'] as List<dynamic>?)
                ?.map((item) => OrderItemModel.fromJson(item as Map<String, dynamic>))
                .toList() ??
            [];

        final List<PaymentModel> payments = (json['payments'] as List<dynamic>?)
                ?.map((pay) => PaymentModel.fromJson(pay as Map<String, dynamic>))
                .toList() ??
            [];

        final List<String> images = (json['order_images'] as List<dynamic>?)
                ?.map((img) => img['storage_path'] as String)
                .toList() ??
            [];

        return OrderModel.fromJson(json, customerName, items, payments, images);
      }).toList();

      // Save to cache
      await ordersBox.put(shopId, data);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (cachedData == null) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> _updateLocalCache(List<OrderModel> newList) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;
    final Box ordersBox = Hive.box('orders_box');
    
    final rawList = newList.map((order) {
      final userId = _ref.read(currentUserIdProvider);
      final orderJson = order.toJson(shopId, userId);
      
      orderJson['customers'] = {'name': order.customerName};
      orderJson['order_items'] = order.items.map((item) => item.toJson(order.id)).toList();
      orderJson['payments'] = order.payments.map((p) => p.toJson(shopId, order.id, userId)).toList();
      orderJson['order_images'] = order.images.map((img) => {'storage_path': img}).toList();
      
      return orderJson;
    }).toList();
    
    await ordersBox.put(shopId, rawList);
    state = AsyncValue.data(newList);
  }

  Future<void> refresh() async {
    await _fetchOrders();
  }

  Future<void> addOrder(OrderModel order) async {
    final shopId = _ref.read(currentShopIdProvider);
    final userId = _ref.read(currentUserIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final newList = [order, ...currentList];
    
    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        final orderJson = order.toJson(shopId, userId);
        final orderResult = await supabase
            .from('orders')
            .insert(orderJson)
            .select()
            .single();

        final generatedOrderId = orderResult['id'] as String;

        for (final item in order.items) {
          await supabase.from('order_items').insert(item.toJson(generatedOrderId));
        }

        for (final payment in order.payments) {
          await supabase.from('payments').insert(payment.toJson(shopId, generatedOrderId, userId));
        }

        for (final imagePath in order.images) {
          await supabase.from('order_images').insert({
            'shop_id': shopId,
            'order_id': generatedOrderId,
            'storage_path': imagePath,
          });
        }

        await _fetchOrders();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          final sync = _ref.read(syncManagerProvider.notifier);
          
          final orderJson = order.toJson(shopId, userId);
          await sync.queueOperation(
            type: 'insert',
            table: 'orders',
            payload: orderJson,
          );

          for (final item in order.items) {
            await sync.queueOperation(
              type: 'insert',
              table: 'order_items',
              payload: item.toJson(order.id),
            );
          }

          for (final payment in order.payments) {
            await sync.queueOperation(
              type: 'insert',
              table: 'payments',
              payload: payment.toJson(shopId, order.id, userId),
            );
          }

          for (final imagePath in order.images) {
            await sync.queueOperation(
              type: 'insert',
              table: 'order_images',
              payload: {
                'shop_id': shopId,
                'order_id': order.id,
                'storage_path': imagePath,
              },
            );
          }
        } else {
          await _fetchOrders();
          rethrow;
        }
      }
    }
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) async {
    final currentList = state.value ?? [];
    final newList = [
      for (final order in currentList)
        if (order.id == orderId) order.copyWith(status: status) else order
    ];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        await supabase.from('orders').update({'status': status.name}).eq('id', orderId);
        await _fetchOrders();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: 'update',
            table: 'orders',
            payload: {'id': orderId, 'status': status.name},
          );
        } else {
          await _fetchOrders();
          rethrow;
        }
      }
    }
  }

  Future<void> updateDeliveryDate(String orderId, DateTime date, String? notes) async {
    final currentList = state.value ?? [];
    final newList = [
      for (final order in currentList)
        if (order.id == orderId) order.copyWith(deliveryDate: date, notes: notes) else order
    ];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        await supabase.from('orders').update({
          'delivery_date': date.toIso8601String(),
          'notes': notes,
        }).eq('id', orderId);
        await _fetchOrders();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: 'update',
            table: 'orders',
            payload: {
              'id': orderId,
              'delivery_date': date.toIso8601String(),
              'notes': notes,
            },
          );
        } else {
          await _fetchOrders();
          rethrow;
        }
      }
    }
  }

  Future<void> addPayment(String orderId, PaymentModel payment) async {
    final shopId = _ref.read(currentShopIdProvider);
    final userId = _ref.read(currentUserIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final newList = [
      for (final order in currentList)
        if (order.id == orderId)
          order.copyWith(payments: [...order.payments, payment])
        else
          order
    ];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        await supabase.from('payments').insert(payment.toJson(shopId, orderId, userId));
        await _fetchOrders();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: 'insert',
            table: 'payments',
            payload: payment.toJson(shopId, orderId, userId),
          );
        } else {
          await _fetchOrders();
          rethrow;
        }
      }
    }
  }

  Future<void> addOrderImage(String orderId, String storagePath) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final newList = [
      for (final order in currentList)
        if (order.id == orderId)
          order.copyWith(images: [...order.images, storagePath])
        else
          order
    ];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        await supabase.from('order_images').insert({
          'shop_id': shopId,
          'order_id': orderId,
          'storage_path': storagePath,
        });
        await _fetchOrders();
      } catch (e) {
        rethrow;
      }
    }
  }

  Future<void> deleteOrderImage(String orderId, String storagePath) async {
    final currentList = state.value ?? [];
    final newList = [
      for (final order in currentList)
        if (order.id == orderId)
          order.copyWith(images: order.images.where((img) => img != storagePath).toList())
        else
          order
    ];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      try {
        await supabase.from('order_images').delete().eq('order_id', orderId).eq('storage_path', storagePath);
        try {
          await supabase.storage.from('design-images').remove([storagePath]);
        } catch (_) {}
        await _fetchOrders();
      } catch (e) {
        rethrow;
      }
    }
  }
}

final ordersProvider = StateNotifierProvider<OrdersNotifier, AsyncValue<List<OrderModel>>>((ref) {
  final license = ref.watch(licenseProvider);
  return OrdersNotifier(ref, isCloudEnabled: license.isCloudEnabled);
});

final orderStatusFilterProvider = StateProvider<OrderStatus?>((ref) => null);

final filteredOrdersProvider = Provider<AsyncValue<List<OrderModel>>>((ref) {
  final ordersAsync = ref.watch(ordersProvider);
  final statusFilter = ref.watch(orderStatusFilterProvider);

  return ordersAsync.whenData((orders) {
    if (statusFilter == null) return orders;
    return orders.where((o) => o.status == statusFilter).toList();
  });
});

// ── Selected Customer ──────────────────────────────────────────────────
final selectedCustomerIdProvider = StateProvider<String?>((ref) => null);

final selectedCustomerProvider = Provider<CustomerModel?>((ref) {
  final id = ref.watch(selectedCustomerIdProvider);
  if (id == null) return null;
  final customersAsync = ref.watch(customersProvider);
  return customersAsync.when(
    data: (list) {
      try {
        return list.firstWhere((c) => c.id == id);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// ── Selected Order ─────────────────────────────────────────────────────
final selectedOrderIdProvider = StateProvider<String?>((ref) => null);

final selectedOrderProvider = Provider<OrderModel?>((ref) {
  final id = ref.watch(selectedOrderIdProvider);
  if (id == null) return null;
  final ordersAsync = ref.watch(ordersProvider);
  return ordersAsync.when(
    data: (orders) {
      try {
        return orders.firstWhere((o) => o.id == id);
      } catch (_) {
        return null;
      }
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

// ── Dashboard Stats ────────────────────────────────────────────────────
final dashboardStatsProvider = Provider<AsyncValue<DashboardStats>>((ref) {
  final ordersAsync = ref.watch(ordersProvider);

  return ordersAsync.whenData((orders) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    double dailyRevenue = 0;
    for (final order in orders) {
      for (final payment in order.payments) {
        if (payment.paidAt.isAfter(startOfToday) || payment.paidAt.isAtSameMomentAs(startOfToday)) {
          dailyRevenue += payment.amount;
        }
      }
    }

    final startOfMonth = DateTime(now.year, now.month, 1);
    double monthlyRevenue = 0;
    for (final order in orders) {
      for (final payment in order.payments) {
        if (payment.paidAt.isAfter(startOfMonth) || payment.paidAt.isAtSameMomentAs(startOfMonth)) {
          monthlyRevenue += payment.amount;
        }
      }
    }

    int totalOrders = orders.length;
    int pendingOrders = orders.where((o) => o.status == OrderStatus.pending).length;
    int readyOrders = orders.where((o) => o.status == OrderStatus.ready).length;
    int urgentOrders = orders.where((o) => o.isUrgent).length;

    // Real weekly revenue calculation for past 7 days (in thousands k)
    final List<double> weeklyRevenue = [];
    final List<String> weekLabels = [];
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    for (int i = 6; i >= 0; i--) {
      final dayStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      double dayTotal = 0;
      for (final order in orders) {
        for (final payment in order.payments) {
          if ((payment.paidAt.isAfter(dayStart) || payment.paidAt.isAtSameMomentAs(dayStart)) &&
              payment.paidAt.isBefore(dayEnd)) {
            dayTotal += payment.amount;
          }
        }
      }
      weeklyRevenue.add(dayTotal / 1000.0);
      weekLabels.add(dayNames[dayStart.weekday - 1]);
    }

    return DashboardStats(
      dailyRevenue: dailyRevenue,
      monthlyRevenue: monthlyRevenue,
      totalOrders: totalOrders,
      pendingOrders: pendingOrders,
      readyOrders: readyOrders,
      urgentOrders: urgentOrders,
      weeklyRevenue: weeklyRevenue,
      weekLabels: weekLabels,
    );
  });
});

// ── Measurements Provider ──────────────────────────────────────────────
class MeasurementsNotifier extends StateNotifier<AsyncValue<List<MeasurementModel>>> {
  final Ref _ref;
  final bool isCloudEnabled;

  MeasurementsNotifier(this._ref, {required this.isCloudEnabled}) : super(const AsyncValue.loading()) {
    _fetchMeasurements();
  }

  Future<void> _fetchMeasurements() async {
    final shopId = _ref.watch(currentShopIdProvider);
    if (shopId == null) {
      state = const AsyncValue.data([]);
      return;
    }

    final Box measurementsBox = Hive.box('measurements_box');

    // Load from cache first
    dynamic cachedData;
    try {
      cachedData = measurementsBox.get(shopId);
      if (cachedData != null) {
        final List<dynamic> listJson = List<dynamic>.from(cachedData as List);
        final list = listJson.map((json) => MeasurementModel.fromJson(Map<String, dynamic>.from(json as Map))).toList();
        state = AsyncValue.data(list);
      } else {
        state = const AsyncValue.loading();
      }
    } catch (e) {
      debugPrint('Error loading cached measurements: $e');
      state = const AsyncValue.loading();
    }

    if (!isCloudEnabled) {
      if (cachedData == null) {
        state = const AsyncValue.data([]);
      }
      return;
    }

    try {
      final supabase = _ref.read(supabaseClientProvider);
      final List<dynamic> data = await supabase
          .from('measurements')
          .select()
          .eq('shop_id', shopId);

      final list = data.map((json) => MeasurementModel.fromJson(json)).toList();
      
      // Save to cache
      await measurementsBox.put(shopId, data);
      state = AsyncValue.data(list);
    } catch (e, stack) {
      if (cachedData == null) {
        state = AsyncValue.error(e, stack);
      }
    }
  }

  Future<void> _updateLocalCache(List<MeasurementModel> newList) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;
    final Box measurementsBox = Hive.box('measurements_box');
    final rawList = newList.map((m) => m.toJson(shopId)).toList();
    await measurementsBox.put(shopId, rawList);
    state = AsyncValue.data(newList);
  }

  Future<void> addOrUpdateMeasurement(MeasurementModel measurement) async {
    final shopId = _ref.read(currentShopIdProvider);
    if (shopId == null) return;

    final currentList = state.value ?? [];
    final exists = currentList.any((m) => m.id == measurement.id);
    final newList = exists
        ? [for (final m in currentList) if (m.id == measurement.id) measurement else m]
        : [measurement, ...currentList];

    await _updateLocalCache(newList);

    if (isCloudEnabled) {
      final supabase = _ref.read(supabaseClientProvider);
      final json = measurement.toJson(shopId);
      try {
        await supabase.from('measurements').upsert(json);
        await _fetchMeasurements();
      } catch (e) {
        final errStr = e.toString().toLowerCase();
        final isNetwork = e is PostgrestException && (e.message.contains('Failed host lookup') || e.message.contains('network')) ||
            errStr.contains('socketexception') || errStr.contains('network') || errStr.contains('failed to connect') || errStr.contains('handshake_failed');

        if (isNetwork) {
          await _ref.read(syncManagerProvider.notifier).queueOperation(
            type: exists ? 'update' : 'insert',
            table: 'measurements',
            payload: json,
          );
        } else {
          await _fetchMeasurements();
          rethrow;
        }
      }
    }
  }
}

final measurementsProvider = StateNotifierProvider<MeasurementsNotifier, AsyncValue<List<MeasurementModel>>>((ref) {
  final license = ref.watch(licenseProvider);
  return MeasurementsNotifier(ref, isCloudEnabled: license.isCloudEnabled);
});

final selectedMeasurementCustomerIdProvider = StateProvider<String?>((ref) => null);

final customerMeasurementsProvider = Provider<AsyncValue<List<MeasurementModel>>>((ref) {
  final customerId = ref.watch(selectedMeasurementCustomerIdProvider);
  final measurementsAsync = ref.watch(measurementsProvider);

  if (customerId == null) {
    return const AsyncValue.data([]);
  }

  return measurementsAsync.whenData((list) {
    return list.where((m) => m.customerId == customerId).toList();
  });
});

// ── Report Period ──────────────────────────────────────────────────────
final reportPeriodProvider = StateProvider<ReportPeriod>((ref) => ReportPeriod.thisMonth);

final _defaultMeasurementTemplates = [
  {
    'id': 'temp_men_shalwar_kameez',
    'shop_id': 'default',
    'name': 'Shalwar Kameez (Men)',
    'category': 'men',
    'fields': ['lambai', 'teerwa', 'bazo', 'chhaati', 'baghal', 'kamar', 'daman', 'collar', 'shalwar', 'panche'],
    'created_at': '2026-06-22T00:00:00.000Z',
  },
  {
    'id': 'temp_women_kurti',
    'shop_id': 'default',
    'name': 'Kurti / Suit (Women)',
    'category': 'women',
    'fields': ['lambai', 'teerwa', 'bazo', 'chhaati', 'kamar', 'hip', 'daman', 'gala', 'shalwar', 'panche'],
    'created_at': '2026-06-22T00:00:00.000Z',
  },
];

// ── Measurement Templates Provider ──────────────────────────────────────
final measurementTemplatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final shopId = ref.watch(currentShopIdProvider);
  if (shopId == null) return [];

  final license = ref.watch(licenseProvider);
  final Box settingsBox = Hive.box('settings_box');
  final cachedData = settingsBox.get('templates_$shopId');

  if (!license.isCloudEnabled) {
    if (cachedData != null) {
      return List<Map<String, dynamic>>.from(cachedData as List);
    }
    return _defaultMeasurementTemplates;
  }

  try {
    final supabase = ref.read(supabaseClientProvider);
    final List<dynamic> data = await supabase
        .from('measurement_templates')
        .select()
        .eq('shop_id', shopId);
    
    final list = List<Map<String, dynamic>>.from(data);
    await settingsBox.put('templates_$shopId', list);
    return list;
  } catch (e) {
    if (cachedData != null) {
      return List<Map<String, dynamic>>.from(cachedData as List);
    }
    return _defaultMeasurementTemplates;
  }
});

// ── Language / Locale Provider ─────────────────────────────────────────
class LocaleNotifier extends StateNotifier<String> {
  LocaleNotifier() : super('en') {
    final saved = Hive.box('settings_box').get('language', defaultValue: 'en') as String;
    state = saved;
  }

  void setLanguage(String lang) {
    Hive.box('settings_box').put('language', lang);
    state = lang;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, String>((ref) {
  return LocaleNotifier();
});

