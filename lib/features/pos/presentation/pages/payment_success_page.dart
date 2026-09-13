import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/whatsapp_receipt_helper.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/di/injection.dart';
import '../../data/sales_repository.dart';
import '../bloc/cart_cubit.dart';
import '../../../../core/services/queue_voice_service.dart';

class PaymentSuccessPage extends StatefulWidget {
  final int orderId;
  final User user;
  final CashierSession session;
  final CartState cart;
  final int pointsEarned;
  final int pointsRedeemed;
  final bool autoClearCart;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.user,
    required this.session,
    required this.cart,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
    this.autoClearCart = true,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  bool _isPrinting = false;
  bool _isSharingWa = false;

  @override
  void initState() {
    super.initState();
    // Auto-trigger printing in background
    getIt<PrintService>().printOrder(widget.orderId);

    // Setup entrance animation
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceController, curve: Curves.easeOutBack),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _shareReceiptWhatsApp() async {
    setState(() => _isSharingWa = true);
    try {
      final details = await getIt<SalesRepository>().getOrderDetails(widget.orderId);
      if (details == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memuat detail transaksi.')),
          );
        }
        return;
      }

      final Order order = details['order'];
      final List<Map<String, dynamic>> items = details['items'];
      final List<OrderPayment> payments = details['payments'];
      final Customer? customer = details['customer'];
      final int pointsEarned = details['pointsEarned'] as int? ?? 0;
      final int pointsRedeemed = details['pointsRedeemed'] as int? ?? 0;
      final List<OrderPromotion> promotions = details['promotions'] as List<OrderPromotion>? ?? [];

      final message = await WhatsAppReceiptHelper.generateReceiptMessage(
        order: order,
        items: items,
        payments: payments,
        customer: customer,
        cashierName: widget.user.name,
        pointsEarned: pointsEarned,
        pointsRedeemed: pointsRedeemed,
        promotions: promotions,
      );

