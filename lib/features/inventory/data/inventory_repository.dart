import 'package:drift/drift.dart';
import '../../../core/database/app_database.dart';

class InventoryRepository {
  final AppDatabase _db;

  InventoryRepository(this._db);

  // Mengambil daftar produk + unit dan kuantitas stok berjalannya (jika null, dianggap 0)
  Future<List<Map<String, dynamic>>> getProductUnitsWithStock() async {
    final query = _db.select(_db.productUnits).join([
      innerJoin(_db.products, _db.products.id.equalsExp(_db.productUnits.productId)),
      leftOuterJoin(
        _db.inventory,
        _db.inventory.productId.equalsExp(_db.productUnits.productId) &
            _db.inventory.unitId.equalsExp(_db.productUnits.id),
      ),
    ]);
    
    final rows = await query.get();
    return rows.map((row) {
      return {
        'product': row.readTable(_db.products),
        'unit': row.readTable(_db.productUnits),
        'inventory': row.readTableOrNull(_db.inventory),
      };
    }).toList();
  }

  // Mengambil log riwayat mutasi stok untuk produk tertentu
  Future<List<Map<String, dynamic>>> getStockMovements(int productId) async {
    final query = (_db.select(_db.stockMovements)
          ..where((tbl) => tbl.productId.equals(productId))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]))
        .join([
      innerJoin(_db.productUnits, _db.productUnits.id.equalsExp(_db.stockMovements.unitId)),
    ]);

    final rows = await query.get();
    return rows.map((row) {
      return {
        'movement': row.readTable(_db.stockMovements),
        'unit': row.readTable(_db.productUnits),
      };
    }).toList();
  }

  // Melakukan Stock Opname (Penyesuaian Stok Fisik)
  Future<void> adjustStock({
    required int productId,
    required int unitId,
    required double theoreticalQty,
    required double physicalQty,
    String? notes,
  }) async {
    await _db.transaction(() async {
      final difference = physicalQty - theoreticalQty;
      if (difference == 0) return; // Tidak ada selisih, tidak perlu simpan

      // 1. Update atau Insert stok di tabel inventory
      final existing = await (_db.select(_db.inventory)
            ..where((tbl) => tbl.productId.equals(productId) & tbl.unitId.equals(unitId)))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.inventory).insert(
              InventoryCompanion.insert(
                productId: productId,
                unitId: unitId,
                quantity: Value(physicalQty),
              ),
            );
      } else {
        await _db.update(_db.inventory).replace(
              existing.copyWith(quantity: physicalQty),
            );
      }

      // 2. Catat riwayat di tabel stock_movements
      await _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: productId,
              unitId: unitId,
              quantity: difference, // Bisa positif (masuk) atau negatif (keluar)
              type: 'opname',
              notes: Value(notes ?? 'Stock Opname Penyesuaian'),
            ),
          );
    });
  }
}
