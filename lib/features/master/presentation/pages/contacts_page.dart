import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
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
                        'Pelanggan & Pemasok',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // TabBar Container
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.white,
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      unselectedLabelStyle: GoogleFonts.poppins(
                        fontWeight: FontWeight.normal,
                        fontSize: 14,
                      ),
                      tabs: const [
                        Tab(text: 'Pelanggan'),
                        Tab(text: 'Pemasok (Supplier)'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

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
        ],
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              customer == null ? 'Tambah Pelanggan' : 'Ubah Pelanggan',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Pelanggan *',
                            errorText: (hasInteractedName && !isNameValid) ? 'Nama wajib diisi' : null,
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedName = true;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Telepon',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: (hasInteractedEmail && !isEmailValid) ? 'Format email tidak valid' : null,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedEmail = true;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Alamat',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                            child: const Text('SIMPAN'),
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
        title: const Text('Hapus Pelanggan'),
        content: Text('Apakah Anda yakin ingin menghapus pelanggan "${customer.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<CustomerCubit>().deleteCustomer(customer.id);
              Navigator.pop(ctx);
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<CustomerCubit, CustomerState>(
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
                      style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        side: const BorderSide(color: AppConstants.borderLightColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppConstants.primaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.person_outline_rounded,
                              color: AppConstants.primaryColor, size: 18),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.phone != null)
                              Text(
                                item.phone!,
                                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                              ),
                            if (item.address != null)
                              Text(
                                item.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                              ),
                            if (item.pointsBalance > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Row(
                                  children: [
                                    const Icon(Icons.card_giftcard_rounded,
                                        size: 11, color: AppConstants.warningColor),
                                    const SizedBox(width: 3),
                                    Text(
                                      'Poin: ${item.pointsBalance}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: AppConstants.warningColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: AppConstants.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, customer: item),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: AppConstants.primaryColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.redAccent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showDeleteDialog(context, item),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
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
          child: ElevatedButton.icon(
            onPressed: () => _showFormDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('TAMBAH PELANGGAN'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
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
                borderRadius: BorderRadius.circular(16),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              supplier == null ? 'Tambah Pemasok' : 'Ubah Pemasok',
                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nama Pemasok *',
                            errorText: (hasInteractedName && !isNameValid) ? 'Nama wajib diisi' : null,
                          ),
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedName = true;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Nomor Telepon',
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: (hasInteractedEmail && !isEmailValid) ? 'Format email tidak valid' : null,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            setModalState(() {
                              hasInteractedEmail = true;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Alamat',
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                            child: const Text('SIMPAN'),
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
        title: const Text('Hapus Pemasok'),
        content: Text('Apakah Anda yakin ingin menghapus pemasok "${supplier.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<SupplierCubit>().deleteSupplier(supplier.id);
              Navigator.pop(ctx);
            },
            child: const Text('HAPUS'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: BlocBuilder<SupplierCubit, SupplierState>(
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
                      style: GoogleFonts.poppins(color: AppConstants.textLightColor),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                        side: const BorderSide(color: AppConstants.borderLightColor),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppConstants.successColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.local_shipping_outlined,
                              color: AppConstants.successColor, size: 18),
                        ),
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (item.phone != null)
                              Text(
                                item.phone!,
                                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                              ),
                            if (item.address != null)
                              Text(
                                item.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.poppins(fontSize: 11, color: AppConstants.textLightColor),
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: AppConstants.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, supplier: item),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    color: AppConstants.primaryColor,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.redAccent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showDeleteDialog(context, item),
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
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
          child: ElevatedButton.icon(
            onPressed: () => _showFormDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('TAMBAH PEMASOK'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}
