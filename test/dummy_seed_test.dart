import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/master/data/master_repository.dart';
import 'package:posmobile/features/master/data/dummy_products_data.dart';
import 'package:posmobile/features/inventory/data/inventory_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MasterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MasterRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('Dummy 100 Products Seeder Tests', () {
    test('Daftar raw100Products memiliki lebih dari 90 produk unik', () {
      final items = DummyDataGenerator.raw100Products;
      expect(items.length, greaterThanOrEqualTo(90));
      
      final barcodSet = <String>{};
      for (var it in items) {
        expect(barcodSet.contains(it.barcode), isFalse, reason: 'Barcode ${it.barcode} duplikat');
        barcodSet.add(it.barcode);
      }
    });

    test('seedDummyData berhasil meng-insert kategori, brand, units, dan harga', () async {
      final count = await repo.seedDummyData();
      expect(count, greaterThan(50));

      final prods = await repo.getProductsWithDetails();
      expect(prods.length, equals(count));

      final cats = await repo.getCategories();
      expect(cats.length, greaterThanOrEqualTo(5));

      final brands = await repo.getBrands();
      expect(brands.length, greaterThanOrEqualTo(5));

      final invRepo = InventoryRepository(db);
      final invItems = await invRepo.getProductUnitsWithStock();
      expect(invItems.length, greaterThan(50));
      expect(invItems.first.containsKey('product'), isTrue);
      expect(invItems.first.containsKey('unit'), isTrue);
    });

    test('seedCoffeeRawMaterials berhasil membuat 23 bahan baku kedai kopi dengan saldo stok', () async {
      final count = await repo.seedCoffeeRawMaterials();
      expect(count, equals(23));

      final rawMats = await repo.getRawMaterialsWithDetails();
      expect(rawMats.length, equals(23));

      // Verifikasi salah satu bahan baku (Espresso Blend)
      final espresso = rawMats.firstWhere(
        (m) => (m['product'] as Product).name.contains('Espresso Blend'),
      );
      final espressoProd = espresso['product'] as Product;
      final espressoUnits = espresso['units'] as List<ProductUnit>;

      expect(espressoProd.productType, equals('raw_material'));
      expect(espressoUnits.first.name, equals('Gram'));
      expect(espressoUnits.first.costPrice, equals(220.0));

      // Verifikasi stok awal masuk ke tabel inventory
      final invList = await (db.select(db.inventory)..where((t) => t.productId.equals(espressoProd.id))).get();
      expect(invList.isNotEmpty, isTrue);
      expect(invList.first.quantity, equals(10000.0)); // 10 Kg
    });

    test('seedCoffeeMenuProducts berhasil membuat 15 menu F&B lengkap beserta komposisi resep BOM', () async {
      final count = await repo.seedCoffeeMenuProducts();
      expect(count, equals(15));

      // Verifikasi produk jadi F&B masuk ke tabel products
      final allProds = await db.select(db.products).get();
      final fnbProds = allProds.where((p) => p.productType == 'goods' && p.hasRecipe == true).toList();
      expect(fnbProds.length, equals(15));

      // Verifikasi resep BOM untuk "Es Kopi Susu Gula Aren (Signature)"
      final kopiSusu = fnbProds.firstWhere((p) => p.name.contains('Es Kopi Susu Gula Aren'));
      expect(kopiSusu.hasRecipe, isTrue);
      expect(kopiSusu.isStockManaged, isFalse);

      final recipes = await (db.select(db.productRecipes)
            ..where((tbl) => tbl.parentProductId.equals(kopiSusu.id)))
          .get();
      expect(recipes.length, equals(6)); // 6 bahan: espresso, milk, aren, cup, lid, sedotan

      // Verifikasi harga jual menu
      final prices = await (db.select(db.productPrices)
            ..where((tbl) => tbl.productId.equals(kopiSusu.id)))
          .get();
      expect(prices.isNotEmpty, isTrue);
      expect(prices.first.price, equals(18000.0));
    });
  });
}
