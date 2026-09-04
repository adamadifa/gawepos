import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/master/data/master_repository.dart';
import 'package:posmobile/features/master/data/dummy_products_data.dart';

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
    });
  });
}
