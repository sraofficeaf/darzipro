import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_extensions.dart';
import 'ie_earning_card.dart';

/// Row widget for each payout in the Payouts screen
class IePayoutRow extends StatefulWidget {
  final Map<String, dynamic> payout;

  const IePayoutRow({super.key, required this.payout});

  @override
  State<IePayoutRow> createState() => _IePayoutRowState();
}

class _IePayoutRowState extends State<IePayoutRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text1 = context.text1;
    final text2 = context.text2;
    final surface = context.surface;
    final border = context.border;

    final payout = widget.payout;
    final isPaid = payout['status'] == 'paid';
    final statusColor = isPaid ? ieAccent : const Color(0xFFF5A623);
    final statusLabel = isPaid ? 'Paid' : 'Pending';

    final amount = payout['total_amount'] as int? ?? 0;
    final period = payout['period_month'] as String? ?? '-';
    final paidAt = payout['paid_at'] != null
        ? payout['paid_at'].toString().split('T')[0]
        : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _expanded ? ieAccentBorder : border,
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      size: 20,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          period,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: text1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isPaid && paidAt != null
                              ? 'Paid on $paidAt'
                              : 'Awaiting payment',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rs ${_fmt(amount)}',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(top: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: statusColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          statusLabel,
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down_rounded,
                        size: 18, color: text2),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              decoration: BoxDecoration(
                color: ieAccentBg.withValues(alpha: 0.5),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Text(
                    'Payout Details',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: ieAccent,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _detailRow('Period', period, text1, text2),
                  _detailRow('Amount', 'Rs ${_fmt(amount)}', text1, text2),
                  _detailRow('Status', statusLabel, statusColor, text2),
                  if (paidAt != null)
                    _detailRow('Payment Date', paidAt, text1, text2),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _detailRow(
      String label, String value, Color valueColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: labelColor)),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: valueColor)),
        ],
      ),
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
}
