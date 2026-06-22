import './models/models.dart';
import '../core/constants/app_enums.dart';

class MockData {
  MockData._();

  // ── CUSTOMERS ──────────────────────────────────────────────
  static final List<CustomerModel> customers = [
    CustomerModel(
      id: 'c1',
      name: 'Ali Khan',
      phone: '0300 1234567',
      address: 'Saddar, Peshawar',
      gender: CustomerGender.male,
      notes: 'Regular customer. Prefers loose-fit kameez.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      totalOrders: 5,
    ),
    CustomerModel(
      id: 'c2',
      name: 'Muhammad Omar',
      phone: '0312 9876543',
      address: 'Hayatabad, Peshawar',
      gender: CustomerGender.male,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      totalOrders: 3,
    ),
    CustomerModel(
      id: 'c3',
      name: 'Zia Ahmed',
      phone: '0345 5554443',
      address: 'University Town, Peshawar',
      gender: CustomerGender.male,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      totalOrders: 2,
    ),
    CustomerModel(
      id: 'c4',
      name: 'Usman Farooq',
      phone: '0312 3456789',
      address: 'Gulbahar, Peshawar',
      gender: CustomerGender.male,
      notes: 'Sleeve thori lamba karna. Brown buttons request ki hain. Gardan check zaroor karna.',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      totalOrders: 7,
    ),
    CustomerModel(
      id: 'c5',
      name: 'Fatima Bibi',
      phone: '0321 1122334',
      address: 'Charsadda Road, Peshawar',
      gender: CustomerGender.female,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      totalOrders: 4,
    ),
    CustomerModel(
      id: 'c6',
      name: 'Zainab Khan',
      phone: '0334 9988776',
      address: 'Board Bazaar, Peshawar',
      gender: CustomerGender.female,
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
      totalOrders: 1,
    ),
    CustomerModel(
      id: 'c7',
      name: 'Bilal Ahmed',
      phone: '0300 7766554',
      address: 'Namak Mandi, Peshawar',
      gender: CustomerGender.male,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      totalOrders: 2,
    ),
    CustomerModel(
      id: 'c8',
      name: 'Kamran Shah',
      phone: '0345 3312456',
      address: 'Dalazak Road, Peshawar',
      gender: CustomerGender.male,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      totalOrders: 3,
    ),
  ];

