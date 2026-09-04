import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/database/app_database.dart';
import '../bloc/customer_cubit.dart';
import '../bloc/supplier_cubit.dart';

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<CustomerCubit>().loadCustomers();
    context.read<SupplierCubit>().loadSuppliers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Clean Header
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(6, 6, 12, 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Color(0xFF0F172A), size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Pelanggan & Pemasok',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF0F172A),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: const Color(0xFFE2E8F0)),
            
            // Segmented TabBar Container
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: const Color(0xFF0F172A),
                  unselectedLabelColor: const Color(0xFF64748B),
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(text: 'Daftar Pelanggan'),
                    Tab(text: 'Daftar Pemasok'),
                  ],
                ),
              ),
            ),

            // TabBar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _CustomerTabContent(),
                  _SupplierTabContent(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── CUSTOMER TAB CONTENT ───────────────────────────────────────────
class _CustomerTabContent extends StatelessWidget {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  void _showFormDialog(BuildContext context, {Customer? customer}) {
    if (customer != null) {
      _nameController.text = customer.name;
      _phoneController.text = customer.phone ?? '';
      _emailController.text = customer.email ?? '';
      _addressController.text = customer.address ?? '';
    } else {
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedName = customer != null;
        bool hasInteractedEmail = false;
        
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final nameText = _nameController.text.trim();
            final emailText = _emailController.text.trim();
            
            final isNameValid = nameText.isNotEmpty;
            final isEmailValid = emailText.isEmpty || 
                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailText);
            
            final isValid = isNameValid && isEmailValid;
            
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.person_rounded,
                                      color: Color(0xFF0F172A), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  customer == null ? 'Tambah Pelanggan' : 'Ubah Pelanggan',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Field: Nama Pelanggan
                        Text(
                          'Nama Pelanggan *',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Contoh: PT Sumber Makmur / Bpk. Budi',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.badge_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            errorText: (hasInteractedName && !isNameValid) ? 'Nama pelanggan wajib diisi' : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedName = true;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field: Nomor Telepon
                        Text(
                          'Nomor Telepon / WhatsApp',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 081234567890',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Field: Email
                        Text(
                          'Email (Opsional)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Contoh: pelanggan@gmail.com',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            errorText: (hasInteractedEmail && !isEmailValid) ? 'Format email tidak valid' : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedEmail = true;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field: Alamat
                        Text(
                          'Alamat Lengkap (Opsional)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _addressController,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Nama jalan, blok, RT/RW, kota...',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: const Color(0xFFE2E8F0),
                              disabledForegroundColor: const Color(0xFF94A3B8),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            onPressed: isValid
                                ? () {
                                    final name = _nameController.text.trim();
                                    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
                                    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
                                    final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
                                    
                                    if (customer == null) {
                                      context.read<CustomerCubit>().addCustomer(
                                        name: name,
                                        phone: phone,
                                        email: email,
                                        address: address,
                                      );
                                    } else {
                                      context.read<CustomerCubit>().editCustomer(
                                        customer,
                                        name: name,
                                        phone: phone,
                                        email: email,
                                        address: address,
                                      );
                                    }
                                    Navigator.pop(ctx);
                                  }
                                : null,
                            label: Text(
                              customer == null ? 'Simpan Pelanggan' : 'Perbarui Pelanggan',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Customer customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Pelanggan',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text('Apakah Anda yakin ingin menghapus pelanggan "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              context.read<CustomerCubit>().deleteCustomer(customer.id);
              Navigator.pop(ctx);
            },
            child: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAppSnackbar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<CustomerCubit, CustomerState>(
            listener: (context, state) {
              if (state is CustomerSaved) {
                _showAppSnackbar(
                  context,
                  state.isEdit
                      ? 'Data pelanggan "${state.customerName}" berhasil diperbarui.'
                      : 'Pelanggan "${state.customerName}" berhasil ditambahkan.',
                );
              } else if (state is CustomerDeleted) {
                _showAppSnackbar(
                  context,
                  'Pelanggan "${state.customerName}" berhasil dihapus.',
                );
              } else if (state is CustomerError) {
                _showAppSnackbar(context, state.message, isError: true);
              }
            },
            builder: (context, state) {
              if (state is CustomerLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is CustomerError) {
                return Center(child: Text(state.message));
              }
              if (state is CustomerLoaded) {
                final list = state.customers;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada pelanggan.',
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_rounded, color: Color(0xFF0F172A), size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.phone != null && item.phone!.isNotEmpty)
                              Text(
                                item.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            if (item.address != null && item.address!.isNotEmpty)
                              Text(
                                item.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, customer: item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF334155),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showDeleteDialog(context, item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
        
        // Add Button Bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _showFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Tambah Pelanggan',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── SUPPLIER TAB CONTENT ───────────────────────────────────────────
class _SupplierTabContent extends StatelessWidget {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  void _showFormDialog(BuildContext context, {Supplier? supplier}) {
    if (supplier != null) {
      _nameController.text = supplier.name;
      _phoneController.text = supplier.phone ?? '';
      _emailController.text = supplier.email ?? '';
      _addressController.text = supplier.address ?? '';
    } else {
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _addressController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedName = supplier != null;
        bool hasInteractedEmail = false;
        
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final nameText = _nameController.text.trim();
            final emailText = _emailController.text.trim();
            
            final isNameValid = nameText.isNotEmpty;
            final isEmailValid = emailText.isEmpty || 
                RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailText);
            
            final isValid = isNameValid && isEmailValid;
            
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Handle bar
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF059669).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.local_shipping_rounded,
                                      color: Color(0xFF059669), size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  supplier == null ? 'Tambah Pemasok' : 'Ubah Pemasok',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 20),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Field: Nama Pemasok
                        Text(
                          'Nama Pemasok / Distributor *',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Contoh: PT Pangan Sejahtera / CV Maju',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.storefront_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            errorText: (hasInteractedName && !isNameValid) ? 'Nama pemasok wajib diisi' : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedName = true;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field: Nomor Telepon
                        Text(
                          'Nomor Telepon / Sales',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Contoh: 082112345678',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Field: Email
                        Text(
                          'Email (Opsional)',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Contoh: sales@distributor.com',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.email_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            errorText: (hasInteractedEmail && !isEmailValid) ? 'Format email tidak valid' : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedEmail = true;
                            });
                          },
                        ),
                        const SizedBox(height: 14),

                        // Field: Alamat
                        Text(
                          'Alamat Kantor / Gudang Pemasok',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _addressController,
                          style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Kawasan industri, nama jalan, kota...',
                            hintStyle: GoogleFonts.poppins(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF64748B)),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              disabledBackgroundColor: const Color(0xFFE2E8F0),
                              disabledForegroundColor: const Color(0xFF94A3B8),
                            ),
                            icon: const Icon(Icons.check_rounded, size: 18),
                            onPressed: isValid
                                ? () {
                                    final name = _nameController.text.trim();
                                    final phone = _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim();
                                    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
                                    final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
                                    
                                    if (supplier == null) {
                                      context.read<SupplierCubit>().addSupplier(
                                        name: name,
                                        phone: phone,
                                        email: email,
                                        address: address,
                                      );
                                    } else {
                                      context.read<SupplierCubit>().editSupplier(
                                        supplier,
                                        name: name,
                                        phone: phone,
                                        email: email,
                                        address: address,
                                      );
                                    }
                                    Navigator.pop(ctx);
                                  }
                                : null,
                            label: Text(
                              supplier == null ? 'Simpan Pemasok' : 'Perbarui Pemasok',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Supplier supplier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hapus Pemasok',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        content: Text('Apakah Anda yakin ingin menghapus pemasok "${supplier.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: GoogleFonts.poppins(color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              context.read<SupplierCubit>().deleteSupplier(supplier.id);
              Navigator.pop(ctx);
            },
            child: Text('Hapus', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showAppSnackbar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocConsumer<SupplierCubit, SupplierState>(
            listener: (context, state) {
              if (state is SupplierSaved) {
                _showAppSnackbar(
                  context,
                  state.isEdit
                      ? 'Data pemasok "${state.supplierName}" berhasil diperbarui.'
                      : 'Pemasok "${state.supplierName}" berhasil ditambahkan.',
                );
              } else if (state is SupplierDeleted) {
                _showAppSnackbar(
                  context,
                  'Pemasok "${state.supplierName}" berhasil dihapus.',
                );
              } else if (state is SupplierError) {
                _showAppSnackbar(context, state.message, isError: true);
              }
            },
            builder: (context, state) {
              if (state is SupplierLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is SupplierError) {
                return Center(child: Text(state.message));
              }
              if (state is SupplierLoaded) {
                final list = state.suppliers;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada pemasok.',
                      style: GoogleFonts.poppins(color: const Color(0xFF94A3B8)),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.local_shipping_rounded, color: Color(0xFF059669), size: 20),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.phone != null && item.phone!.isNotEmpty)
                              Text(
                                item.phone!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            if (item.address != null && item.address!.isNotEmpty)
                              Text(
                                item.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(
                                  fontSize: 10.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, supplier: item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF334155),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Material(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showDeleteDialog(context, item),
                                child: const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFDC2626),
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }
              return const SizedBox();
            },
          ),
        ),
        
        // Add Button Bottom
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _showFormDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(
                'Tambah Pemasok',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
