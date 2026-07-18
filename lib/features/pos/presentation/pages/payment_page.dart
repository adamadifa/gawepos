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

  const PaymentPage({
    super.key,
    required this.user,
    required this.session,
    required this.cart,
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
      'id': 'debt',
      'label': 'Bon',
      'sublabel': 'Bon / Piutang',
      'icon': Icons.assignment_late_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _amountPaid = widget.cart.grandTotal;
    _amountPaidController.text = _formatNumber(_amountPaid.toStringAsFixed(0));
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

  void _calculateChange() {
    setState(() {
      if (_paymentMethod == 'debt') {
        _changeAmount = 0.0;
        // Let _amountPaid be whatever user typed for DP, default to 0.0 initially
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

    HapticFeedback.mediumImpact();
    final cartItemsMap = widget.cart.items.map((item) {
      return {
        'product': item.product,
        'unit': item.unit,
        'quantity': item.quantity,
        'price': item.price,
        'discountAmount': item.discountAmount,
        'appliedMinQty': item.appliedMinQty,
      };
    }).toList();

    final paymentsMap = [
      if (_paymentMethod == 'debt') ...[
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
      ] else
        {
          'method': _paymentMethod,
          'amount': widget.cart.grandTotal,
          'referenceId': null,
        }
    ];

    final effectiveGrandTotal = widget.cart.grandTotal;
    final earnRate = _pointsSettings['earnRate'] ?? 1000;
    final actualPaid = _paymentMethod == 'debt'
        ? _amountPaid
        : (_paymentMethod == 'cash' ? _amountPaid : effectiveGrandTotal);
    final pointsEarned = actualPaid >= earnRate ? (actualPaid ~/ earnRate) : 0;

    context.read<SalesCubit>().checkout(
          userId: widget.user.id,
          cashierSessionId: widget.session.id,
          subtotal: widget.cart.subtotal,
          discountAmount: widget.cart.discountAmount,
          taxAmount: widget.cart.taxAmount,
          grandTotal: effectiveGrandTotal,
          paidAmount: actualPaid,
          changeAmount: _changeAmount,
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
    return BlocListener<SalesCubit, SalesState>(
      listener: (context, state) {
        if (state is SalesSuccess) {
          final earnRate = _pointsSettings['earnRate'] ?? 1000;
          final actualPaid = _paymentMethod == 'debt'
              ? _amountPaid
              : (_paymentMethod == 'cash' ? _amountPaid : widget.cart.grandTotal);
          final earned = actualPaid >= earnRate ? (actualPaid ~/ earnRate) : 0;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentSuccessPage(
                orderId: state.orderId,
                user: widget.user,
                session: widget.session,
                cart: widget.cart,
                pointsEarned: earned,
                pointsRedeemed: _pointsRedeemed,
              ),
            ),
          );
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
        backgroundColor: AppConstants.backgroundColor,
        body: Column(
          children: [
            // ── Header Ringkas & Formal ──────────────────────────────────
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppConstants.primaryColor,
                    AppConstants.primaryDarkColor,
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryColor.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                                color: Colors.white, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Text(
                            'Pembayaran',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Badge Detail
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shopping_bag_outlined,
                                    size: 13, color: Colors.white),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.cart.items.length} Item',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 12,
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
                              'Total Tagihan',
                              style: GoogleFonts.poppins(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
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
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
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
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
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
        ),
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
                  color: isSel ? AppConstants.primaryColor.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSel ? AppConstants.primaryColor : AppConstants.borderLightColor,
                    width: isSel ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.01),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      m['icon'] as IconData,
                      size: 18,
                      color: isSel ? AppConstants.primaryColor : AppConstants.textLightColor,
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
                              color: isSel ? AppConstants.primaryColor : AppConstants.textDarkColor,
                            ),
                          ),
                          Text(
                            m['sublabel'] as String,
                            style: GoogleFonts.poppins(
                              fontSize: 9,
                              color: AppConstants.textLightColor,
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
                                  ? AppConstants.primaryColor
                                  : isPas
                                      ? AppConstants.successColor.withValues(alpha: 0.08)
                                      : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isSelected
                                    ? AppConstants.primaryColor
                                    : isPas
                                        ? AppConstants.successColor
                                        : AppConstants.borderLightColor,
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isPas ? 'Uang Pas' : _shortFormat(s),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : isPas
                                            ? AppConstants.successColor
                                            : AppConstants.textDarkColor,
                                  ),
                                  textAlign: TextAlign.center,
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
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: AppConstants.borderLightColor, width: 1),
            ),
          ),
          child: BlocBuilder<SalesCubit, SalesState>(
            builder: (context, state) {
              final isLoading = state is SalesLoading;
              return GestureDetector(
                onTap: isLoading ? null : _checkout,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isLoading
                          ? [
                              AppConstants.primaryColor.withValues(alpha: 0.7),
                              AppConstants.primaryDarkColor.withValues(alpha: 0.7),
                            ]
                          : [
                              AppConstants.primaryColor,
                              AppConstants.primaryDarkColor,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isLoading
                        ? []
                        : [
                            BoxShadow(
                              color: AppConstants.primaryColor.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
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
                        const Icon(Icons.check_circle_outline_rounded,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Proses Pembayaran',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          );
        },
      ),
    ),
      ),
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
