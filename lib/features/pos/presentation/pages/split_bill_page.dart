import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../bloc/cart_cubit.dart';
import 'payment_page.dart';

class SplitBillPage extends StatefulWidget {
  final User user;
  final CashierSession session;
  final CartState originalCart;

  const SplitBillPage({
    super.key,
    required this.user,
    required this.session,
    required this.originalCart,
  });

  @override
  State<SplitBillPage> createState() => _SplitBillPageState();
}

class _SplitBillPageState extends State<SplitBillPage> {
  // Mode Split: 'items' (Pilih Item per Tagihan) atau 'equal' (Bagi Rata Nominal)
  String _splitMode = 'items';

  // --- State untuk Mode Bagi Rata (Equal Split) ---
  int _numberOfSplits = 2;
  final Set<int> _paidEqualBills = {};

  // --- State untuk Mode Per Item (Item Split) ---
  // List grup tagihan (Bill 1, Bill 2, dst.)
  // Setiap bill memiliki assigned item: key string "productId_unitId" -> quantity
  late List<Map<String, double>> _billAllocations;
  int _selectedBillIndex = 0;
  final Set<int> _paidItemBills = {};

  @override
  void initState() {
    super.initState();
    _initItemAllocations(2);
  }

  void _initItemAllocations(int count) {
    _billAllocations = List.generate(count, (_) => <String, double>{});
  }

  String _itemKey(CartItem item) => '${item.product.id}_${item.unit.id}';

  double _getAllocatedQty(CartItem item) {
    final key = _itemKey(item);
    double total = 0.0;
    for (var bill in _billAllocations) {
      total += bill[key] ?? 0.0;
    }
    return total;
  }

  double _getRemainingQty(CartItem item) {
    return item.quantity - _getAllocatedQty(item);
  }

  // Hitung total nilai untuk bill tertentu pada mode per-item
  double _calculateBillTotal(int billIndex) {
    final allocation = _billAllocations[billIndex];
    double subtotal = 0.0;
    for (var item in widget.originalCart.items) {
      final key = _itemKey(item);
      final qty = allocation[key] ?? 0.0;
      if (qty > 0) {
        subtotal += (qty * item.price) - (item.discountAmount * (qty / item.quantity));
      }
    }
    return subtotal;
  }

  // Buat CartState baru khusus untuk bill yang dipilih
  CartState _createCartForBill(int billIndex) {
    final allocation = _billAllocations[billIndex];
    final List<CartItem> billItems = [];

    for (var item in widget.originalCart.items) {
      final key = _itemKey(item);
      final qty = allocation[key] ?? 0.0;
      if (qty > 0) {
        final double itemDisc = item.discountAmount * (qty / item.quantity);
        billItems.add(item.copyWith(
          quantity: qty,
          discountAmount: itemDisc,
        ));
      }
    }

    final billSubtotal = billItems.fold(0.0, (sum, i) => sum + i.subtotal);
    final originalSubtotal = widget.originalCart.subtotal;
    final ratio = originalSubtotal > 0 ? (billSubtotal / originalSubtotal) : 0.0;

    return CartState(
      items: billItems,
      selectedCustomer: widget.originalCart.selectedCustomer,
      globalDiscount: widget.originalCart.globalDiscount * ratio,
      isGlobalDiscountPercentage: widget.originalCart.isGlobalDiscountPercentage,
      taxPercentage: widget.originalCart.taxPercentage,
    );
  }

  // Buat CartState untuk mode bagi rata dengan memecah item asli secara proporsional
  CartState _createEqualSplitCart(double amountPerPerson, int partNumber) {
    final splitRatio = 1.0 / _numberOfSplits;
    final List<CartItem> splitItems = [];

    for (var item in widget.originalCart.items) {
      final splitQty = item.quantity * splitRatio;
      final splitDisc = item.discountAmount * splitRatio;
      splitItems.add(item.copyWith(
        quantity: splitQty,
        discountAmount: splitDisc,
      ));
    }

    final globalDisc = widget.originalCart.globalDiscount * splitRatio;

    return CartState(
      items: splitItems,
      selectedCustomer: widget.originalCart.selectedCustomer,
      globalDiscount: globalDisc,
      isGlobalDiscountPercentage: widget.originalCart.isGlobalDiscountPercentage,
      taxPercentage: widget.originalCart.taxPercentage,
    );
  }

