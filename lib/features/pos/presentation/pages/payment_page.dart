import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../data/sales_repository.dart';
import '../bloc/cart_cubit.dart';
import '../bloc/sales_cubit.dart';
import 'payment_success_page.dart';

class PaymentPage extends StatefulWidget {
  final User user;
  final CashierSession session;
  final CartState cart;
  final bool autoClearCart;

  const PaymentPage({
    super.key,
    required this.user,
    required this.session,
    required this.cart,
    this.autoClearCart = true,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage>
    with TickerProviderStateMixin {
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();
  final _redeemPointsController = TextEditingController();
  String _paymentMethod = 'cash';
  double _amountPaid = 0.0;
  double _changeAmount = 0.0;

  final SalesRepository _salesRepo = getIt<SalesRepository>();

  Map<String, int> _pointsSettings = {
    'enabled': 0,
    'earnRate': 1000,
    'redeemValue': 10,
    'minRedeem': 100,
  };
  int _customerPointsBalance = 0;
  int _pointsRedeemed = 0;
  double _pointsDiscount = 0.0;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Definisi metode pembayaran formal & konsisten
  static const _paymentMethods = [
    {
      'id': 'cash',
      'label': 'Tunai',
      'sublabel': 'Bayar langsung',
      'icon': Icons.payments_rounded,
    },
    {
      'id': 'qris',
      'label': 'QRIS',
      'sublabel': 'Scan barcode QRIS',
      'icon': Icons.qr_code_scanner_rounded,
    },
    {
      'id': 'card',
      'label': 'Kartu',
      'sublabel': 'EDC / Debit / Kredit',
      'icon': Icons.credit_card_rounded,
    },
    {
      'id': 'transfer',
      'label': 'Transfer',
      'sublabel': 'Transfer via Bank',
      'icon': Icons.account_balance_rounded,
    },
    {
      'id': 'multi',
      'label': 'Campur',
      'sublabel': 'Split Payment (Multi)',
      'icon': Icons.pie_chart_rounded,
    },
    {
      'id': 'debt',
      'label': 'Bon',
      'sublabel': 'Bon / Piutang',
      'icon': Icons.assignment_late_rounded,
    },
  ];

  // List rincian pembayaran untuk Split Payment (Multi-Payment)
  List<Map<String, dynamic>> _splitPayments = [];

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.cart.grandTotal;
    _amountPaidController.text = _formatNumber(_amountPaid.toStringAsFixed(0));
    if (widget.cart.orderNotes != null && widget.cart.orderNotes!.isNotEmpty) {
      _notesController.text = widget.cart.orderNotes!;
    }
    _calculateChange();
    _loadPointsData();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    _redeemPointsController.dispose();
    super.dispose();
  }

  Future<void> _loadPointsData() async {
    final customerId = widget.cart.selectedCustomer?.id;
    if (customerId == null) return;

    _pointsSettings = await _salesRepo.getPointsSettings();
    if (_pointsSettings['enabled'] == 0) return;

    try {
      final balance = await _salesRepo.getCustomerPointsBalance(customerId);
      if (mounted) {
        setState(() => _customerPointsBalance = balance);
      }
    } catch (_) {}
  }

  void _initSplitPayments() {
    if (_splitPayments.isEmpty) {
      final total = widget.cart.grandTotal;
      final half = (total / 2).roundToDouble();
      _splitPayments = [
        {'method': 'cash', 'amount': half, 'referenceId': null},
        {'method': 'qris', 'amount': total - half, 'referenceId': null},
      ];
    }
  }

  double get _totalSplitPaid => _splitPayments.fold<double>(
        0.0,
        (sum, item) => sum + (item['amount'] as double? ?? 0.0),
      );

  void _calculateChange() {
    setState(() {
      if (_paymentMethod == 'debt') {
        _changeAmount = 0.0;
        // Let _amountPaid be whatever user typed for DP, default to 0.0 initially
      } else if (_paymentMethod == 'multi') {
        _initSplitPayments();
        _amountPaid = _totalSplitPaid;
        _changeAmount = _amountPaid - widget.cart.grandTotal;
        if (_changeAmount < 0) _changeAmount = 0.0;
      } else if (_paymentMethod != 'cash') {
        _amountPaid = widget.cart.grandTotal;
        _amountPaidController.text = _formatNumber(_amountPaid.toStringAsFixed(0));
        _changeAmount = 0.0;
      } else {
        _changeAmount = _amountPaid - widget.cart.grandTotal;
        if (_changeAmount < 0) _changeAmount = 0.0;
      }
    });
  }

  List<double> _getCashSuggestions() {
    final total = widget.cart.grandTotal;
    final List<double> suggestions = [total];
    final denom = [5000.0, 10000.0, 20000.0, 50000.0, 100000.0, 200000.0];
    for (var d in denom) {
      if (d > total) {
        if (!suggestions.contains(d)) suggestions.add(d);
      }
      final roundedUp = ((total / d).ceil() * d);
      if (roundedUp > total && !suggestions.contains(roundedUp)) {
        suggestions.add(roundedUp);
      }
    }
    suggestions.sort();
    return suggestions.take(4).toList();
  }

  void _checkout() {
    if (_paymentMethod == 'cash' && _amountPaid < widget.cart.grandTotal) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Text('Nominal uang bayar kurang dari total!'),
            ],
          ),
          backgroundColor: AppConstants.errorColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_paymentMethod == 'multi') {
      final totalPaid = _totalSplitPaid;
      if (_splitPayments.isEmpty || totalPaid < widget.cart.grandTotal) {
        HapticFeedback.heavyImpact();
        final sisa = widget.cart.grandTotal - totalPaid;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Total pembayaran split masih kurang ${CurrencyFormatter.format(sisa)}!',
                  ),
                ),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        return;
      }
    }

    HapticFeedback.mediumImpact();
    final cartItemsMap = widget.cart.items.map((item) {
      return {
        'product': item.product,
        'unit': item.unit,
        'quantity': item.quantity,
        'price': item.price,
        'discountAmount': item.discountAmount,
        'appliedMinQty': item.appliedMinQty,
        'notes': item.notes,
      };
    }).toList();

    List<Map<String, dynamic>> paymentsMap;
    if (_paymentMethod == 'debt') {
      paymentsMap = [
        {
          'method': 'debt',
          'amount': widget.cart.grandTotal - _amountPaid,
          'referenceId': null,
        },
        if (_amountPaid > 0)
          {
            'method': 'cash',
            'amount': _amountPaid,
            'referenceId': null,
          },
      ];
    } else if (_paymentMethod == 'multi') {
      paymentsMap = _splitPayments.where((p) => (p['amount'] as double? ?? 0.0) > 0).map((p) {
        return {
          'method': p['method'] as String,
          'amount': p['amount'] as double,
          'referenceId': p['referenceId'] as String?,
        };
      }).toList();
    } else {
      paymentsMap = [
        {
          'method': _paymentMethod,
          'amount': widget.cart.grandTotal,
          'referenceId': null,
        }
      ];
    }

    final effectiveGrandTotal = widget.cart.grandTotal;
    final earnRate = _pointsSettings['earnRate'] ?? 1000;
    final actualPaid = _paymentMethod == 'debt'
        ? _amountPaid
        : (_paymentMethod == 'cash'
            ? _amountPaid
            : (_paymentMethod == 'multi' ? _totalSplitPaid : effectiveGrandTotal));
    final pointsEarned = actualPaid >= earnRate ? (actualPaid ~/ earnRate) : 0;

    context.read<SalesCubit>().checkout(
          userId: widget.user.id,
          cashierSessionId: widget.session.id,
          subtotal: widget.cart.subtotal,
          discountAmount: widget.cart.discountAmount,
          taxAmount: widget.cart.taxAmount,
          grandTotal: effectiveGrandTotal,
          paidAmount: actualPaid,
          changeAmount: _paymentMethod == 'multi'
              ? (actualPaid > effectiveGrandTotal ? actualPaid - effectiveGrandTotal : 0.0)
              : _changeAmount,
          downPayment: _paymentMethod == 'debt' ? _amountPaid : 0.0,
          cartItems: cartItemsMap,
          payments: paymentsMap,
          customerId: widget.cart.selectedCustomer?.id,
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          pointsEarned: pointsEarned,
          pointsRedeemed: _pointsRedeemed,
          pointsDiscount: _pointsDiscount,
        );
  }

  Map<String, dynamic> get _selectedMethod =>
      _paymentMethods.firstWhere((m) => m['id'] == _paymentMethod);

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.of(context).size.width > 720;

    return BlocListener<SalesCubit, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          final earnRate = _pointsSettings['earnRate'] ?? 1000;
          final actualPaid = _paymentMethod == 'debt'
              ? _amountPaid
              : (_paymentMethod == 'cash' ? _amountPaid : widget.cart.grandTotal);
          final earned = actualPaid >= earnRate ? (actualPaid ~/ earnRate) : 0;

          Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessPage(
                orderId: state.orderId,
                user: widget.user,
                session: widget.session,
                cart: widget.cart,
                pointsEarned: earned,
                pointsRedeemed: _pointsRedeemed,
                autoClearCart: widget.autoClearCart,
              ),
            ),
          ).then((result) {
            if (context.mounted) {
              Navigator.pop(context, result ?? true);
            }
          });
        }
        if (state is SalesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppConstants.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: isTablet ? _buildTabletLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📱 MOBILE PAYMENT LAYOUT (< 720px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildMobileLayout() {
    return Column(
      children: [
        // ── Header Executive Deep Slate ──────────────────────────────
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Pembayaran Transaksi',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      // Badge Detail
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.shopping_bag_outlined,
                                size: 13, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.cart.items.length} Item',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL TAGIHAN PEMBAYARAN',
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 2),
                        ScaleTransition(
                          scale: _pulseAnimation,
                          child: Text(
                            CurrencyFormatter.format(
                                widget.cart.grandTotal),
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Summary Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildHeaderStat(
                                  'Subtotal',
                                  CurrencyFormatter.format(
                                      widget.cart.subtotal)),
                              if (widget.cart.discountAmount > 0)
                                _buildHeaderStat(
                                    'Diskon',
                                    '-${CurrencyFormatter.format(widget.cart.discountAmount)}'),
                              if (widget.cart.taxAmount > 0)
                                _buildHeaderStat(
                                    'Pajak',
                                    CurrencyFormatter.format(
                                        widget.cart.taxAmount)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Scrollable Content ───────────────────────────────────
        Expanded(
          child: SlideTransition(
            position: _slideAnimation,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // Metode Pembayaran Label
                _buildSectionLabel('Pilih Metode Pembayaran', Icons.payment_rounded),
                const SizedBox(height: 6),
                _buildPaymentMethodGrid(),
                const SizedBox(height: 14),

                // Detail input pembayaran
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _paymentMethod == 'cash'
                      ? Column(
                          key: const ValueKey('cash_section'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionLabel('Detail Tunai', Icons.payments_outlined),
                            const SizedBox(height: 6),
                            _buildCashPaymentCard(),
                            const SizedBox(height: 14),
                          ],
                        )
                      : _paymentMethod == 'multi'
                          ? Column(
                              key: const ValueKey('multi_section'),
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionLabel('Rincian Split Payment', Icons.pie_chart_outline_rounded),
                                const SizedBox(height: 6),
                                _buildSplitPaymentCard(),
                                const SizedBox(height: 14),
                              ],
                            )
                          : _buildNonCashInfo(),
                ),

                // Poin Pelanggan
                if (_pointsSettings['enabled'] == 1 && widget.cart.selectedCustomer != null)
                  _buildPointsCard(),
                const SizedBox(height: 12),

                // Catatan Transaksi
                _buildSectionLabel('Catatan Transaksi', Icons.edit_note_rounded),
                const SizedBox(height: 6),
                _buildNotesCard(),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // ── Action Button ────────────────────────────────────────
        _buildCheckoutButton(),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 📟 TABLET DUAL-PANE PAYMENT LAYOUT (>= 720px)
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildTabletLayout() {
    return SafeArea(
      child: Column(
        children: [
          // Tablet Header Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 8, 20, 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF0F172A), size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pembayaran Transaksi',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Kasir: ${widget.user.name} • Sesi #${widget.session.id}',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined,
                          size: 14, color: Color(0xFF0F172A)),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.cart.items.length} Item di Keranjang',
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF0F172A),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFFE2E8F0)),

          // Main Tablet Body
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── LEFT COLUMN: Total & Invoice Breakdown (Flex: 45) ──
                      Expanded(
                        flex: 45,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Total Tagihan Slate Card
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF0F172A).withValues(alpha: 0.2),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'TOTAL TAGIHAN PEMBAYARAN',
                                      style: GoogleFonts.poppins(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    ScaleTransition(
                                      scale: _pulseAnimation,
                                      child: Text(
                                        CurrencyFormatter.format(widget.cart.grandTotal),
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildHeaderStat('Subtotal', CurrencyFormatter.format(widget.cart.subtotal)),
                                          if (widget.cart.discountAmount > 0)
                                            _buildHeaderStat('Diskon', '-${CurrencyFormatter.format(widget.cart.discountAmount)}'),
                                          if (widget.cart.taxAmount > 0)
                                            _buildHeaderStat('Pajak', CurrencyFormatter.format(widget.cart.taxAmount)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Order Items List Card
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Rincian Pesanan',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (widget.cart.selectedCustomer != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.person_rounded, size: 12, color: Color(0xFF2563EB)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  widget.cart.selectedCustomer!.name,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(0xFF2563EB),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Divider(height: 20, color: Color(0xFFF1F5F9)),
                                    ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: widget.cart.items.length,
                                      separatorBuilder: (_, __) => const Divider(height: 16, color: Color(0xFFF8FAFC)),
                                      itemBuilder: (context, idx) {
                                        final item = widget.cart.items[idx];
                                        return Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    item.product.name,
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: const Color(0xFF0F172A),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  Text(
                                                    '${item.quantity.toString().replaceAll(RegExp(r'\.?0+$'), '')} ${item.unit.name} × ${CurrencyFormatter.format(item.price)}',
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 11,
                                                      color: const Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              CurrencyFormatter.format(item.subtotal),
                                              style: GoogleFonts.poppins(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                                color: const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // ── RIGHT COLUMN: Payment Method & Input Form (Flex: 55) ──
                      Expanded(
                        flex: 55,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Metode Pembayaran Label
                              _buildSectionLabel('Pilih Metode Pembayaran', Icons.payment_rounded),
                              const SizedBox(height: 8),
                              _buildPaymentMethodGrid(),
                              const SizedBox(height: 16),

                              // Detail input pembayaran
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: _paymentMethod == 'cash'
                                    ? Column(
                                        key: const ValueKey('cash_section_tablet'),
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildSectionLabel('Detail Tunai', Icons.payments_outlined),
                                          const SizedBox(height: 6),
                                          _buildCashPaymentCard(),
                                          const SizedBox(height: 16),
                                        ],
                                      )
                                    : _paymentMethod == 'multi'
                                        ? Column(
                                            key: const ValueKey('multi_section_tablet'),
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              _buildSectionLabel('Rincian Split Payment', Icons.pie_chart_outline_rounded),
                                              const SizedBox(height: 6),
                                              _buildSplitPaymentCard(),
                                              const SizedBox(height: 16),
                                            ],
                                          )
                                        : _buildNonCashInfo(),
                              ),

                              // Poin Pelanggan
                              if (_pointsSettings['enabled'] == 1 && widget.cart.selectedCustomer != null) ...[
                                _buildPointsCard(),
                                const SizedBox(height: 16),
                              ],

                              // Catatan Transaksi
                              _buildSectionLabel('Catatan Transaksi', Icons.edit_note_rounded),
                              const SizedBox(height: 6),
                              _buildNotesCard(),
                              const SizedBox(height: 20),

                              // Action Button on Tablet
                              _buildCheckoutButtonInline(),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildHeaderStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppConstants.primaryColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppConstants.textLightColor,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodGrid() {
    return SizedBox(
      height: 54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _paymentMethods.length,
        itemBuilder: (context, index) {
          final m = _paymentMethods[index];
          final id = m['id'] as String;
          final isSel = _paymentMethod == id;
          final isDebtDisabled = id == 'debt' && widget.cart.selectedCustomer == null;

          return GestureDetector(
            onTap: () {
              if (isDebtDisabled) {
                HapticFeedback.heavyImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Silakan pilih pelanggan terlebih dahulu untuk transaksi Bon!'),
                    backgroundColor: AppConstants.errorColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
                return;
              }
              HapticFeedback.selectionClick();
              setState(() {
                _paymentMethod = id;
                _calculateChange();
              });
            },
            child: Opacity(
              opacity: isDebtDisabled ? 0.45 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 114,
                margin: EdgeInsets.only(
                  right: index < _paymentMethods.length - 1 ? 8 : 0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSel ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    width: isSel ? 1.5 : 1.0,
                  ),
                  boxShadow: isSel
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      m['icon'] as IconData,
                      size: 18,
                      color: isSel ? Colors.white : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            m['label'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            m['sublabel'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: isSel ? Colors.white70 : const Color(0xFF94A3B8),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCashPaymentCard() {
    final suggestions = _getCashSuggestions();
    final isInsufficient =
        _amountPaid < widget.cart.grandTotal && _amountPaid > 0;
    final hasChange = _changeAmount > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.borderLightColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Input nominal
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uang Diterima',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppConstants.textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isInsufficient
                          ? AppConstants.errorColor
                          : AppConstants.borderLightColor,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isInsufficient
                              ? AppConstants.errorColor.withValues(alpha: 0.1)
                              : AppConstants.primaryColor.withValues(alpha: 0.08),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(9),
                            bottomLeft: Radius.circular(9),
                          ),
                        ),
                        child: Text(
                          'Rp',
                          style: GoogleFonts.poppins(
                            color: isInsufficient
                                ? AppConstants.errorColor
                                : AppConstants.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _amountPaidController,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [
                            _NumberInputFormatter(),
                          ],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDarkColor,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(horizontal: 14),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _amountPaid = double.tryParse(
                                    val.replaceAll('.', ''),
                                  ) ??
                                  0.0;
                              _calculateChange();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Nominal Cepat
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nominal Cepat',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppConstants.textLightColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: suggestions.asMap().entries.map((entry) {
                    final s = entry.value;
                    final isPas = s == widget.cart.grandTotal;
                    final isSelected = _amountPaid == s;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: entry.key < suggestions.length - 1 ? 6 : 0),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _amountPaid = s;
                              _amountPaidController.text =
                                  _formatNumber(s.toStringAsFixed(0));
                              _calculateChange();
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF0F172A)
                                  : isPas
                                      ? const Color(0xFF0F172A).withValues(alpha: 0.05)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0F172A)
                                    : isPas
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFE2E8F0),
                                width: isSelected || isPas ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              children: [
                                if (isPas)
                                  Text(
                                    'UANG PAS',
                                    style: GoogleFonts.poppins(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? Colors.white70 : const Color(0xFF0F172A),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                Text(
                                  _shortFormat(s),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Kembalian
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: hasChange
                  ? AppConstants.successColor.withValues(alpha: 0.08)
                  : isInsufficient
                      ? AppConstants.errorColor.withValues(alpha: 0.08)
                      : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hasChange
                    ? AppConstants.successColor.withValues(alpha: 0.2)
                    : isInsufficient
                        ? AppConstants.errorColor.withValues(alpha: 0.2)
                        : AppConstants.borderLightColor,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasChange
                          ? Icons.check_circle_outline_rounded
                          : isInsufficient
                              ? Icons.error_outline_rounded
                              : Icons.info_outline_rounded,
                      size: 18,
                      color: hasChange
                          ? AppConstants.successColor
                          : isInsufficient
                              ? AppConstants.errorColor
                              : AppConstants.textLightColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasChange
                          ? 'Kembalian'
                          : isInsufficient
                              ? 'Kekurangan'
                              : 'Kembalian',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: hasChange
                            ? AppConstants.successColor
                            : isInsufficient
                                ? AppConstants.errorColor
                                : AppConstants.textLightColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  hasChange
                      ? CurrencyFormatter.format(_changeAmount)
                      : isInsufficient
                          ? '- ${CurrencyFormatter.format(widget.cart.grandTotal - _amountPaid)}'
                          : CurrencyFormatter.format(0),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasChange
                        ? AppConstants.successColor
                        : isInsufficient
                            ? AppConstants.errorColor
                            : AppConstants.textDarkColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNonCashInfo() {
    final methodLabel = _selectedMethod['label'] as String;
    final methodIcon = _selectedMethod['icon'] as IconData;
    final isDebt = _paymentMethod == 'debt';

    return Column(
      key: const ValueKey('non_cash_section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDebt ? Colors.orange.shade200 : AppConstants.borderLightColor,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (isDebt ? Colors.orange : AppConstants.primaryColor).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      methodIcon,
                      color: isDebt ? Colors.orange.shade800 : AppConstants.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDebt ? 'Pembayaran Sistem Bon (Piutang)' : 'Pembayaran via $methodLabel',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        Text(
                          isDebt
                              ? 'Tagihan sebesar ${CurrencyFormatter.format(widget.cart.grandTotal)} akan dicatat sebagai piutang pelanggan ${widget.cart.selectedCustomer?.name}.'
                              : 'Tagihan dibayar penuh secara non-tunai. Tanpa kembalian.',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppConstants.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isDebt) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppConstants.borderLightColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Uang Muka (DP)',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppConstants.textDarkColor,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppConstants.borderLightColor),
                        ),
                        child: TextField(
                          controller: _amountPaidController,
                          keyboardType: TextInputType.number,
                          inputFormatters: const [
                            _NumberInputFormatter(),
                          ],
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.textDarkColor,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            prefixText: 'Rp ',
                            prefixStyle: GoogleFonts.poppins(
                              color: AppConstants.textLightColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _amountPaid = double.tryParse(
                                    val.replaceAll('.', ''),
                                  ) ??
                                  0.0;
                              if (_amountPaid > widget.cart.grandTotal) {
                                _amountPaid = widget.cart.grandTotal;
                                _amountPaidController.text =
                                    _formatNumber(
                                  _amountPaid.toStringAsFixed(0),
                                );
                                _amountPaidController.selection =
                                    TextSelection.fromPosition(
                                  TextPosition(
                                    offset:
                                        _amountPaidController.text.length,
                                  ),
                                );
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sisa Piutang:',
                      style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                    ),
                    Text(
                      CurrencyFormatter.format(widget.cart.grandTotal - _amountPaid),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _buildSplitPaymentCard() {
    final grandTotal = widget.cart.grandTotal;
    final totalPaid = _totalSplitPaid;
    final remaining = grandTotal - totalPaid;
    final isExact = (totalPaid - grandTotal).abs() < 0.01;
    final isOver = totalPaid > grandTotal;
    final isUnder = remaining > 0.01;

    // Pilihan metode untuk pembayaran split
    final splitMethodOptions = [
      {'id': 'cash', 'label': 'Tunai', 'icon': Icons.payments_rounded},
      {'id': 'qris', 'label': 'QRIS', 'icon': Icons.qr_code_scanner_rounded},
      {'id': 'card', 'label': 'Kartu EDC', 'icon': Icons.credit_card_rounded},
      {'id': 'transfer', 'label': 'Transfer', 'icon': Icons.account_balance_rounded},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExact
              ? const Color(0xFF059669).withValues(alpha: 0.3)
              : (isOver
                  ? const Color(0xFF2563EB).withValues(alpha: 0.3)
                  : const Color(0xFFD97706).withValues(alpha: 0.3)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Status Split
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isExact
                  ? const Color(0xFFECFDF5)
                  : (isOver ? const Color(0xFFEFF6FF) : const Color(0xFFFFFBEB)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExact
                    ? const Color(0xFFA7F3D0)
                    : (isOver ? const Color(0xFFBFDBFE) : const Color(0xFFFDE68A)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isExact
                      ? Icons.check_circle_rounded
                      : (isOver ? Icons.info_rounded : Icons.pending_rounded),
                  color: isExact
                      ? const Color(0xFF059669)
                      : (isOver ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isExact
                            ? 'Pembayaran Pas Terpenuhi'
                            : (isOver ? 'Kelebihan Pembayaran (Kembalian)' : 'Sisa Belum Terbayar'),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        isExact
                            ? 'Rp 0'
                            : (isOver
                                ? CurrencyFormatter.format(totalPaid - grandTotal)
                                : CurrencyFormatter.format(remaining)),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isExact
                              ? const Color(0xFF059669)
                              : (isOver ? const Color(0xFF2563EB) : const Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${CurrencyFormatter.format(totalPaid)} / ${CurrencyFormatter.format(grandTotal)}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // List Tiap Baris Metode Split
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _splitPayments.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, idx) {
              final item = _splitPayments[idx];
              final currentMethod = item['method'] as String? ?? 'cash';
              final currentAmount = item['amount'] as double? ?? 0.0;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Badge Nomor Bagian
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${idx + 1}',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Dropdown Pilih Metode
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: currentMethod,
                                isDense: true,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded,
                                    color: Color(0xFF64748B), size: 20),
                                items: splitMethodOptions.map((opt) {
                                  return DropdownMenuItem<String>(
                                    value: opt['id'] as String,
                                    child: Row(
                                      children: [
                                        Icon(opt['icon'] as IconData,
                                            size: 16,
                                            color: const Color(0xFF0F172A)),
                                        const SizedBox(width: 8),
                                        Text(
                                          opt['label'] as String,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _splitPayments[idx]['method'] = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tombol Hapus Baris (hanya jika lebih dari 1 baris)
                        if (_splitPayments.length > 1)
                          InkWell(
                            onTap: () {
                              setState(() {
                                _splitPayments.removeAt(idx);
                                _calculateChange();
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(Icons.delete_outline_rounded,
                                  color: AppConstants.errorColor, size: 20),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Input Nominal untuk baris ini
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'Rp ',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('split_amount_${idx}_${_splitPayments.length}'),
                                    initialValue: currentAmount > 0
                                        ? _formatNumber(currentAmount.toStringAsFixed(0))
                                        : '',
                                    keyboardType: TextInputType.number,
                                    inputFormatters: const [_NumberInputFormatter()],
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: const Color(0xFF0F172A),
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: '0',
                                      hintStyle: GoogleFonts.poppins(
                                        color: const Color(0xFF94A3B8),
                                        fontSize: 13,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      final raw = val.replaceAll('.', '');
                                      final parsed = double.tryParse(raw) ?? 0.0;
                                      setState(() {
                                        _splitPayments[idx]['amount'] = parsed;
                                        _calculateChange();
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tombol Pintas "Isi Sisa"
                        if (isUnder && remaining > 0)
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _splitPayments[idx]['amount'] = currentAmount + remaining;
                                _calculateChange();
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              '+ Sisa',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // Tombol Tambah Metode Pembayaran Lainnya
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                final unassigned = remaining > 0 ? remaining : 0.0;
                // Pilih default method berikutnya
                final usedMethods = _splitPayments.map((p) => p['method']).toSet();
                String nextMethod = 'card';
                for (var opt in splitMethodOptions) {
                  if (!usedMethods.contains(opt['id'])) {
                    nextMethod = opt['id'] as String;
                    break;
                  }
                }
                _splitPayments.add({
                  'method': nextMethod,
                  'amount': unassigned,
                  'referenceId': null,
                });
                _calculateChange();
              });
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              'Tambah Metode Lain',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.borderLightColor),
      ),
      child: TextField(
        controller: _notesController,
        maxLines: 1,
        style: GoogleFonts.poppins(fontSize: 13, color: AppConstants.textDarkColor),
        decoration: InputDecoration(
          hintText: 'Catatan transaksi (opsional)...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: AppConstants.textLightColor,
          ),
          prefixIcon: const Icon(Icons.edit_note_rounded,
              color: AppConstants.textLightColor, size: 22),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
          ),
          child: _buildCheckoutButtonInline(),
        ),
      ),
    );
  }

  Widget _buildCheckoutButtonInline() {
    return BlocBuilder<SalesCubit, SalesState>(
      builder: (context, state) {
        final isLoading = state is SalesLoading;
        return SizedBox(
          height: 50,
          width: double.infinity,
          child: FilledButton(
            onPressed: isLoading ? null : _checkout,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'KONFIRMASI PEMBAYARAN',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPointsCard() {
    final earnRate = _pointsSettings['earnRate'] ?? 1000;
    final redeemValue = _pointsSettings['redeemValue'] ?? 10;
    final minRedeem = _pointsSettings['minRedeem'] ?? 100;
    final pointsEarnEstimate = widget.cart.grandTotal >= earnRate
        ? (widget.cart.grandTotal ~/ earnRate)
        : 0;
    final maxRedeemable = _customerPointsBalance;
    final canRedeem = maxRedeemable >= minRedeem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Poin Pelanggan', Icons.card_giftcard_rounded),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConstants.borderLightColor),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppConstants.warningColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded,
                        color: AppConstants.warningColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cart.selectedCustomer?.name ?? '',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        Text(
                          'Saldo poin: $_customerPointsBalance poin',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppConstants.textLightColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.primaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '+$pointsEarnEstimate poin',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (canRedeem) ...[
                const SizedBox(height: 12),
                Divider(color: AppConstants.borderLightColor, height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Tukar poin:',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: AppConstants.textLightColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 100,
                      height: 36,
                      child: TextField(
                        controller: _redeemPointsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: const [
                          _NumberInputFormatter(),
                        ],
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppConstants.textDarkColor,
                        ),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: AppConstants.backgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          hintText: '0',
                          hintStyle: GoogleFonts.poppins(fontSize: 12),
                        ),
                        onChanged: (val) {
                          final raw = val.replaceAll('.', '');
                          final points = int.tryParse(raw) ?? 0;
                          final clamped = points > maxRedeemable
                              ? maxRedeemable
                              : (points < 0 ? 0 : points);
                          final disc = clamped >= minRedeem
                              ? (clamped * redeemValue).toDouble()
                              : 0.0;
                          if (clamped != points) {
                            final clampedStr = clamped.toString();
                            _redeemPointsController.value = TextEditingValue(
                              text: clamped == 0 ? '' : _formatNumber(clampedStr),
                              selection: TextSelection.collapsed(
                                offset: clamped == 0 ? 0 : _formatNumber(clampedStr).length,
                              ),
                            );
                          }
                          setState(() {
                            _pointsRedeemed = clamped;
                            _pointsDiscount = disc;
                          });
                        },
                      ),
                    ),
                    const Spacer(),
                    if (_pointsRedeemed > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppConstants.successColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '-${CurrencyFormatter.format(_pointsDiscount)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppConstants.successColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _shortFormat(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(value % 1000000 == 0 ? 0 : 1)}jt';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}rb';
    }
    return value.toStringAsFixed(0);
  }

  String _formatNumber(String digits) {
    if (digits.isEmpty) return '';
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}

class _NumberInputFormatter extends TextInputFormatter {
  const _NumberInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = _formatNumber(digitsOnly);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatNumber(String digits) {
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(digits[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }
}
