import '../../core/constants/app_enums.dart';

class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final CustomerGender gender;
  final String? notes;
  final DateTime createdAt;
  final int totalOrders;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.gender,
    this.notes,
    required this.createdAt,
    this.totalOrders = 0,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    CustomerGender? gender,
    String? notes,
    DateTime? createdAt,
    int? totalOrders,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      gender: gender ?? this.gender,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      totalOrders: totalOrders ?? this.totalOrders,
    );
  }

  factory CustomerModel.fromJson(Map<String, dynamic> json, [int totalOrders = 0]) {
    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      gender: CustomerGender.values.firstWhere(
        (g) => g.name == json['gender'],
        orElse: () => CustomerGender.male,
      ),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      totalOrders: totalOrders,
    );
  }

  Map<String, dynamic> toJson(String shopId) {
    return {
      'id': id,
      'shop_id': shopId,
      'name': name,
      'phone': phone,
      'address': address,
      'gender': gender.name,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class OrderItemModel {
  final String id;
  final String dressType;
  final int quantity;
  final String clothDetails;
  final String? designDetails;
  final double unitPrice;
  final String? notes;

  const OrderItemModel({
    required this.id,
    required this.dressType,
    required this.quantity,
    required this.clothDetails,
    this.designDetails,
    required this.unitPrice,
    this.notes,
  });

  double get total => unitPrice * quantity;

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      dressType: json['dress_type'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      clothDetails: json['cloth_details'] as String? ?? '',
      designDetails: json['design_details'] as String?,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson(String orderId) {
    return {
      'id': id,
      'order_id': orderId,
      'dress_type': dressType,
      'quantity': quantity,
      'cloth_details': clothDetails,
      'design_details': designDetails,
      'unit_price': unitPrice,
      'notes': notes,
    };
  }
}

class PaymentModel {
  final String id;
  final double amount;
  final PaymentMethod method;
  final DateTime paidAt;
  final String? note;

  const PaymentModel({
    required this.id,
    required this.amount,
    required this.method,
    required this.paidAt,
    this.note,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      method: PaymentMethod.values.firstWhere(
        (m) => m.name == json['method'],
        orElse: () => PaymentMethod.cash,
      ),
      paidAt: DateTime.parse(json['paid_at'] as String),
      note: json['note'] as String?,
    );
  }

  Map<String, dynamic> toJson(String shopId, String orderId, String? userId) {
    return {
      'id': id,
      'shop_id': shopId,
      'order_id': orderId,
      'amount': amount,
      'method': method.name,
      'paid_at': paidAt.toIso8601String(),
      'note': note,
      'created_by': userId,
    };
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String customerName;
  final String tokenNumber;
  final int orderNumber;
  final DateTime orderDate;
  final DateTime? deliveryDate;
  final OrderStatus status;
  final double totalAmount;
  final double discount;
  final List<OrderItemModel> items;
  final List<PaymentModel> payments;
  final String? notes;
  final List<String> images;

  const OrderModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.tokenNumber,
    required this.orderNumber,
    required this.orderDate,
    this.deliveryDate,
    required this.status,
    required this.totalAmount,
    this.discount = 0,
    required this.items,
    required this.payments,
    this.notes,
    this.images = const [],
  });

  OrderModel copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? tokenNumber,
    int? orderNumber,
    DateTime? orderDate,
    DateTime? deliveryDate,
    OrderStatus? status,
    double? totalAmount,
    double? discount,
    List<OrderItemModel>? items,
    List<PaymentModel>? payments,
    String? notes,
    List<String>? images,
  }) {
    return OrderModel(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      tokenNumber: tokenNumber ?? this.tokenNumber,
      orderNumber: orderNumber ?? this.orderNumber,
      orderDate: orderDate ?? this.orderDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      totalAmount: totalAmount ?? this.totalAmount,
      discount: discount ?? this.discount,
      items: items ?? this.items,
      payments: payments ?? this.payments,
      notes: notes ?? this.notes,
      images: images ?? this.images,
    );
  }

  double get paidAmount =>
      payments.fold(0.0, (sum, p) => sum + p.amount);

  double get remainingAmount => totalAmount - discount - paidAmount;

  bool get isFullyPaid => remainingAmount <= 0;

  bool get isUrgent {
    if (deliveryDate == null) return false;
    final now = DateTime.now();
    final diff = deliveryDate!.difference(now).inDays;
    return diff <= 1 &&
        status != OrderStatus.delivered &&
        status != OrderStatus.cancelled;
  }

  String get itemsSummary {
    if (items.isEmpty) return '';
    return items.map((i) => '${i.dressType} × ${i.quantity}').join(' · ');
  }

  factory OrderModel.fromJson(
    Map<String, dynamic> json,
    String customerName,
    List<OrderItemModel> items,
    List<PaymentModel> payments,
    List<String> images,
  ) {
    return OrderModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      customerName: customerName,
      tokenNumber: json['token_number'] as String? ?? '',
      orderNumber: json['order_number'] as int? ?? 0,
      orderDate: DateTime.parse(json['order_date'] as String),
      deliveryDate: json['delivery_date'] != null
          ? DateTime.parse(json['delivery_date'] as String)
          : null,
      status: OrderStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => OrderStatus.pending,
      ),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      items: items,
      payments: payments,
      notes: json['notes'] as String?,
      images: images,
    );
  }

  Map<String, dynamic> toJson(String shopId, String? userId) {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      if (orderNumber > 0) 'order_number': orderNumber,
      if (tokenNumber.isNotEmpty) 'token_number': tokenNumber,
      'order_date': orderDate.toIso8601String().substring(0, 10),
      if (deliveryDate != null)
        'delivery_date': deliveryDate!.toIso8601String().substring(0, 10),
      'status': status.name,
      'total_amount': totalAmount,
      'discount': discount,
      'notes': notes,
      'created_by': userId,
    };
  }
}

