import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../shared/models/models.dart';

/// Standard Flutter Widget for Token Card (Customer Copy / Thermal Roll format).
/// Rendered natively by Flutter's engine (Skia/Impeller) for 100% pixel-perfect
/// Urdu shaping, RTL text joining, and crisp QR codes before export to PDF image.
class TokenCardWidget extends StatelessWidget {
  final OrderModel order;
  final CustomerModel? customer;
  final bool isThermal;

  const TokenCardWidget({
    super.key,
    required this.order,
    required this.customer,
    this.isThermal = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isThermal) {
      return _buildThermalLayout();
    } else {
      return _buildA4Layout();
    }
  }

  // ── 80MM THERMAL LAYOUT ──────────────────────────────────────────────────
  Widget _buildThermalLayout() {
    return Container(
      width: 380, // Standard 80mm thermal width
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shop Header
          Center(
            child: Column(
              children: [
                Text(
                  'SaifurRahman Tailors',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Saddar, Peshawar · 0300-1234567',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF475569)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // Token Number & Order Number
          Center(
            child: Column(
              children: [
                Text(
                  'TOKEN NO.',
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
                ),
                Text(
                  order.tokenNumber,
                  style: GoogleFonts.outfit(fontSize: 36, fontWeight: FontWeight.w900, color: const Color(0xFFD97706)),
                ),
                Text(
                  'Order #${order.orderNumber}',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // Customer Info
          Text('CUSTOMER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            order.customerName,
            style: GoogleFonts.notoNaskhArabic(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
          ),
          if (customer?.phone != null && customer!.phone.isNotEmpty)
            Text(
              'Ph: ${customer!.phone}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF475569)),
            ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // Dates
          _thermalRow('Order Date:', formatDateShort(order.orderDate)),
          if (order.deliveryDate != null)
            _thermalRow(
              'Delivery Date:',
              formatDateShort(order.deliveryDate!),
              bold: true,
              highlight: order.isUrgent,
            ),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // Items Table
          Text('ITEMS', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${item.dressType} x${item.quantity} ${item.clothDetails}',
                        style: GoogleFonts.inter(fontSize: 11),
                      ),
                    ),
                    Text(
                      formatMoney(item.total),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 10),
          _divider(),
          const SizedBox(height: 10),

          // Payment Breakdown
          _thermalRow('Total Amount:', formatMoney(order.totalAmount)),
          _thermalRow('Advance Paid:', formatMoney(order.paidAmount)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF0F172A), width: 1),
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.isFullyPaid ? 'FULLY PAID' : 'REMAINING BAL:',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                Text(
                  order.isFullyPaid ? 'CLEAR' : formatMoney(order.remainingAmount),
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFFD97706)),
                ),
              ],
            ),
          ),

          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            _divider(),
            Text('NOTES:', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
            Text(order.notes!, style: GoogleFonts.notoNaskhArabic(fontSize: 11)),
          ],

          const SizedBox(height: 12),
          Center(
            child: QrImageView(
              data: 'darzi-order:${order.id}',
              version: QrVersions.auto,
              size: 80.0,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '-- Generated by Darzi Pro --',
              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
            ),
          ),
        ],
      ),
    );
  }

  // ── A4 FULL CARD LAYOUT ──────────────────────────────────────────────────
  Widget _buildA4Layout() {
    return Container(
      width: 700,
      height: 990,
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5A623),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('✂️', style: TextStyle(fontSize: 20)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SaifurRahman Tailors',
                          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        Text(
                          'Saddar, Peshawar · 0300-1234567',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFF5A623)),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFF5A623)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text('TOKEN', style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFF5A623), letterSpacing: 1.2)),
                      Text(
                        order.tokenNumber,
                        style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFFF5A623)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Customer Block & Dates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CUSTOMER', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                  Text(
                    order.customerName,
                    style: GoogleFonts.notoNaskhArabic(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                  ),
                  if (customer?.phone != null)
                    Text('Ph: ${customer!.phone}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569))),
                ],
              ),
              Row(
                children: [
                  _dateBox('ORDER DATE', formatDateShort(order.orderDate), urgent: false),
                  const SizedBox(width: 10),
                  _dateBox(
                    'DELIVERY DATE',
                    order.deliveryDate != null ? formatDateShort(order.deliveryDate!) : 'Not Set',
                    urgent: order.isUrgent,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Items Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    color: const Color(0xFFF8FAFC),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text('ITEM / CLOTH DETAILS', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)))),
                        Text('QTY', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                        const SizedBox(width: 50),
                        Text('PRICE', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      itemCount: order.items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      itemBuilder: (context, idx) {
                        final item = order.items[idx];
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.dressType, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                                    if (item.clothDetails.isNotEmpty)
                                      Text(item.clothDetails, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              Text('x${item.quantity}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 36),
                              Text(formatMoney(item.total), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Money Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total: ${formatMoney(order.totalAmount)}', style: GoogleFonts.inter(color: Colors.white, fontSize: 13)),
                    Text('Advance: ${formatMoney(order.paidAmount)}', style: GoogleFonts.inter(color: const Color(0xFF10B981), fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('REMAINING BALANCE', style: GoogleFonts.inter(color: const Color(0xFFF5A623), fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(
                      order.isFullyPaid ? 'FULLY PAID' : formatMoney(order.remainingAmount),
                      style: GoogleFonts.outfit(color: const Color(0xFFF5A623), fontSize: 22, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Footer Row with QR
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Generated by Darzi Pro', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
              QrImageView(data: 'darzi-order:${order.id}', version: QrVersions.auto, size: 48.0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateBox(String label, String value, {required bool urgent}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF64748B))),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: urgent ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thermalRow(String label, String value, {bool bold = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 11)),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: highlight ? 12 : 11,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: highlight ? const Color(0xFFDC2626) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      height: 1,
      color: const Color(0xFFE2E8F0),
    );
  }
}
