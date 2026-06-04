import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/widgets/curved_header.dart';
import '../bloc/category_cubit.dart';
import '../bloc/brand_cubit.dart';

class CategoriesBrandsPage extends StatefulWidget {
  const CategoriesBrandsPage({super.key});

  @override
  State<CategoriesBrandsPage> createState() => _CategoriesBrandsPageState();
}

class _CategoriesBrandsPageState extends State<CategoriesBrandsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    context.read<CategoryCubit>().loadCategories();
    context.read<BrandCubit>().loadBrands();
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
                        'Kategori & Merek',
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
                        Tab(text: 'Kategori'),
                        Tab(text: 'Merek (Brand)'),
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
                      _CategoryTabContent(),
                      _BrandTabContent(),
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

// ─── CATEGORY TAB CONTENT ───────────────────────────────────────────
class _CategoryTabContent extends StatelessWidget {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();

  void _showFormDialog(BuildContext context, {Category? category}) {
    if (category != null) {
      _nameController.text = category.name;
      _descController.text = category.description ?? '';
    } else {
      _nameController.clear();
      _descController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedName = category != null;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isNameValid = _nameController.text.trim().isNotEmpty;
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SafeArea(
                top: false,
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
                            category == null ? 'Tambah Kategori' : 'Ubah Kategori',
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
                          labelText: 'Nama Kategori *',
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
                        controller: _descController,
                        decoration: const InputDecoration(
                          labelText: 'Deskripsi',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isNameValid
                              ? () {
                                  final name = _nameController.text.trim();
                                  if (category == null) {
                                    context.read<CategoryCubit>().addCategory(
                                      name,
                                      _descController.text.trim().isEmpty ? null : _descController.text.trim(),
                                    );
                                  } else {
                                    context.read<CategoryCubit>().editCategory(
                                      category,
                                      name,
                                      _descController.text.trim().isEmpty ? null : _descController.text.trim(),
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
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Kategori'),
        content: Text('Apakah Anda yakin ingin menghapus kategori "${category.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<CategoryCubit>().deleteCategory(category.id);
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
        // Content Area
        Expanded(
          child: BlocBuilder<CategoryCubit, CategoryState>(
            builder: (context, state) {
              if (state is CategoryLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is CategoryError) {
                return Center(child: Text(state.message));
              }
              if (state is CategoryLoaded) {
                final list = state.categories;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada kategori.',
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
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        subtitle: item.description != null
                            ? Text(
                                item.description!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: AppConstants.textLightColor,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: AppConstants.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, category: item),
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
            label: const Text('TAMBAH KATEGORI'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── BRAND TAB CONTENT ──────────────────────────────────────────────
class _BrandTabContent extends StatelessWidget {
  final _nameController = TextEditingController();

  void _showFormDialog(BuildContext context, {Brand? brand}) {
    if (brand != null) {
      _nameController.text = brand.name;
    } else {
      _nameController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        bool hasInteractedName = brand != null;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isNameValid = _nameController.text.trim().isNotEmpty;
            return Container(
              margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: SafeArea(
                top: false,
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
                            brand == null ? 'Tambah Merek' : 'Ubah Merek',
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
                          labelText: 'Nama Merek *',
                          errorText: (hasInteractedName && !isNameValid) ? 'Nama wajib diisi' : null,
                        ),
                        onChanged: (_) {
                          setModalState(() {
                            hasInteractedName = true;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isNameValid
                              ? () {
                                  final name = _nameController.text.trim();
                                  if (brand == null) {
                                    context.read<BrandCubit>().addBrand(name);
                                  } else {
                                    context.read<BrandCubit>().editBrand(brand, name);
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
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Brand brand) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Merek'),
        content: Text('Apakah Anda yakin ingin menghapus merek "${brand.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('BATAL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<BrandCubit>().deleteBrand(brand.id);
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
        // Content Area
        Expanded(
          child: BlocBuilder<BrandCubit, BrandState>(
            builder: (context, state) {
              if (state is BrandLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state is BrandError) {
                return Center(child: Text(state.message));
              }
              if (state is BrandLoaded) {
                final list = state.brands;
                if (list.isEmpty) {
                  return Center(
                    child: Text(
                      'Belum ada merek (brand).',
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
                        title: Text(
                          item.name,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppConstants.textDarkColor,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Material(
                              color: AppConstants.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _showFormDialog(context, brand: item),
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
            label: const Text('TAMBAH MEREK'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}
