import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:posmobile/core/database/app_database.dart';
import 'package:posmobile/features/master/data/master_repository.dart';

void main() {
  late AppDatabase db;
  late MasterRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = MasterRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('MasterRepository Product CRUD Tests', () {
    test('insertProductComplete menyimpan produk, unit, dan harga tanpa error PriceTier', () async {
      final productCompanion = ProductsCompanion.insert(
        name: 'Kopi Susu Gula Aren',
        sku: const drift.Value('KOP-001'),
        barcode: const drift.Value('899123456789'),
        productType: const drift.Value('goods'),
        isStockManaged: const drift.Value(true),
        minStockAlert: const drift.Value(5),
      );

      final units = [
        ProductUnitsCompanion.insert(
          id: const drift.Value(1),
          productId: 0,
          name: 'Cup',
          conversionFactor: const drift.Value(1.0),
          isBase: const drift.Value(true),
        ),
      ];

      final prices = [
        ProductPricesCompanion.insert(
          id: const drift.Value(1),
          productId: 0,
          unitId: 1,
          priceTierId: 1,
          price: const drift.Value(18000.0),
          minQty: const drift.Value(1),
        ),
      ];

      final newId = await repo.insertProductComplete(
        product: productCompanion,
        units: units,
        prices: prices,
      );

      expect(newId > 0, isTrue);

      final detail = await repo.getProductComplete(newId);
      expect(detail != null, isTrue);
      expect((detail!['product'] as Product).name, equals('Kopi Susu Gula Aren'));
      expect((detail['units'] as List).length, equals(1));
      expect((detail['prices'] as List).length, equals(1));
      expect((detail['prices'] as List<ProductPrice>).first.price, equals(18000.0));
    });
  });
}