      if (mounted) {
        await WhatsAppReceiptHelper.showSendWhatsAppModal(
          context: context,
          receiptMessage: message,
          initialCustomer: customer,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membagikan struk: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharingWa = false);
    }
  }

  Future<void> _printReceipt() async {
    setState(() {
      _isPrinting = true;
    });

    final success = await getIt<PrintService>().printOrder(widget.orderId);

    setState(() {
      _isPrinting = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Struk berhasil dicetak!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal mencetak struk! Pastikan printer Anda terhubung.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  void _finish() {
    if (widget.autoClearCart) {
      context.read<CartCubit>().clearCart();
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: themeColor,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- TOP ACTIONS BAR ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Back/Close button
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                            onPressed: _finish,
                          ),
                          Text(
                            'Bukti Pembayaran',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: _isSharingWa
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF25D366)),
                                      )
                                    : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                                tooltip: 'Kirim Struk WA / Bagikan',
                                onPressed: _isSharingWa ? null : _shareReceiptWhatsApp,
                              ),
                              const SizedBox(width: 4),
                              FilledButton.icon(
                                onPressed: _printReceipt,
                                icon: const Icon(Icons.print_rounded, size: 16),
                                label: Text(
                                  'Cetak',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // --- MAIN TICKET CONTENT ---
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                      child: AnimatedBuilder(
                        animation: _entranceController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _fadeAnimation.value,
                            child: Transform.translate(
                              offset: Offset(0, _slideAnimation.value),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 480),
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    alignment: Alignment.topCenter,
                                    children: [
                                  // The Ticket Card
                                  ClipPath(
                                    clipper: TicketClipper(),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // --- TICKET UPPER SECTION ---
                                          Text(
                                            'Great!',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF1E5631),
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Pembayaran Berhasil',
                                            style: GoogleFonts.poppins(
                                              color: Colors.black,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Transaksi berhasil disimpan & diproses',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 16),

                                          // Card Nomor Antrean & Tombol Panggil Suara
                                          Builder(
                                            builder: (context) {
                                              String qNum = '';
                                              final notes = widget.cart.orderNotes ?? '';
                                              final match = RegExp(r'#(\d+)').firstMatch(notes);
                                              if (match != null) {
                                                qNum = match.group(1)!;
                                              }

                                              final displayQueue = qNum.isNotEmpty ? "Antrean #$qNum" : "Pesanan Lunas";

                                              return Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFEF3C7),
                                                  borderRadius: BorderRadius.circular(16),
                                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        const Icon(Icons.confirmation_number_rounded, color: Color(0xFFB45309), size: 20),
                                                        const SizedBox(width: 8),
                                                        Text(
                                                          displayQueue,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w800,
                                                            color: const Color(0xFF78350F),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    ValueListenableBuilder<String?>(
                                                      valueListenable: QueueVoiceService().currentlySpeakingQueue,
                                                      builder: (context, speakingQueue, child) {
                                                        final isSpeaking = speakingQueue == (qNum.isNotEmpty ? qNum : displayQueue);
                                                        return ElevatedButton.icon(
                                                          onPressed: () {
                                                            if (isSpeaking) {
                                                              QueueVoiceService().stop();
                                                            } else {
                                                              QueueVoiceService().speakQueueCall(
                                                                queueNumber: qNum.isNotEmpty ? qNum : "01",
                                                                customerName: widget.cart.selectedCustomer?.name,
                                                                tableName: widget.cart.selectedTable?.name,
                                                              );
                                                            }
                                                          },
                                                          icon: Icon(
                                                            isSpeaking ? Icons.volume_up_rounded : Icons.record_voice_over_rounded,
                                                            size: 18,
                                                          ),
                                                          label: Text(
                                                            isSpeaking ? 'Memanggil Antrean...' : '🔊 Panggil Antrean Sekarang',
                                                            style: GoogleFonts.poppins(
                                                              fontWeight: FontWeight.w700,
                                                              fontSize: 12.5,
                                                            ),
                                                          ),
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: isSpeaking ? const Color(0xFF10B981) : const Color(0xFF0F172A),
                                                            foregroundColor: Colors.white,
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                                            elevation: 0,
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                          const SizedBox(height: 20),

                                          // Dashed Separator Line
                                          const DashedLine(height: 1.5, color: Colors.black12),
                                          const SizedBox(height: 24),

                                          // --- TICKET LOWER SECTION ---
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: Text(
                                              'Rincian Belanja:',
                                              style: GoogleFonts.poppins(
                                                color: Colors.grey.shade600,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),

                                           // Catatan Pesanan / Meja (jika ada)
                                           if (widget.cart.selectedTable != null || (widget.cart.orderNotes != null && widget.cart.orderNotes!.isNotEmpty)) ...[
                                             Container(
                                               width: double.infinity,
                                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                               decoration: BoxDecoration(
                                                 color: const Color(0xFFF1F5F9),
                                                 borderRadius: BorderRadius.circular(10),
                                                 border: Border.all(color: const Color(0xFFE2E8F0)),
                                               ),
                                               child: Column(
                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                 children: [
                                                   if (widget.cart.selectedTable != null)
                                                     Row(
                                                       children: [
                                                         const Icon(Icons.table_restaurant_rounded, size: 14, color: AppConstants.primaryColor),
                                                         const SizedBox(width: 6),
                                                         Expanded(
                                                           child: Text(
                                                             'Meja: ${widget.cart.selectedTable!.name} (${widget.cart.selectedTable!.section})',
                                                             style: GoogleFonts.poppins(
                                                               fontSize: 12,
                                                               fontWeight: FontWeight.bold,
                                                               color: const Color(0xFF0F172A),
                                                             ),
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                   if (widget.cart.selectedTable != null && widget.cart.orderNotes != null && widget.cart.orderNotes!.isNotEmpty)
                                                     const SizedBox(height: 4),
                                                   if (widget.cart.orderNotes != null && widget.cart.orderNotes!.isNotEmpty)
                                                     Row(
                                                       crossAxisAlignment: CrossAxisAlignment.start,
                                                       children: [
                                                         const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF64748B)),
                                                         const SizedBox(width: 6),
                                                         Expanded(
                                                           child: Text(
                                                             'Catatan: ${widget.cart.orderNotes!}',
                                                             style: GoogleFonts.poppins(
                                                               fontSize: 11,
                                                               color: const Color(0xFF475569),
                                                               fontStyle: FontStyle.italic,
                                                             ),
                                                           ),
                                                         ),
                                                       ],
                                                     ),
                                                 ],
                                               ),
                                             ),
                                             const SizedBox(height: 16),
                                           ],

                                           // Cart Items summary list inside a capsule
                                           Container(
                                             padding: const EdgeInsets.all(12),
                                             decoration: BoxDecoration(
                                               color: Colors.grey.shade50,
                                               borderRadius: BorderRadius.circular(16),
                                             ),
                                             child: Column(
                                               children: widget.cart.items.map((item) {
                                                 final qtyStr = item.quantity.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
                                                 return Padding(
                                                   padding: const EdgeInsets.symmetric(vertical: 4.0),
                                                   child: Row(
                                                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                     crossAxisAlignment: CrossAxisAlignment.start,
                                                     children: [
                                                       Expanded(
                                                         child: Column(
                                                           crossAxisAlignment: CrossAxisAlignment.start,
                                                           children: [
                                                             Text(
                                                               item.product.name,
                                                               style: GoogleFonts.poppins(
                                                                 fontSize: 12,
                                                                 fontWeight: FontWeight.w600,
                                                                 color: Colors.black87,
                                                               ),
                                                               maxLines: 2,
                                                               overflow: TextOverflow.ellipsis,
                                                             ),
                                                             if (item.notes != null && item.notes!.trim().isNotEmpty) ...[
                                                               const SizedBox(height: 2),
                                                               Row(
                                                                 crossAxisAlignment: CrossAxisAlignment.start,
                                                                 children: [
                                                                   const Text('• ', style: TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                                                                   Expanded(
                                                                     child: Text(
                                                                       item.notes!.trim(),
                                                                       style: GoogleFonts.poppins(
                                                                         fontSize: 10.5,
                                                                         color: const Color(0xFFD97706),
                                                                         fontWeight: FontWeight.w500,
                                                                         fontStyle: FontStyle.italic,
                                                                       ),
                                                                     ),
                                                                   ),
                                                                 ],
                                                               ),
                                                             ],
                                                             const SizedBox(height: 2),
                                                             Text(
                                                               '$qtyStr ${item.unit.name} x ${CurrencyFormatter.format(item.price)}',
                                                               style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                                                             ),
                                                           ],
                                                         ),
                                                       ),
                                                       const SizedBox(width: 8),
                                                       Text(
                                                         CurrencyFormatter.format(item.subtotal),
                                                         style: GoogleFonts.poppins(
                                                           fontSize: 12,
                                                           fontWeight: FontWeight.bold,
                                                           color: Colors.black87,
                                                         ),
                                                       ),
                                                     ],
                                                   ),
                                                 );
                                               }).toList(),
                                             ),
                                           ),
                                          const SizedBox(height: 24),

                                          // Total Payment Info
                                          Text(
                                            'Total Pembayaran',
                                            style: GoogleFonts.poppins(
                                              color: Colors.grey.shade600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            CurrencyFormatter.format(widget.cart.grandTotal),
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF0F2C59),
                                              fontSize: 28,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (widget.cart.appliedPromotions.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            for (final p in widget.cart.appliedPromotions)
                                              Container(
                                                margin: const EdgeInsets.only(bottom: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFEFF6FF),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.local_offer_rounded, size: 13, color: Color(0xFF2563EB)),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          p.promoName,
                                                          style: GoogleFonts.poppins(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xFF1E40AF),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Text(
                                                      '-${CurrencyFormatter.format(p.discountAmount)}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w700,
                                                        color: const Color(0xFF1E40AF),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                          const SizedBox(height: 16),

                                          if (widget.pointsEarned > 0 || widget.pointsRedeemed > 0) ...[
                                            Divider(
                                              color: AppConstants.borderLightColor,
                                              height: 1,
                                            ),
                                            const SizedBox(height: 12),
                                            if (widget.pointsEarned > 0)
                                              Row(
                                                children: [
                                                  const Icon(Icons.card_giftcard_rounded,
                                                      size: 16, color: AppConstants.warningColor),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Poin didapat: +${widget.pointsEarned}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      color: AppConstants.successColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            if (widget.pointsRedeemed > 0)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: widget.pointsEarned > 0 ? 4 : 0,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.redeem_rounded,
                                                        size: 16, color: AppConstants.warningColor),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      'Poin ditukar: -${widget.pointsRedeemed}',
                                                      style: GoogleFonts.poppins(
                                                        fontSize: 12,
                                                        color: AppConstants.textLightColor,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 12),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Overlapping Pulsing Checkmark
                                  const Positioned(
                                    top: -45,
                                    child: PulsingCheckmark(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                      ),
                    ),
                  ),
                ),

                // --- FOOTER BUTTONS ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _printReceipt,
                                  icon: const Icon(Icons.print_rounded, size: 16),
                                  label: Text(
                                    'Cetak Struk',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _isSharingWa ? null : _shareReceiptWhatsApp,
                                  icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF25D366)),
                                  label: Text(
                                    'Kirim WA',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12, color: const Color(0xFF25D366)),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF25D366),
                                    side: BorderSide(color: const Color(0xFF25D366).withValues(alpha: 0.5)),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _finish,
                              icon: Icon(
                                widget.autoClearCart
                                    ? Icons.add_shopping_cart_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                widget.autoClearCart
                                    ? 'Transaksi Baru'
                                    : 'Selesai & Lanjut Tagihan Lain',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: themeColor,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_isPrinting)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Mencetak Struk...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════
// WIDGETS
// ═════════════════════════════════════════════════

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    const cutoutRadius = 14.0;
    final cutoutY = size.height * 0.42;
    
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width, cutoutY - cutoutRadius);
    path.arcToPoint(
      Offset(size.width, cutoutY + cutoutRadius),
      radius: const Radius.circular(cutoutRadius),
      clockwise: false,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, cutoutY + cutoutRadius);
    path.arcToPoint(
      Offset(0, cutoutY - cutoutRadius),
      radius: const Radius.circular(cutoutRadius),
      clockwise: false,
    );
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class DashedLine extends StatelessWidget {
  final double height;
  final Color color;

  const DashedLine({super.key, this.height = 1, this.color = Colors.black12});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 6.0;
        final dashHeight = height;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color),
              ),
            );
          }),
        );
      },
    );
  }
}

class PulsingCheckmark extends StatefulWidget {
  const PulsingCheckmark({super.key});

  @override
  State<PulsingCheckmark> createState() => _PulsingCheckmarkState();
}

class _PulsingCheckmarkState extends State<PulsingCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeBlue = const Color(0xFF3B82F6);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final value = _controller.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing ring 2
            Transform.scale(
              scale: 1.0 + (value * 0.45),
              child: Opacity(
                opacity: (1.0 - value).clamp(0.0, 1.0),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: themeBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Outer pulsing ring 1
            Transform.scale(
              scale: 1.0 + (value * 0.22),
              child: Opacity(
                opacity: (1.0 - value).clamp(0.0, 1.0),
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: themeBlue.withValues(alpha: 0.24),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            // Central blue checkmark container
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: themeBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: themeBlue.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 46,
              ),
            ),
          ],
        );
      },
    );
  }
}
