import 'dart:io';
import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../../core/database/app_database.dart';
import 'dummy_products_data.dart';
import 'dummy_coffee_raw_materials.dart';

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

  // ─── POINTS ────────────────────────────────────────────────────────
  Future<List<PointTransaction>> getPointsHistory(int customerId) async {
    return await (_db.select(_db.pointTransactions)
          ..where((tbl) => tbl.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .get();
  }

  Future<int> getCustomerPointsBalance(int customerId) async {
    final customer = await (_db.select(_db.customers)
          ..where((tbl) => tbl.id.equals(customerId)))
        .getSingleOrNull();
    return customer?.pointsBalance ?? 0;
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
    final recipes = await getProductRecipes(productId);

    return {
      'product': product,
      'brand': brand,
      'category': category,
      'units': units,
      'prices': prices,
      'recipes': recipes,
    };
  }

  // ─── RESEP / BILL OF MATERIALS (BOM) ────────────────────────────────

  // Mengambil daftar bahan baku yang terhubung dengan menu jadi (dengan nama bahan & satuannya)
  Future<List<Map<String, dynamic>>> getProductRecipes(int parentProductId) async {
    final query = _db.select(_db.productRecipes).join([
      innerJoin(
        _db.products,
        _db.products.id.equalsExp(_db.productRecipes.ingredientProductId),
        useColumns: true,
      ),
      innerJoin(
        _db.productUnits,
        _db.productUnits.id.equalsExp(_db.productRecipes.ingredientUnitId),
        useColumns: true,
      ),
    ])..where(_db.productRecipes.parentProductId.equals(parentProductId));

    final rows = await query.get();
    return rows.map((row) {
      return {
        'recipe': row.readTable(_db.productRecipes),
        'ingredientProduct': row.readTable(_db.products),
        'ingredientUnit': row.readTable(_db.productUnits),
      };
    }).toList();
  }

  // Mengambil produk bertipe bahan baku ('raw_material') untuk dipilih di form resep
  Future<List<Product>> getRawMaterialCandidates() async {
    return await (_db.select(_db.products)
          ..where((tbl) => tbl.productType.equals('raw_material') & tbl.isActive.equals(true))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();
  }

  // Mengambil daftar bahan baku lengkap untuk halaman Master Bahan Baku
  Future<List<Map<String, dynamic>>> getRawMaterialsWithDetails() async {
    final rawProducts = await (_db.select(_db.products)
          ..where((tbl) => tbl.productType.equals('raw_material'))
          ..orderBy([(t) => OrderingTerm(expression: t.name)]))
        .get();

    final List<Map<String, dynamic>> results = [];
    for (var prod in rawProducts) {
      final units = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.productId.equals(prod.id)))
          .get();
      
      final category = prod.categoryId != null
          ? await (_db.select(_db.categories)..where((tbl) => tbl.id.equals(prod.categoryId!))).getSingleOrNull()
          : null;

      results.add({
        'product': prod,
        'units': units,
        'category': category,
      });
    }
    return results;
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

  // Menyimpan Produk baru beserta Units, Prices (Pricing Matrix), dan Resep Bahan Baku (BOM)
  Future<int> insertProductComplete({
    required ProductsCompanion product,
    required List<ProductUnitsCompanion> units,
    required List<ProductPricesCompanion> prices,
    List<ProductRecipesCompanion> recipes = const [],
  }) async {
    return await _db.transaction(() async {
      // 0. Pastikan setidaknya ada default PriceTier (misal: 'Harga Umum' id 1)
      final existingTiers = await _db.select(_db.priceTiers).get();
      int defaultTierId = 1;
      if (existingTiers.isEmpty) {
        defaultTierId = await _db.into(_db.priceTiers).insert(
          PriceTiersCompanion.insert(name: 'Harga Umum'),
        );
      } else {
        defaultTierId = existingTiers.first.id;
      }

      // 1. Insert product
      final productId = await _db.into(_db.products).insert(product);

      // 2. Insert units & map old/temp ids
      final unitIdMap = <int, int>{}; // Temporary ID -> Database ID
      for (var unit in units) {
        final companion = unit.copyWith(
          productId: Value(productId),
          id: const Value.absent(), // Biarkan SQLite auto-increment ID yang valid
        );
        final unitId = await _db.into(_db.productUnits).insert(companion);
        if (unit.id.present) {
          unitIdMap[unit.id.value] = unitId;
        }
      }

      // 3. Insert prices
      for (var price in prices) {
        final tempUnitId = price.unitId.value;
        final realUnitId = unitIdMap[tempUnitId] ?? tempUnitId;
        
        final tierIdToUse = price.priceTierId.present && price.priceTierId.value > 0
            ? price.priceTierId.value
            : defaultTierId;

        final companion = price.copyWith(
          productId: Value(productId),
          unitId: Value(realUnitId),
          priceTierId: Value(tierIdToUse),
          id: const Value.absent(),
        );
        await _db.into(_db.productPrices).insert(companion);
      }

      // 4. Insert recipes (jika ada)
      for (var recipe in recipes) {
        final companion = recipe.copyWith(
          parentProductId: Value(productId),
          id: const Value.absent(),
        );
        await _db.into(_db.productRecipes).insert(companion);
      }

      return productId;
    });
  }

  // Mengubah data Produk beserta unit, harga, dan resepnya dalam satu transaksi aman
  Future<void> updateProductComplete({
    required Product product,
    required List<ProductUnitsCompanion> units,
    required List<ProductPricesCompanion> prices,
    List<ProductRecipesCompanion> recipes = const [],
  }) async {
    await _db.transaction(() async {
      // 1. Update product info
      await _db.update(_db.products).replace(product);

      // Get currently stored units for this product
      final existingUnitsInDb = await (_db.select(_db.productUnits)
            ..where((tbl) => tbl.productId.equals(product.id)))
          .get();
      final existingUnitIds = existingUnitsInDb.map((u) => u.id).toSet();

      // We will map incoming (possibly temporary/fake) IDs to the real generated/reused database IDs
      final unitIdMap = <int, int>{};
      final incomingUsedUnitIds = <int>{};

      // 2. Process units (update or insert)
      for (var unit in units) {
        final hasValidId = unit.id.present && existingUnitIds.contains(unit.id.value);

        if (hasValidId) {
          // Existing unit: Update it
          final companion = unit.copyWith(
            productId: Value(product.id),
          );
          await (_db.update(_db.productUnits)
                ..where((tbl) => tbl.id.equals(unit.id.value)))
              .write(companion);
          
          unitIdMap[unit.id.value] = unit.id.value;
          incomingUsedUnitIds.add(unit.id.value);
        } else {
          // New unit: Insert it
          final companion = unit.copyWith(
            productId: Value(product.id),
            id: const Value.absent(), // auto increment
          );
          final newUnitId = await _db.into(_db.productUnits).insert(companion);
          if (unit.id.present) {
            unitIdMap[unit.id.value] = newUnitId;
          }
        }
      }

      // 3. Delete units that are not in the incoming list
      final unitsToDelete = existingUnitIds.difference(incomingUsedUnitIds);
      if (unitsToDelete.isNotEmpty) {
        await (_db.delete(_db.productUnits)
              ..where((tbl) => tbl.id.isIn(unitsToDelete)))
            .go();
      }

      // 4. Delete existing prices for this product and insert new ones
      await (_db.delete(_db.productPrices)
            ..where((tbl) => tbl.productId.equals(product.id)))
          .go();

      // 5. Insert new prices mapping unit IDs appropriately
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

      // 6. Delete existing recipes and insert new ones
      await (_db.delete(_db.productRecipes)
            ..where((tbl) => tbl.parentProductId.equals(product.id)))
          .go();

      for (var recipe in recipes) {
        final companion = recipe.copyWith(
          parentProductId: Value(product.id),
          id: const Value.absent(),
        );
        await _db.into(_db.productRecipes).insert(companion);
      }
    });
  }

  // Hapus produk (cascade delete diatur di tabel Drift)
  Future<int> deleteProduct(int id) async {
    return await (_db.delete(_db.products)..where((tbl) => tbl.id.equals(id))).go();
  }

  // Reset / Bersihkan seluruh data katalog produk master (produk, satuan, harga matriks, resep, inventori)
  Future<void> resetMasterCatalogData() async {
    await _db.transaction(() async {
      await _db.delete(_db.productRecipes).go();
      await _db.delete(_db.productPrices).go();
      await _db.delete(_db.inventory).go();
      await _db.delete(_db.stockMovements).go();
      await _db.delete(_db.productUnits).go();
      await _db.delete(_db.products).go();
    });
  }

  // Seed data dummy master (100 Produk Terkategori Lengkap dengan Foto & Satuan)
  Future<int> seedDummyData({void Function(int current, int total)? onProgress}) async {
    // 0. Pastikan PriceTier default 'Harga Umum' dan 'Harga Grosir' ada
    final existingTiers = await _db.select(_db.priceTiers).get();
    int defaultTierId = 1;
    if (existingTiers.isEmpty) {
      defaultTierId = await _db.into(_db.priceTiers).insert(
        PriceTiersCompanion.insert(name: 'Harga Umum'),
      );
      await _db.into(_db.priceTiers).insert(
        PriceTiersCompanion.insert(name: 'Harga Grosir'),
      );
    } else {
      defaultTierId = existingTiers.first.id;
    }

    // 1. Kategori Mapping Cache
    final categoryMap = <String, int>{};
    final categoriesList = await _db.select(_db.categories).get();
    for (var c in categoriesList) {
      categoryMap[c.name] = c.id;
    }

    // 2. Brand Mapping Cache
    final brandMap = <String, int>{};
    final brandsList = await _db.select(_db.brands).get();
    for (var b in brandsList) {
      brandMap[b.name] = b.id;
    }

    // 3. Insert Customers & Suppliers jika belum ada
    final existingCustomers = await _db.select(_db.customers).get();
    if (existingCustomers.isEmpty) {
      await _db.into(_db.customers).insert(
        CustomersCompanion.insert(name: 'Budi Santoso (Member VIP)', phone: const Value('081234567890'), address: const Value('Jl. Merdeka No. 12')),
      );
      await _db.into(_db.customers).insert(
        CustomersCompanion.insert(name: 'Siti Aminah (Grosir)', phone: const Value('089876543210'), address: const Value('Ruko Harmony Blok C')),
      );
      await _db.into(_db.customers).insert(
        CustomersCompanion.insert(name: 'Warung Bu Joko', phone: const Value('085712349999'), address: const Value('Jl. Pasar Baru No. 45')),
      );
    }

    final existingSuppliers = await _db.select(_db.suppliers).get();
    if (existingSuppliers.isEmpty) {
      await _db.into(_db.suppliers).insert(
        SuppliersCompanion.insert(name: 'PT Indomarco Adi Prima', phone: const Value('021-5551234'), address: const Value('Kawasan Industri Pulogadung')),
      );
      await _db.into(_db.suppliers).insert(
        SuppliersCompanion.insert(name: 'CV Makmur Sejahtera Distributor', phone: const Value('031-7778889'), address: const Value('Raya Dupak, Surabaya')),
      );
      await _db.into(_db.suppliers).insert(
        SuppliersCompanion.insert(name: 'PT Unilever Trading Indonesia', phone: const Value('021-8889999'), address: const Value('BSD City, Tangerang')),
      );
    }

    int insertedCount = 0;
    final totalItems = DummyDataGenerator.raw100Products.length;

    // Loop 100 produk dan insert bertahap
    for (int i = 0; i < totalItems; i++) {
      final item = DummyDataGenerator.raw100Products[i];

      // Dapatkan atau buat Kategori
      int? catId = categoryMap[item.category];
      if (catId == null) {
        catId = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(name: item.category),
        );
        categoryMap[item.category] = catId;
      }

      // Dapatkan atau buat Brand
      int? brandId = brandMap[item.brand];
      if (brandId == null) {
        brandId = await _db.into(_db.brands).insert(
          BrandsCompanion.insert(name: item.brand),
        );
        brandMap[item.brand] = brandId;
      }

      // Generate Image PNG lokal untuk produk
      final imagePath = await DummyDataGenerator.generateProductImage(
        name: item.name,
        category: item.category,
        color: item.badgeColor,
        shortCode: item.shortCode,
      );

      // Cek apakah produk dengan barcode/SKU ini sudah ada untuk mencegah duplikat
      final existingProd = await (_db.select(_db.products)
            ..where((tbl) => tbl.barcode.equals(item.barcode) | tbl.sku.equals(item.sku)))
          .getSingleOrNull();

      if (existingProd != null) {
        // Jika sudah ada, update gambar jika belum ada
        if (existingProd.imagePath == null && imagePath != null) {
          await (_db.update(_db.products)..where((tbl) => tbl.id.equals(existingProd.id)))
              .write(ProductsCompanion(imagePath: Value(imagePath)));
        }
        insertedCount++;
        onProgress?.call(i + 1, totalItems);
        continue;
      }

      // Insert Produk Baru beserta Satuan dan Harga dalam transaksi
      await _db.transaction(() async {
        final prodId = await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            name: item.name,
            sku: Value(item.sku),
            barcode: Value(item.barcode),
            categoryId: Value(catId),
            brandId: Value(brandId),
            imagePath: Value(imagePath),
            productType: const Value('goods'),
            businessSegment: const Value('retail'),
            isStockManaged: const Value(true),
            minStockAlert: Value(item.minStock),
            allowManualPrice: const Value(false),
            isActive: const Value(true),
          ),
        );

        // Insert Satuan Dasar
        final unitBaseId = await _db.into(_db.productUnits).insert(
          ProductUnitsCompanion.insert(
            productId: prodId,
            name: item.unitBase,
            conversionFactor: const Value(1.0),
            isBase: const Value(true),
          ),
        );

        // Insert Harga Satuan Dasar (Eceran & Grosir min 10)
        await _db.into(_db.productPrices).insert(
          ProductPricesCompanion.insert(
            productId: prodId,
            unitId: unitBaseId,
            priceTierId: defaultTierId,
            price: Value(item.sellPrice),
            minQty: const Value(1),
          ),
        );

        if (item.grosirPrice > 0 && item.grosirPrice < item.sellPrice) {
          await _db.into(_db.productPrices).insert(
            ProductPricesCompanion.insert(
              productId: prodId,
              unitId: unitBaseId,
              priceTierId: defaultTierId,
              price: Value(item.grosirPrice),
              minQty: const Value(5),
            ),
          );
        }

        // Insert Satuan Turunan jika ada (misal: Dus, Slop, Karton, Rim)
        if (item.unitSub != null && item.conversion > 1) {
          final unitSubId = await _db.into(_db.productUnits).insert(
            ProductUnitsCompanion.insert(
              productId: prodId,
              name: item.unitSub!,
              conversionFactor: Value(item.conversion),
              isBase: const Value(false),
            ),
          );

          final subPrice = item.grosirSubPrice > 0 ? item.grosirSubPrice : (item.sellPrice * item.conversion * 0.95);
          await _db.into(_db.productPrices).insert(
            ProductPricesCompanion.insert(
              productId: prodId,
              unitId: unitSubId,
              priceTierId: defaultTierId,
              price: Value(subPrice),
              minQty: const Value(1),
            ),
          );
        }

        // Inisialisasi stok awal inventori (50 unit)
        await _db.into(_db.inventory).insert(
          InventoryCompanion.insert(
            productId: prodId,
            unitId: unitBaseId,
            quantity: const Value(50.0),
          ),
        );
      });

      insertedCount++;
      onProgress?.call(i + 1, totalItems);
    }

    return insertedCount;
  }

  // ─── SEED DUMMY BAHAN BAKU KEDAI KOPI (RAW MATERIALS) ───────────────
  Future<int> seedCoffeeRawMaterials({Function(int current, int total)? onProgress}) async {
    // 1. Dapatkan atau buat Default Price Tier (Harga Umum)
    final existingTiers = await _db.select(_db.priceTiers).get();
    int defaultTierId = 1;
    if (existingTiers.isEmpty) {
      defaultTierId = await _db.into(_db.priceTiers).insert(
        PriceTiersCompanion.insert(name: 'Harga Umum'),
      );
    } else {
      defaultTierId = existingTiers.first.id;
    }

    // 2. Cache Kategori Bahan Baku
    final categories = await _db.select(_db.categories).get();
    final categoryMap = {for (var c in categories) c.name: c.id};

    int insertedCount = 0;
    final totalItems = CoffeeShopDummyData.rawMaterials.length;

    for (int i = 0; i < totalItems; i++) {
      final item = CoffeeShopDummyData.rawMaterials[i];

      // Dapatkan atau buat Kategori
      int? catId = categoryMap[item.category];
      if (catId == null) {
        catId = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(name: item.category),
        );
        categoryMap[item.category] = catId;
      }

      // Cek apakah bahan baku dengan nama ini sudah ada
      final existingProd = await (_db.select(_db.products)
            ..where((tbl) => tbl.name.equals(item.name) & tbl.productType.equals('raw_material')))
          .getSingleOrNull();

      if (existingProd != null) {
        insertedCount++;
        onProgress?.call(i + 1, totalItems);
        continue;
      }

      // Insert Bahan Baku Baru beserta Satuan, Harga Modal, dan Saldo Stok Awal
      await _db.transaction(() async {
        final prodId = await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            name: item.name,
            categoryId: Value(catId),
            productType: const Value('raw_material'),
            businessSegment: const Value('fnb'),
            isStockManaged: const Value(true),
            minStockAlert: Value(item.minStock),
            allowManualPrice: const Value(false),
            isActive: const Value(true),
            hasRecipe: const Value(false),
          ),
        );

        // Satuan Unit (Gram, Ml, Pcs, dll)
        final unitId = await _db.into(_db.productUnits).insert(
          ProductUnitsCompanion.insert(
            productId: prodId,
            name: item.unitName,
            conversionFactor: const Value(1.0),
            costPrice: Value(item.costPrice),
            isBase: const Value(true),
          ),
        );

        // Matriks Harga Dasar (Harga Modal)
        await _db.into(_db.productPrices).insert(
          ProductPricesCompanion.insert(
            productId: prodId,
            unitId: unitId,
            priceTierId: defaultTierId,
            price: Value(item.costPrice),
            minQty: const Value(1),
          ),
        );

        // Inisialisasi Saldo Stok Fisik Awal
        await _db.into(_db.inventory).insert(
          InventoryCompanion.insert(
            productId: prodId,
            unitId: unitId,
            quantity: Value(item.initialStock),
          ),
        );

        // Catat di Mutasi Stok Masuk Awal
        await _db.into(_db.stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: prodId,
            unitId: unitId,
            quantity: item.initialStock,
            type: 'opname',
            notes: const Value('Saldo stok awal bahan baku kedai kopi dummy'),
          ),
        );
      });

      insertedCount++;
      onProgress?.call(i + 1, totalItems);
    }

    return insertedCount;
  }

  // ─── SEED DUMMY MENU F&B KEDAI KOPI (DENGAN RESEP RACIKAN / BOM) ───────
  Future<int> seedCoffeeMenuProducts({Function(int current, int total)? onProgress}) async {
    // 1. Pastikan seluruh bahan baku kedai kopi sudah ter-seed
    await seedCoffeeRawMaterials();

    // 2. Dapatkan atau buat Default Price Tier (Harga Umum)
    final existingTiers = await _db.select(_db.priceTiers).get();
    int defaultTierId = 1;
    if (existingTiers.isEmpty) {
      defaultTierId = await _db.into(_db.priceTiers).insert(
        PriceTiersCompanion.insert(name: 'Harga Umum'),
      );
    } else {
      defaultTierId = existingTiers.first.id;
    }

    // 3. Cache Kategori & Brand
    final categories = await _db.select(_db.categories).get();
    final categoryMap = {for (var c in categories) c.name: c.id};

    final brands = await _db.select(_db.brands).get();
    final brandMap = {for (var b in brands) b.name: b.id};

    // 4. Cache Raw Material Products & Base Units
    final rawProds = await (_db.select(_db.products)
          ..where((tbl) => tbl.productType.equals('raw_material')))
        .get();
    final rawProdMap = {for (var p in rawProds) p.name: p.id};

    final allUnits = await _db.select(_db.productUnits).get();
    final rawProdBaseUnitMap = <int, int>{};
    for (var u in allUnits) {
      if (u.isBase) {
        rawProdBaseUnitMap[u.productId] = u.id;
      }
    }

    int insertedCount = 0;
    final totalItems = CoffeeShopDummyData.menuProducts.length;

    for (int i = 0; i < totalItems; i++) {
      final item = CoffeeShopDummyData.menuProducts[i];

      // Dapatkan atau buat Kategori
      int? catId = categoryMap[item.category];
      if (catId == null) {
        catId = await _db.into(_db.categories).insert(
          CategoriesCompanion.insert(name: item.category),
        );
        categoryMap[item.category] = catId;
      }

      // Dapatkan atau buat Brand
      int? brandId = brandMap[item.brand];
      if (brandId == null) {
        brandId = await _db.into(_db.brands).insert(
          BrandsCompanion.insert(name: item.brand),
        );
        brandMap[item.brand] = brandId;
      }

      // Generate Image PNG lokal untuk menu F&B
      final imagePath = await DummyDataGenerator.generateProductImage(
        name: item.name,
        category: item.category,
        color: item.badgeColor,
        shortCode: item.shortCode,
      );

      // Cek apakah produk dengan barcode/SKU sudah ada
      final existingProd = await (_db.select(_db.products)
            ..where((tbl) => tbl.barcode.equals(item.barcode) | tbl.sku.equals(item.sku)))
          .getSingleOrNull();

      if (existingProd != null) {
        if (existingProd.imagePath == null && imagePath != null) {
          await (_db.update(_db.products)..where((tbl) => tbl.id.equals(existingProd.id)))
              .write(ProductsCompanion(imagePath: Value(imagePath)));
        }
        insertedCount++;
        onProgress?.call(i + 1, totalItems);
        continue;
      }

      // Insert Produk Menu F&B beserta Satuan, Harga Jual, dan Komposisi Resep BOM
      await _db.transaction(() async {
        final prodId = await _db.into(_db.products).insert(
          ProductsCompanion.insert(
            name: item.name,
            sku: Value(item.sku),
            barcode: Value(item.barcode),
            categoryId: Value(catId),
            brandId: Value(brandId),
            productType: const Value('goods'),
            businessSegment: const Value('fnb'),
            imagePath: Value(imagePath),
            isStockManaged: const Value(false), // Menu F&B stok dikontrol via bahan baku (BOM)
            hasRecipe: const Value(true), // Menandakan menu ini memotong stok bahan baku
            isActive: const Value(true),
          ),
        );

        // Satuan Jual Utama (Cup / Porsi)
        final unitId = await _db.into(_db.productUnits).insert(
          ProductUnitsCompanion.insert(
            productId: prodId,
            name: item.unitName,
            conversionFactor: const Value(1.0),
            isBase: const Value(true),
          ),
        );

        // Matriks Harga Jual Satuan (Eceran & Grosir)
        await _db.into(_db.productPrices).insert(
          ProductPricesCompanion.insert(
            productId: prodId,
            unitId: unitId,
            priceTierId: defaultTierId,
            price: Value(item.sellPrice),
            minQty: const Value(1),
          ),
        );

        if (item.grosirPrice > 0 && item.grosirPrice < item.sellPrice) {
          await _db.into(_db.productPrices).insert(
            ProductPricesCompanion.insert(
              productId: prodId,
              unitId: unitId,
              priceTierId: defaultTierId,
              price: Value(item.grosirPrice),
              minQty: const Value(5),
            ),
          );
        }

        // Simpan Komposisi Resep (BOM) untuk setiap bahan baku terkait
        for (final ing in item.recipe) {
          final ingProdId = rawProdMap[ing.rawMaterialName];
          if (ingProdId != null) {
            final ingUnitId = rawProdBaseUnitMap[ingProdId];
            if (ingUnitId != null) {
              await _db.into(_db.productRecipes).insert(
                ProductRecipesCompanion.insert(
                  parentProductId: prodId,
                  ingredientProductId: ingProdId,
                  ingredientUnitId: ingUnitId,
                  quantityRequired: ing.quantity,
                  notes: Value(ing.notes),
                ),
              );
            }
          }
        }
      });

      insertedCount++;
      onProgress?.call(i + 1, totalItems);
    }

    return insertedCount;
  }
}

