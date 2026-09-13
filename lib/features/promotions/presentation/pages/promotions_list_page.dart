import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/promotion_cubit.dart';
import 'promotion_form_page.dart';

class PromotionsListPage extends StatefulWidget {
  const PromotionsListPage({super.key});

  @override
  State<PromotionsListPage> createState() => _PromotionsListPageState();
}

class _PromotionsListPageState extends State<PromotionsListPage> {
  String _selectedFilter = 'all'; // all, active, inactive, expired

  @override
  void initState() {
    super.initState();
    context.read<PromotionCubit>().loadPromotions();
  }

  String _getPromoTypeLabel(String type) {
    switch (type) {
      case 'buy_x_get_y':
        return 'Beli X Gratis Y (BOGO)';
      case 'min_purchase_discount':
        return 'Diskon Min. Belanja';
      case 'product_discount':
        return 'Diskon Spesial Produk';
      case 'purchase_with_purchase':
        return 'Tebus Murah (PWP)';
      default:
        return 'Promosi Diskon';
    }
  }

  Color _getPromoTypeColor(String type) {
    switch (type) {
      case 'buy_x_get_y':
        return const Color(0xFFE11D48); // Rose
      case 'min_purchase_discount':
        return const Color(0xFF2563EB); // Royal Blue
      case 'product_discount':
        return const Color(0xFF7C3AED); // Purple
      case 'purchase_with_purchase':
        return const Color(0xFFD97706); // Amber
      default:
        return const Color(0xFF475569);
    }
  }

  IconData _getPromoTypeIcon(String type) {
    switch (type) {
      case 'buy_x_get_y':
        return Icons.card_giftcard_rounded;
      case 'min_purchase_discount':
        return Icons.payments_rounded;
      case 'product_discount':
        return Icons.percent_rounded;
      case 'purchase_with_purchase':
        return Icons.stars_rounded;
      default:
        return Icons.local_offer_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Program Promosi & Diskon',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: const Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PromotionFormPage()),
          );
        },
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: Text(
          'Buat Promo Baru',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'Semua Promo'),
                  const SizedBox(width: 8),
                  _buildFilterChip('active', 'Sedang Berjalan'),
                  const SizedBox(width: 8),
                  _buildFilterChip('inactive', 'Nonaktif'),
                  const SizedBox(width: 8),
                  _buildFilterChip('expired', 'Sudah Berakhir'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppConstants.borderLightColor),

          // List Promosi
          Expanded(
            child: BlocBuilder<PromotionCubit, PromotionState>(
              builder: (context, state) {
                if (state.status == PromotionStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (state.status == PromotionStatus.error) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48, color: AppConstants.errorColor),
                        const SizedBox(height: 12),
                        Text(
                          state.errorMessage ?? 'Terjadi kesalahan',
                          style: GoogleFonts.poppins(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: () => context.read<PromotionCubit>().loadPromotions(),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final promotions = state.promotions.where((p) {
                  final isCurrentlyActive = p.isActive && p.startDate.isBefore(now) && p.endDate.isAfter(now);
                  final isExpired = p.endDate.isBefore(now);

                  if (_selectedFilter == 'active') return isCurrentlyActive;
                  if (_selectedFilter == 'inactive') return !p.isActive;
                  if (_selectedFilter == 'expired') return isExpired;
                  return true;
                }).toList();

                if (promotions.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppConstants.primaryColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.local_offer_outlined,
                                size: 40, color: AppConstants.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Belum Ada Program Promosi',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Buat program promo seperti Beli 1 Gratis 1, Diskon Min. Belanja, atau Tebus Murah ala ritel modern untuk meningkatkan penjualan toko Anda.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const PromotionFormPage()),
                              );
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(
                              'Buat Promo Pertama',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: promotions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final promo = promotions[index];
                    final isCurrentlyActive = promo.isActive &&
                        promo.startDate.isBefore(now) &&
                        promo.endDate.isAfter(now);
                    final isExpired = promo.endDate.isBefore(now);
                    final typeColor = _getPromoTypeColor(promo.type);
                    final typeIcon = _getPromoTypeIcon(promo.type);

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentlyActive
                              ? AppConstants.primaryColor.withValues(alpha: 0.3)
                              : AppConstants.borderLightColor,
                          width: isCurrentlyActive ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Card
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                            child: Row(
                              children: [
                                // Tipe Badge
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(typeIcon, size: 13, color: typeColor),
                                        const SizedBox(width: 5),
                                        Flexible(
                                          child: Text(
                                            _getPromoTypeLabel(promo.type),
                                            style: GoogleFonts.poppins(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: typeColor,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Status Switch
                                Switch(
                                  value: promo.isActive,
                                  activeThumbColor: AppConstants.primaryColor,
                                  onChanged: (val) {
                                    context.read<PromotionCubit>().toggleActive(promo.id, val);
                                  },
                                ),

                                // Menu Popup (Edit, Delete)
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  onSelected: (action) {
                                    if (action == 'edit') {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => PromotionFormPage(promotion: promo),
                                        ),
                                      );
                                    } else if (action == 'delete') {
                                      _showDeleteDialog(promo);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF0F172A)),
                                          const SizedBox(width: 8),
                                          Text('Edit Promo', style: GoogleFonts.poppins(fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          const Icon(Icons.delete_outline_rounded, size: 18, color: AppConstants.errorColor),
                                          const SizedBox(width: 8),
                                          Text('Hapus', style: GoogleFonts.poppins(fontSize: 13, color: AppConstants.errorColor)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Nama & Kode Promo
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  promo.name,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                if (promo.code.isNotEmpty && !promo.code.startsWith('AUTO_')) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFCBD5E1)),
                                    ),
                                    child: Text(
                                      'KODE: ${promo.code}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                        color: const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1, color: Color(0xFFF1F5F9)),

                          // Footer Info (Periode & Status)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const Icon(Icons.date_range_rounded, size: 14, color: Colors.grey),
                                const SizedBox(width: 6),
                                Text(
                                  '${dateFormat.format(promo.startDate)} - ${dateFormat.format(promo.endDate)}',
                                  style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade700),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isExpired
                                        ? Colors.red.shade50
                                        : (isCurrentlyActive ? Colors.green.shade50 : Colors.grey.shade100),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isExpired
                                        ? 'Berakhir'
                                        : (isCurrentlyActive ? 'Aktif' : 'Nonaktif'),
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isExpired
                                          ? Colors.red.shade700
                                          : (isCurrentlyActive ? Colors.green.shade700 : Colors.grey.shade600),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(Promotion promo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Hapus Program Promo?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          'Apakah Anda yakin ingin menghapus promo "${promo.name}"? Data yang dihapus tidak dapat dikembalikan.',
          style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey.shade700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.read<PromotionCubit>().deletePromotion(promo.id);
            },
            child: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
