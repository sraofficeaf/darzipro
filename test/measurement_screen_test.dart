import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:darzi_pro/features/measurements/measurements_screen.dart';
import 'package:darzi_pro/features/printing/widgets/naap_card_widget.dart';
import 'package:darzi_pro/shared/models/models.dart';
import 'package:darzi_pro/core/constants/app_enums.dart';

void main() {
  group('Measurement 3-Step Redesign Tests', () {
    test('15 Standard measurement fields are defined with correct keys', () {
      expect(k15MeasurementFields.length, 15);
      final keys = k15MeasurementFields.map((f) => f.key).toList();
      expect(keys, containsAll([
        'lambai',
        'teerwa',
        'bazo',
        'chaati',
        'baghal',
        'kamar',
        'daman',
        'collar',
        'shalwar',
        'panche',
        'kaf',
        'jeb',
        'gol',
        'asan',
        'gareban',
      ]));
    });

    testWidgets('Custom painters paint all 15 shape icons without throwing', (tester) async {
      for (final field in k15MeasurementFields) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: CustomPaint(
                    painter: MeasurementShapePainter(
                      keyName: field.key,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });

    test('MeasurementModel round-trip serialization with sections and silaiOptions', () {
      final fields = [
        const MeasurementFieldModel(key: 'lambai', label: 'Length', unit: 'in', value: '40'),
        const MeasurementFieldModel(key: 'teerwa', label: 'Shoulder', unit: 'in', value: '17.5'),
      ];
      final designFields = [
        const MeasurementFieldModel(key: 'collar_type', label: 'Collar Type', unit: '', value: 'Standard'),
      ];
      final measurement = MeasurementModel(
        id: 'test_m_1',
        customerId: 'cust_123',
        title: 'شلوار قمیض',
        profileName: 'شلوار قمیض',
        category: MeasurementCategory.men,
        sections: [
          MeasurementSectionModel(title: 'Measurements', fields: fields),
          MeasurementSectionModel(title: 'Design Options', fields: designFields),
        ],
        updatedAt: DateTime(2026, 9, 13),
        silaiOptions: [
          {'label': 'ڈبل سلائی', 'checked': true},
          {'label': 'زنجیری سلائی', 'checked': false},
        ],
        silaiNotes: 'بازو باریک رکھنا ہے',
      );

      final json = measurement.toJson('shop_test');
      expect(json['id'], 'test_m_1');
      expect(json['customer_id'], 'cust_123');
      expect(json['category'], 'men');
      expect(json['title'], 'شلوار قمیض');
      expect(json['profile_name'], 'شلوار قمیض');

      final deserialized = MeasurementModel.fromJson(json);
      expect(deserialized.id, 'test_m_1');
      expect(deserialized.profileName, 'شلوار قمیض');
      expect(deserialized.category, MeasurementCategory.men);
      expect(deserialized.silaiNotes, 'بازو باریک رکھنا ہے');
      expect(deserialized.silaiOptions?.length, 2);
      expect(deserialized.sections.first.fields.first.value, '40');
    });

    testWidgets('NaapCardWidget only prints entered measurement fields on white background', (tester) async {
      final order = OrderModel(
        id: 'ord_1',
        customerId: 'cust_1',
        customerName: 'سعید الرحمان',
        tokenNumber: 'TK-101',
        orderNumber: 101,
        orderDate: DateTime(2026, 9, 13),
        status: OrderStatus.pending,
        totalAmount: 1500,
        items: const [],
        payments: const [],
      );

      final customer = CustomerModel(
        id: 'cust_1',
        name: 'سعید الرحمان',
        phone: '0300-1234567',
        address: 'Peshawar',
        gender: CustomerGender.male,
        createdAt: DateTime(2026, 6, 23),
      );

      // Tailor only filled 3 measurements: lambai (42), teerwa (18), chaati (40)
      // The other 12 fields are empty/unfilled
      final measurement = MeasurementModel(
        id: 'm_1',
        customerId: 'cust_1',
        title: 'شلوار قمیض',
        category: MeasurementCategory.men,
        sections: [
          const MeasurementSectionModel(
            title: 'Measurements',
            fields: [
              MeasurementFieldModel(key: 'lambai', label: 'Length', unit: 'in', value: '42'),
              MeasurementFieldModel(key: 'teerwa', label: 'Shoulder', unit: 'in', value: '18'),
              MeasurementFieldModel(key: 'chaati', label: 'Chest', unit: 'in', value: '40'),
              MeasurementFieldModel(key: 'daman', label: 'Hem', unit: 'in', value: ''),
              MeasurementFieldModel(key: 'jeb', label: 'Pocket', unit: 'in', value: '0'),
            ],
          ),
        ],
        updatedAt: DateTime.now(),
        silaiOptions: [
          {'label': 'ڈبل سلائی', 'checked': true},
          {'label': 'زنجیری سلائی', 'checked': false},
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: NaapCardWidget(
                order: order,
                customer: customer,
                measurement: measurement,
              ),
            ),
          ),
        ),
      );

      // Entered values MUST be present
      expect(find.text('42"'), findsOneWidget);
      expect(find.text('18"'), findsOneWidget);
      expect(find.text('40"'), findsOneWidget);

      // Unfilled fields must NOT be printed as values
      expect(find.text('0"'), findsNothing);

      // Checked silai option must be displayed
      expect(find.text('ڈبل سلائی'), findsOneWidget);
      // Unchecked silai option must NOT be displayed
      expect(find.text('زنجیری سلائی'), findsNothing);
    });
  });
}