class MeasurementFieldModel {
  final String key;
  final String label;
  final String unit;
  final String value;

  const MeasurementFieldModel({
    required this.key,
    required this.label,
    required this.unit,
    required this.value,
  });

  MeasurementFieldModel copyWith({String? value}) {
    return MeasurementFieldModel(
      key: key,
      label: label,
      unit: unit,
      value: value ?? this.value,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'unit': unit,
        'value': value,
      };

  factory MeasurementFieldModel.fromJson(Map<String, dynamic> json) {
    return MeasurementFieldModel(
      key: json['key'] as String? ?? '',
      label: json['label'] as String? ?? '',
      unit: json['unit'] as String? ?? 'in',
      value: json['value'] as String? ?? '',
    );
  }
}

class MeasurementSectionModel {
  final String title;
  final List<MeasurementFieldModel> fields;

  const MeasurementSectionModel({
    required this.title,
    required this.fields,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'fields': fields.map((f) => f.toJson()).toList(),
      };

  factory MeasurementSectionModel.fromJson(Map<String, dynamic> json) {
    return MeasurementSectionModel(
      title: json['title'] as String? ?? '',
      fields: (json['fields'] as List<dynamic>?)
              ?.map((e) => MeasurementFieldModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class MeasurementModel {
  final String id;
  final String customerId;
  final String title;
  final MeasurementCategory category;
  final List<MeasurementSectionModel> sections;
  final DateTime updatedAt;

  const MeasurementModel({
    required this.id,
    required this.customerId,
    required this.title,
    required this.category,
    required this.sections,
    required this.updatedAt,
  });

  factory MeasurementModel.fromJson(Map<String, dynamic> json) {
    final values = json['values'] as Map<String, dynamic>? ?? {};
    List<MeasurementSectionModel> parsedSections = [];
    if (values.containsKey('sections')) {
      parsedSections = (values['sections'] as List<dynamic>)
          .map((s) => MeasurementSectionModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return MeasurementModel(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      title: json['title'] as String? ?? 'Naap',
      category: MeasurementCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => MeasurementCategory.men,
      ),
      sections: parsedSections,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson(String shopId) {
    return {
      'id': id,
      'shop_id': shopId,
      'customer_id': customerId,
      'category': category.name,
      'title': title,
      'values': {
        'sections': sections.map((s) => s.toJson()).toList(),
      },
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class DashboardStats {
  final double dailyRevenue;
  final double monthlyRevenue;
  final int totalOrders;
  final int pendingOrders;
  final int readyOrders;
  final int urgentOrders;
  final List<double> weeklyRevenue;
  final List<String> weekLabels;

  const DashboardStats({
    required this.dailyRevenue,
    required this.monthlyRevenue,
    required this.totalOrders,
    required this.pendingOrders,
    required this.readyOrders,
    required this.urgentOrders,
    required this.weeklyRevenue,
    required this.weekLabels,
  });
}
