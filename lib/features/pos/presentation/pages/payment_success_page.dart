import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/services/print_service.dart';
import '../../../../core/di/injection.dart';
import '../bloc/cart_cubit.dart';

class PaymentSuccessPage extends StatefulWidget {
  final int orderId;
  final User user;
  final CashierSession session;
  final CartState cart;
  final int pointsEarned;
  final int pointsRedeemed;

  const PaymentSuccessPage({
    super.key,
    required this.orderId,
    required this.user,
    required this.session,
    required this.cart,
    this.pointsEarned = 0,
    this.pointsRedeemed = 0,
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
    context.read<CartCubit>().clearCart();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = AppConstants.primaryDarkColor;

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
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back/Close button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                        onPressed: _finish,
                      ),
                      Text(
                        'Detail Pembayaran',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Print button
                      IconButton(
                        icon: const Icon(Icons.print_rounded, color: Colors.white, size: 24),
                        onPressed: _printReceipt,
                        tooltip: 'Cetak Struk',
                      ),
                    ],
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
                                          const SizedBox(height: 24),

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
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                            ),
                                                            Text(
                                                              '$qtyStr ${item.unit.name} x ${CurrencyFormatter.format(item.price)}',
                                                              style: const TextStyle(fontSize: 11, color: AppConstants.textLightColor),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
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
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // --- FOOTER BUTTON ---
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton(
                    onPressed: _finish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: themeColor,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Transaksi Baru',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
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
