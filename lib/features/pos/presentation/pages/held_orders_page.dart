import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/widgets/curved_header.dart';
import '../../data/sales_repository.dart';
import '../bloc/cart_cubit.dart';

class HeldOrdersPage extends StatefulWidget {
  final User user;
  final List<Map<String, dynamic>> allProducts;
  final List<Customer> allCustomers;

  const HeldOrdersPage({
    super.key,
    required this.user,
    required this.allProducts,
    required this.allCustomers,
  });

  @override
  State<HeldOrdersPage> createState() => _HeldOrdersPageState();
}

class _HeldOrdersPageState extends State<HeldOrdersPage> {
  List<PosHeldOrder> _heldOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHeldOrders();
  }

  Future<void> _loadHeldOrders() async {
    setState(() => _isLoading = true);
    try {
      final orders = await getIt<SalesRepository>().getHeldOrders(widget.user.id);
      setState(() {
        _heldOrders = orders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteHeld(int id) async {
    try {
      await getIt<SalesRepository>().deleteHeldOrder(id);
      _loadHeldOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaksi ditahan berhasil dihapus.')),
        );
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.backgroundColor,
      body: Stack(
        children: [
          const CurvedHeader(height: 155),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Text(
                        'Transaksi Ditahan (Hold)',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _heldOrders.isEmpty
                          ? Center(
                              child: Text(
                                'Tidak ada transaksi ditahan.',
                                style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _heldOrders.length,
                              itemBuilder: (context, index) {
                                final order = _heldOrders[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                                    side: const BorderSide(color: AppConstants.borderLightColor),
                                  ),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppConstants.warningColor,
                                      child: Icon(Icons.pause_circle_filled_rounded,
                                          color: Colors.white),
                                    ),
                                    title: Text(
                                      order.referenceNo,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: AppConstants.textDarkColor,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'Tahan pada: ${order.createdAt.toString().substring(0, 16)}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () {
                                            context.read<CartCubit>().recallCart(
                                                  order,
                                                  widget.allProducts,
                                                  widget.allCustomers,
                                                );
                                            _deleteHeld(order.id);
                                            Navigator.pop(context);
                                          },
                                          style: ElevatedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 8),
                                            minimumSize: Size.zero,
                                          ),
                                          child: const Text('RECALL'),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.delete_rounded,
                                              color: Colors.redAccent),
                                          onPressed: () => _deleteHeld(order.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
