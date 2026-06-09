import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';

class MasterRepository {
  final AppDatabase _db;

  MasterRepository(this._db);

  // ─── CATEGORIES CRUD ───────────────────────────────────────────────
  Future<List<Category>> getCategories() async {
    return await _db.select(_db.categories).get();
  }

  Future<int> insertCategory(CategoriesCompanion category) async {
    return await _db.into(_db.categories).insert(category);
  }

  Future<bool> updateCategory(Category category) async {
    return await _db.update(_db.categories).replace(category);
  }

  Future<int> deleteCategory(int id) async {
    return await (_db.delete(_db.categories)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ─── BRANDS CRUD ──────────────────────────────────────────────────
  Future<List<Brand>> getBrands() async {
    return await _db.select(_db.brands).get();
  }

  Future<int> insertBrand(BrandsCompanion brand) async {
    return await _db.into(_db.brands).insert(brand);
  }

  Future<bool> updateBrand(Brand brand) async {
    return await _db.update(_db.brands).replace(brand);
  }

  Future<int> deleteBrand(int id) async {
    return await (_db.delete(_db.brands)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ─── CUSTOMERS CRUD ────────────────────────────────────────────────
  Future<List<Customer>> getCustomers() async {
    return await _db.select(_db.customers).get();
  }

  Future<int> insertCustomer(CustomersCompanion customer) async {
    return await _db.into(_db.customers).insert(customer);
  }

  Future<bool> updateCustomer(Customer customer) async {
    return await _db.update(_db.customers).replace(customer);
  }

  Future<int> deleteCustomer(int id) async {
    return await (_db.delete(_db.customers)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ─── SUPPLIERS CRUD ────────────────────────────────────────────────
  Future<List<Supplier>> getSuppliers() async {
    return await _db.select(_db.suppliers).get();
  }

  Future<int> insertSupplier(SuppliersCompanion supplier) async {
    return await _db.into(_db.suppliers).insert(supplier);
  }

  Future<bool> updateSupplier(Supplier supplier) async {
    return await _db.update(_db.suppliers).replace(supplier);
  }

  Future<int> deleteSupplier(int id) async {
    return await (_db.delete(_db.suppliers)..where((tbl) => tbl.id.equals(id))).go();
  }

  // ─── PRICE TIERS ──────────────────────────────────────────────────
  Future<List<PriceTier>> getPriceTiers() async {
    return await _db.select(_db.priceTiers).get();
  }

  // ─── PRODUCTS & MATRIX CRUD ────────────────────────────────────────

  // Mengambil daftar produk lengkap beserta Brand & Category
  Future<List<Map<String, dynamic>>> getProductsWithDetails() async {
    final query = _db.select(_db.products).join([
      leftOuterJoin(_db.brands, _db.brands.id.equalsExp(_db.products.brandId)),
      leftOuterJoin(_db.categories, _db.categories.id.equalsExp(_db.products.categoryId)),
    ]);
    
    final rows = await query.get();
    return rows.map((row) {
      return {
        'product': row.readTable(_db.products),
        'brand': row.readTableOrNull(_db.brands),
        'category': row.readTableOrNull(_db.categories),
      };
    }).toList();
  }

  // Mengambil satu produk lengkap beserta units dan pricing matrix-nya
  Future<Map<String, dynamic>?> getProductComplete(int productId) async {
    final product = await (_db.select(_db.products)..where((tbl) => tbl.id.equals(productId))).getSingleOrNull();
    if (product == null) return null;

    final brand = product.brandId != null 
        ? await (_db.select(_db.brands)..where((tbl) => tbl.id.equals(product.brandId!))).getSingleOrNull()
        : null;

    final category = product.categoryId != null 
        ? await (_db.select(_db.categories)..where((tbl) => tbl.id.equals(product.categoryId!))).getSingleOrNull()
        : null;

    final units = await (_db.select(_db.productUnits)..where((tbl) => tbl.productId.equals(productId))).get();
    final prices = await (_db.select(_db.productPrices)..where((tbl) => tbl.productId.equals(productId))).get();

    return {
      'product': product,
      'brand': brand,
      'category': category,
      'units': units,
      'prices': prices,
    };
  }

  // Simpan/salin file gambar yang dipilih ke direktori dokumen aplikasi
  Future<String?> saveProductImage(File imageFile) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final productsDir = Directory(p.join(appDir.path, 'product_images'));
      if (!await productsDir.exists()) {
        await productsDir.create(recursive: true);
      }
      final extension = p.extension(imageFile.path);
      final fileName = 'img_${DateTime.now().microsecondsSinceEpoch}$extension';
      final savedFile = await imageFile.copy(p.join(productsDir.path, fileName));
      return savedFile.path;
    } catch (e) {
      return null;
    }
  }

  // Menyimpan Produk baru beserta Units dan Prices (Pricing Matrix) dalam satu transaksi aman
  Future<int> insertProductComplete({
    required ProductsCompanion product,
    required List<ProductUnitsCompanion> units,
    required List<ProductPricesCompanion> prices,
  }) async {
    return await _db.transaction(() async {
      // 1. Insert product
      final productId = await _db.into(_db.products).insert(product);

      // 2. Insert units & map old/temp ids if necessary, or just insert them with the correct productId
      final unitIdMap = <int, int>{}; // Temporary ID -> Database ID
      for (var unit in units) {
        final companion = unit.copyWith(
          productId: Value(productId),
        );
        final unitId = await _db.into(_db.productUnits).insert(companion);
        // Kita berasumsi list unit diinput secara urut dan bisa di-map,
        // namun untuk mempermudah pricing, kita map menggunakan id sementara yang dikirim UI
        if (unit.id.present) {
          unitIdMap[unit.id.value] = unitId;
        }
      }

      // 3. Insert prices
      for (var price in prices) {
        final tempUnitId = price.unitId.value;
        final realUnitId = unitIdMap[tempUnitId] ?? tempUnitId;
        
        final companion = price.copyWith(
          productId: Value(productId),
          unitId: Value(realUnitId),
        );
        await _db.into(_db.productPrices).insert(companion);
      }

      return productId;
    });
  }

  // Mengubah data Produk beserta unit & harganya dalam satu transaksi aman
  Future<void> updateProductComplete({
    required Product product,
    required List<ProductUnitsCompanion> units,
    required List<ProductPricesCompanion> prices,
  }) async {
    await _db.transaction(() async {
      // 1. Update product info
      await _db.update(_db.products).replace(product);

      // 2. Hapus unit & harga lama untuk di-insert ulang secara bersih
      await (_db.delete(_db.productUnits)..where((tbl) => tbl.productId.equals(product.id))).go();
      await (_db.delete(_db.productPrices)..where((tbl) => tbl.productId.equals(product.id))).go();

      // 3. Insert unit baru
      final unitIdMap = <int, int>{};
      for (var unit in units) {
        final companion = unit.copyWith(
          productId: Value(product.id),
          id: const Value.absent(), // Biarkan auto increment baru
        );
        final unitId = await _db.into(_db.productUnits).insert(companion);
        if (unit.id.present) {
          unitIdMap[unit.id.value] = unitId;
        }
      }

      // 4. Insert harga baru
      for (var price in prices) {
        final tempUnitId = price.unitId.value;
        final realUnitId = unitIdMap[tempUnitId] ?? tempUnitId;

        final companion = price.copyWith(
          productId: Value(product.id),
          unitId: Value(realUnitId),
          id: const Value.absent(),
        );
        await _db.into(_db.productPrices).insert(companion);
      }
    });
  }

  // Hapus produk (cascade delete diatur di tabel Drift)
  Future<int> deleteProduct(int id) async {
    return await (_db.delete(_db.products)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Seed data dummy master
  Future<void> seedDummyData() async {
    await _db.transaction(() async {
      // 1. Insert Categories
      final catIdMakanan = await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(name: 'Makanan', description: const Value('Aneka makanan instan & snack')),
      );
      final catIdMinuman = await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(name: 'Minuman', description: const Value('Minuman bersoda & air mineral')),
      );
      await _db.into(_db.categories).insert(
        CategoriesCompanion.insert(name: 'Kebutuhan Harian', description: const Value('Peralatan mandi & pembersih rumah')),
      );

      // 2. Insert Brands
      final brandIdIndofood = await _db.into(_db.brands).insert(
        BrandsCompanion.insert(name: 'Indofood'),
      );
      final brandIdCoke = await _db.into(_db.brands).insert(
        BrandsCompanion.insert(name: 'Coca-Cola'),
      );
      await _db.into(_db.brands).insert(
        BrandsCompanion.insert(name: 'Unilever'),
      );

      // 3. Insert Customers
      await _db.into(_db.customers).insert(
        CustomersCompanion.insert(name: 'Budi Santoso', phone: const Value('081234567890'), address: const Value('Jl. Merdeka No. 12')),
      );
      await _db.into(_db.customers).insert(
        CustomersCompanion.insert(name: 'Siti Aminah', phone: const Value('089876543210'), address: const Value('Ruko Harmony Blok C')),
      );

      // 4. Insert Suppliers
      await _db.into(_db.suppliers).insert(
        SuppliersCompanion.insert(name: 'PT Indomarco Adi Prima', phone: const Value('021-5551234'), address: const Value('Kawasan Industri Pulogadung')),
      );
      await _db.into(_db.suppliers).insert(
        SuppliersCompanion.insert(name: 'CV Makmur Sejahtera', phone: const Value('031-7778889'), address: const Value('Raya Dupak, Surabaya')),
      );

      // 5. Insert Product 1: Indomie Goreng
      final p1Id = await _db.into(_db.products).insert(
        ProductsCompanion.insert(
          name: 'Indomie Goreng',
          sku: const Value('IND-GOR-01'),
          barcode: const Value('89686011118'),
          categoryId: Value(catIdMakanan),
          brandId: Value(brandIdIndofood),
          isStockManaged: const Value(true),
          minStockAlert: const Value(10),
        ),
      );
      final u1BaseId = await _db.into(_db.productUnits).insert(
        ProductUnitsCompanion.insert(productId: p1Id, name: 'Pcs', conversionFactor: const Value(1.0), isBase: const Value(true)),
      );
      final u1SubId = await _db.into(_db.productUnits).insert(
        ProductUnitsCompanion.insert(productId: p1Id, name: 'Dus', conversionFactor: const Value(40.0), isBase: const Value(false)),
      );
      // Quantity breaks for Pcs
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p1Id, unitId: u1BaseId, priceTierId: 1, price: const Value(3500.0), minQty: const Value(1)));
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p1Id, unitId: u1BaseId, priceTierId: 1, price: const Value(3300.0), minQty: const Value(10)));
      // Quantity breaks for Dus
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p1Id, unitId: u1SubId, priceTierId: 1, price: const Value(130000.0), minQty: const Value(1)));
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p1Id, unitId: u1SubId, priceTierId: 1, price: const Value(125000.0), minQty: const Value(5)));

      // 6. Insert Product 2: Coca-Cola
      final p2Id = await _db.into(_db.products).insert(
        ProductsCompanion.insert(
          name: 'Coca-Cola Can 330ml',
          sku: const Value('COKE-CAN-01'),
          barcode: const Value('8886001300224'),
          categoryId: Value(catIdMinuman),
          brandId: Value(brandIdCoke),
          isStockManaged: const Value(true),
          minStockAlert: const Value(12),
        ),
      );
      final u2BaseId = await _db.into(_db.productUnits).insert(
        ProductUnitsCompanion.insert(productId: p2Id, name: 'Can', conversionFactor: const Value(1.0), isBase: const Value(true)),
      );
      final u2SubId = await _db.into(_db.productUnits).insert(
        ProductUnitsCompanion.insert(productId: p2Id, name: 'Pack', conversionFactor: const Value(6.0), isBase: const Value(false)),
      );
      // Quantity breaks for Can
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p2Id, unitId: u2BaseId, priceTierId: 1, price: const Value(6500.0), minQty: const Value(1)));
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p2Id, unitId: u2BaseId, priceTierId: 1, price: const Value(6000.0), minQty: const Value(12)));
      // Quantity breaks for Pack
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p2Id, unitId: u2SubId, priceTierId: 1, price: const Value(37000.0), minQty: const Value(1)));
      await _db.into(_db.productPrices).insert(ProductPricesCompanion.insert(productId: p2Id, unitId: u2SubId, priceTierId: 1, price: const Value(34000.0), minQty: const Value(3)));
    });
  }
}