  // ── ORDERS ─────────────────────────────────────────────────
  static final List<OrderModel> orders = [
    OrderModel(
      id: 'o1',
      customerId: 'c4',
      customerName: 'Usman Farooq',
      tokenNumber: 'T-0421',
      orderNumber: 421,
      orderDate: DateTime.now().subtract(const Duration(days: 2)),
      deliveryDate: DateTime.now().add(const Duration(days: 1)),
      status: OrderStatus.stitching,
      totalAmount: 8500,
      items: [
        const OrderItemModel(
          id: 'oi1',
          dressType: 'Sherwani',
          quantity: 1,
          clothDetails: 'Brown Khaddar',
          designDetails: 'Button sleeves, round collar',
          unitPrice: 8500,
          notes: 'Sleeve thori lamba',
        ),
      ],
      payments: [
        PaymentModel(
          id: 'p1',
          amount: 4500,
          method: PaymentMethod.cash,
          paidAt: DateTime.now().subtract(const Duration(days: 2)),
          note: 'Advance',
        ),
      ],
      notes: 'Sleeve thori lamba karna. Brown buttons request ki hain. Gardan check zaroor karna.',
    ),
    OrderModel(
      id: 'o2',
      customerId: 'c5',
      customerName: 'Fatima Bibi',
      tokenNumber: 'T-0420',
      orderNumber: 420,
      orderDate: DateTime.now().subtract(const Duration(days: 4)),
      deliveryDate: DateTime.now().add(const Duration(days: 4)),
      status: OrderStatus.ready,
      totalAmount: 6200,
      items: [
        const OrderItemModel(
          id: 'oi2',
          dressType: 'Shalwar Kameez',
          quantity: 2,
          clothDetails: 'White Lawn',
          unitPrice: 3100,
        ),
      ],
      payments: [
        PaymentModel(
          id: 'p2',
          amount: 6200,
          method: PaymentMethod.cash,
          paidAt: DateTime.now().subtract(const Duration(days: 4)),
          note: 'Full payment',
        ),
      ],
    ),
    OrderModel(
      id: 'o3',
      customerId: 'c7',
      customerName: 'Bilal Ahmed',
      tokenNumber: 'T-0419',
      orderNumber: 419,
      orderDate: DateTime.now().subtract(const Duration(days: 6)),
      deliveryDate: DateTime.now().add(const Duration(days: 7)),
      status: OrderStatus.cutting,
      totalAmount: 12000,
      items: [
        const OrderItemModel(
          id: 'oi3',
          dressType: 'Waistcoat',
          quantity: 1,
          clothDetails: 'Navy Velvet',
          unitPrice: 5000,
        ),
        const OrderItemModel(
          id: 'oi4',
          dressType: 'Pant',
          quantity: 1,
          clothDetails: 'Navy Velvet matching',
          unitPrice: 7000,
        ),
      ],
      payments: [
        PaymentModel(
          id: 'p3',
          amount: 5000,
          method: PaymentMethod.cash,
          paidAt: DateTime.now().subtract(const Duration(days: 6)),
          note: 'Advance',
        ),
      ],
    ),
    OrderModel(
      id: 'o4',
      customerId: 'c6',
      customerName: 'Zainab Khan',
      tokenNumber: 'T-0418',
      orderNumber: 418,
      orderDate: DateTime.now().subtract(const Duration(days: 3)),
      deliveryDate: DateTime.now().add(const Duration(days: 9)),
      status: OrderStatus.pending,
      totalAmount: 22500,
      items: [
        const OrderItemModel(
          id: 'oi5',
          dressType: 'Lehenga',
          quantity: 1,
          clothDetails: 'Red Chiffon with golden embroidery',
          unitPrice: 22500,
        ),
      ],
      payments: [
        PaymentModel(
          id: 'p4',
          amount: 10000,
          method: PaymentMethod.cash,
          paidAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    ),
    OrderModel(
      id: 'o5',
      customerId: 'c8',
      customerName: 'Kamran Shah',
      tokenNumber: 'T-0417',
      orderNumber: 417,
      orderDate: DateTime.now().subtract(const Duration(days: 15)),
      deliveryDate: DateTime.now().subtract(const Duration(days: 1)),
      status: OrderStatus.delivered,
      totalAmount: 18000,
      items: [
        const OrderItemModel(
          id: 'oi6',
          dressType: 'Suit',
          quantity: 1,
          clothDetails: 'Black Wool',
          designDetails: 'Double button, slim fit',
          unitPrice: 18000,
        ),
      ],
      payments: [
        PaymentModel(
          id: 'p5',
          amount: 10000,
          method: PaymentMethod.cash,
          paidAt: DateTime.now().subtract(const Duration(days: 15)),
        ),
        PaymentModel(
          id: 'p6',
          amount: 8000,
          method: PaymentMethod.cash,
          paidAt: DateTime.now().subtract(const Duration(days: 1)),
          note: 'Final payment on delivery',
        ),
      ],
    ),
  ];

  // ── MEASUREMENTS ───────────────────────────────────────────
  static final List<MeasurementModel> measurements = [
    MeasurementModel(
      id: 'm1',
      customerId: 'c4',
      title: 'Shalwar Kameez',
      category: MeasurementCategory.men,
      updatedAt: DateTime.now().subtract(const Duration(days: 30)),
      sections: const [
        MeasurementSectionModel(
          title: 'Kameez (Shirt)',
          fields: [
            MeasurementFieldModel(key: 'lambai', label: 'Lambai', unit: 'in', value: '42'),
            MeasurementFieldModel(key: 'chaati', label: 'Chaati', unit: 'in', value: '40'),
            MeasurementFieldModel(key: 'kamar', label: 'Kamar', unit: 'in', value: '36'),
            MeasurementFieldModel(key: 'gardan', label: 'Gardan', unit: 'in', value: '15'),
            MeasurementFieldModel(key: 'baghal', label: 'Baghal', unit: 'in', value: '18'),
            MeasurementFieldModel(key: 'shoulder', label: 'Shoulder', unit: 'in', value: '16'),
          ],
        ),
        MeasurementSectionModel(
          title: 'Sleeve (Baazoo)',
          fields: [
            MeasurementFieldModel(key: 'sleeve_lambai', label: 'Lambai', unit: 'in', value: '24'),
            MeasurementFieldModel(key: 'chaurai', label: 'Chaurai', unit: 'in', value: '6.5'),
            MeasurementFieldModel(key: 'mohri', label: 'Mohri', unit: 'in', value: '5'),
          ],
        ),
        MeasurementSectionModel(
          title: 'Shalwar (Trousers)',
          fields: [
            MeasurementFieldModel(key: 'shalwar_lambai', label: 'Lambai', unit: 'in', value: '40'),
            MeasurementFieldModel(key: 'pauncha', label: 'Pauncha', unit: 'in', value: '8'),
            MeasurementFieldModel(key: 'hip', label: 'Hip', unit: 'in', value: '40'),
            MeasurementFieldModel(key: 'ran', label: 'Ran (Thigh)', unit: 'in', value: '22'),
          ],
        ),
      ],
    ),
  ];

  // ── DASHBOARD STATS ────────────────────────────────────────
  static final DashboardStats dashboardStats = DashboardStats(
    dailyRevenue: 45000,
    monthlyRevenue: 850000,
    totalOrders: 24,
    pendingOrders: 8,
    readyOrders: 12,
    urgentOrders: 4,
    weeklyRevenue: [45, 60, 72, 100, 65, 80, 55],
    weekLabels: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  );

  // ── REPORTS DATA ───────────────────────────────────────────
  static const List<Map<String, dynamic>> topDressTypes = [
    {'name': 'Shalwar Kameez', 'count': 28, 'revenue': 67200, 'percent': 0.80},
    {'name': 'Sherwani', 'count': 12, 'revenue': 54000, 'percent': 0.60},
    {'name': 'Lehenga / Frock', 'count': 10, 'revenue': 38500, 'percent': 0.45},
    {'name': 'Suit / Pant Coat', 'count': 8, 'revenue': 24800, 'percent': 0.30},
  ];

  // Helper methods
  static CustomerModel? getCustomerById(String id) {
    try {
      return customers.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<OrderModel> getOrdersForCustomer(String customerId) {
    return orders.where((o) => o.customerId == customerId).toList();
  }

  static List<MeasurementModel> getMeasurementsForCustomer(String customerId) {
    return measurements.where((m) => m.customerId == customerId).toList();
  }
}