  // Update keranjang belanja utama berdasarkan sisa item yang belum dibayar
  void _syncRemainingCartToState() {
    final List<CartItem> remainingCartItems = [];
    
    for (var item in widget.originalCart.items) {
      final key = _itemKey(item);
      double paidQtyForItem = 0.0;
      
      for (int billIdx in _paidItemBills) {
        paidQtyForItem += _billAllocations[billIdx][key] ?? 0.0;
      }
      
      final double unPaidQty = item.quantity - paidQtyForItem;
      if (unPaidQty > 0.0001) {
        final double itemDisc = item.discountAmount * (unPaidQty / item.quantity);
        remainingCartItems.add(item.copyWith(
          quantity: unPaidQty,
          discountAmount: itemDisc,
        ));
      }
    }

    if (remainingCartItems.isEmpty) {
      context.read<CartCubit>().clearCart();
    } else {
      context.read<CartCubit>().replaceCart(
        widget.originalCart.copyWith(items: remainingCartItems),
      );
    }
  }

  Future<void> _payItemBill(int billIndex) async {
    final billCart = _createCartForBill(billIndex);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          user: widget.user,
          session: widget.session,
          cart: billCart,
          autoClearCart: false,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _paidItemBills.add(billIndex);
      });
      _syncRemainingCartToState();

      // Cek apakah semua tagihan sudah terbayar
      final allBillsAllocated = _billAllocations.asMap().entries.every((entry) {
        final total = _calculateBillTotal(entry.key);
        return total == 0 || _paidItemBills.contains(entry.key);
      });

      if (allBillsAllocated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua tagihan split bill telah selesai dibayar!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      } else {
        // Otomatis pindahkan fokus tab ke tagihan berikutnya yang belum lunas & memiliki nominal
        int nextUnpaidIndex = -1;
        for (int i = 0; i < _billAllocations.length; i++) {
          if (!_paidItemBills.contains(i) && _calculateBillTotal(i) > 0) {
            nextUnpaidIndex = i;
            break;
          }
        }
        if (nextUnpaidIndex == -1) {
          for (int i = 0; i < _billAllocations.length; i++) {
            if (!_paidItemBills.contains(i)) {
              nextUnpaidIndex = i;
              break;
            }
          }
        }
        if (nextUnpaidIndex != -1 && mounted) {
          setState(() {
            _selectedBillIndex = nextUnpaidIndex;
          });
        }
      }
    }
  }

  Future<void> _payEqualBill(int billNo, double amountPerPerson) async {
    final splitCart = _createEqualSplitCart(amountPerPerson, billNo);
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPage(
          user: widget.user,
          session: widget.session,
          cart: splitCart,
          autoClearCart: false,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {
        _paidEqualBills.add(billNo);
      });

      if (_paidEqualBills.length >= _numberOfSplits) {
        context.read<CartCubit>().clearCart();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua tagihan bagi rata telah selesai dibayar!'),
            backgroundColor: Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Split Bill (Pisah Tagihan)',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w700,
                fontSize: 16.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              'Total Nota: ${CurrencyFormatter.format(widget.originalCart.grandTotal)}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── MODE SELECTOR TAB ──
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_paidEqualBills.isNotEmpty && _splitMode != 'items') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak dapat beralih mode karena pembayaran bagi rata sudah berlangsung.'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        setState(() => _splitMode = 'items');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _splitMode == 'items' ? const Color(0xFF0F172A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Pisah Per Menu / Item',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: _splitMode == 'items' ? FontWeight.w700 : FontWeight.w500,
                              color: _splitMode == 'items' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_paidItemBills.isNotEmpty && _splitMode != 'equal') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tidak dapat beralih mode karena pembayaran pisah menu sudah berlangsung.'),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                          return;
                        }
                        setState(() => _splitMode = 'equal');
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _splitMode == 'equal' ? const Color(0xFF0F172A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            'Bagi Rata (Equal Split)',
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: _splitMode == 'equal' ? FontWeight.w700 : FontWeight.w500,
                              color: _splitMode == 'equal' ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(height: 1, color: const Color(0xFFE2E8F0)),

          // ── CONTENT BODY BASED ON MODE ──
          Expanded(
            child: _splitMode == 'items'
                ? _buildItemSplitView()
                : _buildEqualSplitView(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 1. VIEW: BAGI RATA (EQUAL SPLIT)
  // ══════════════════════════════════════════════════════════
  Widget _buildEqualSplitView() {
    final grandTotal = widget.originalCart.grandTotal;
    final amountPerPerson = grandTotal / _numberOfSplits;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Counter Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Text(
                  'Jumlah Orang / Pembagian',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filled(
                      onPressed: _numberOfSplits > 2
                          ? () => setState(() => _numberOfSplits--)
                          : null,
                      icon: const Icon(Icons.remove_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFF1F5F9),
                        disabledForegroundColor: const Color(0xFFCBD5E1),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        '$_numberOfSplits Orang',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _numberOfSplits < 20
                          ? () => setState(() => _numberOfSplits++)
                          : null,
                      icon: const Icon(Icons.add_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Nominal per Orang:',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF475569),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(amountPerPerson),
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // List of Sub-Bills ready to pay
          Expanded(
            child: ListView.builder(
              itemCount: _numberOfSplits,
              itemBuilder: (context, index) {
                final billNo = index + 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '#$billNo',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tagihan Orang ke-$billNo',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Nominal: ${CurrencyFormatter.format(amountPerPerson)}',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_paidEqualBills.contains(billNo))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  color: Color(0xFF059669), size: 16),
                              const SizedBox(width: 6),
                              Text(
                                'Lunas',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: const Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        FilledButton(
                          onPressed: () => _payEqualBill(billNo, amountPerPerson),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: Text(
                            'Bayar',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // 2. VIEW: PISAH PER MENU / ITEM
  // ══════════════════════════════════════════════════════════
  Widget _buildItemSplitView() {
    return Column(
      children: [
        // Sub-Bill Selector Tabs Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_billAllocations.length, (index) {
                      final isSelected = _selectedBillIndex == index;
                      final isPaid = _paidItemBills.contains(index);
                      final total = _calculateBillTotal(index);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          onTap: () => setState(() => _selectedBillIndex = index),
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isPaid
                                  ? const Color(0xFF059669).withValues(alpha: 0.1)
                                  : (isSelected ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isPaid
                                    ? const Color(0xFF059669).withValues(alpha: 0.4)
                                    : (isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0)),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Tagihan #${index + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isPaid
                                            ? const Color(0xFF059669)
                                            : (isSelected ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    if (isPaid) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle_rounded,
                                          color: Color(0xFF059669), size: 12),
                                    ],
                                  ],
                                ),
                                Text(
                                  isPaid ? 'Lunas' : CurrencyFormatter.format(total),
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isPaid
                                        ? const Color(0xFF059669)
                                        : (isSelected
                                            ? Colors.white.withValues(alpha: 0.8)
                                            : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0F172A)),
                tooltip: 'Tambah Tagihan Baru',
                onPressed: () {
                  setState(() {
                    _billAllocations.add(<String, double>{});
                    _selectedBillIndex = _billAllocations.length - 1;
                  });
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE2E8F0)),

        // Item List with Assignment Controls
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.originalCart.items.length,
            itemBuilder: (context, index) {
              final item = widget.originalCart.items[index];
              final key = _itemKey(item);
              final currentBillQty = _billAllocations[_selectedBillIndex][key] ?? 0.0;
              final remainingQty = _getRemainingQty(item);

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: currentBillQty > 0 ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                    width: currentBillQty > 0 ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${CurrencyFormatter.format(item.price)} / ${item.unit.name}',
                            style: GoogleFonts.poppins(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: remainingQty > 0
                                  ? const Color(0xFFD97706).withValues(alpha: 0.1)
                                  : const Color(0xFF059669).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              remainingQty > 0
                                  ? 'Sisa belum terbagi: ${CurrencyFormatter.formatQty(remainingQty)}'
                                  : 'Sudah terbagi semua',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: remainingQty > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Stepper Assign ke Tagihan Terpilih
                    Row(
                      children: [
                        IconButton(
                          onPressed: (currentBillQty > 0 && !_paidItemBills.contains(_selectedBillIndex))
                              ? () {
                                  setState(() {
                                    if (currentBillQty <= 1.0) {
                                      _billAllocations[_selectedBillIndex].remove(key);
                                    } else {
                                      _billAllocations[_selectedBillIndex][key] = currentBillQty - 1.0;
                                    }
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                          color: const Color(0xFF0F172A),
                          disabledColor: const Color(0xFFCBD5E1),
                        ),
                        Text(
                          CurrencyFormatter.formatQty(currentBillQty),
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          onPressed: (remainingQty > 0 && !_paidItemBills.contains(_selectedBillIndex))
                              ? () {
                                  setState(() {
                                    _billAllocations[_selectedBillIndex][key] = currentBillQty + 1.0;
                                  });
                                }
                              : null,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          color: const Color(0xFF0F172A),
                          disabledColor: const Color(0xFFCBD5E1),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        // Bottom Action Checkout Bill Terpilih
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'TOTAL TAGIHAN #${_selectedBillIndex + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(_calculateBillTotal(_selectedBillIndex)),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_paidItemBills.contains(_selectedBillIndex))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF059669), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Tagihan Ini Lunas',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  FilledButton.icon(
                    onPressed: _calculateBillTotal(_selectedBillIndex) > 0
                        ? () => _payItemBill(_selectedBillIndex)
                        : null,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(
                      'Bayar Tagihan Ini',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
