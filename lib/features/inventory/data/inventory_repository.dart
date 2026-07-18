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

  // Mengambil seluruh unit satuan yang terdaftar untuk produk tertentu
  Future<List<ProductUnit>> getProductUnits(int productId) async {
    return await (_db.select(_db.productUnits)..where((tbl) => tbl.productId.equals(productId))).get();
  }

  // Mengambil log riwayat mutasi stok untuk produk tertentu dengan filter tanggal opsional
  Future<List<Map<String, dynamic>>> getStockMovements(int productId, {DateTime? start, DateTime? end}) async {
    final query = _db.select(_db.stockMovements)
      ..where((tbl) {
        var expr = tbl.productId.equals(productId);
        if (start != null) {
          expr = expr & tbl.createdAt.isBiggerOrEqualValue(start);
        }
        if (end != null) {
          expr = expr & tbl.createdAt.isSmallerOrEqualValue(end);
        }
        return expr;
      })
      ..orderBy([(t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)]);

    final rows = await query.join([
      innerJoin(_db.productUnits, _db.productUnits.id.equalsExp(_db.stockMovements.unitId)),
    ]).get();

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
      if (difference == 0) return;

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

      await _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: productId,
              unitId: unitId,
              quantity: difference,
              type: 'opname',
              notes: Value(notes ?? 'Stock Opname Penyesuaian'),
            ),
          );
    });
  }

  // Manual Stock Adjustment (Barang Masuk / Keluar Manual)
  Future<void> adjustStockManual({
    required int productId,
    required int unitId,
    required double quantity,
    required bool isAddition, // true = masuk, false = keluar
    String? notes,
  }) async {
    await _db.transaction(() async {
      final delta = isAddition ? quantity : -quantity;

      final existing = await (_db.select(_db.inventory)
            ..where((tbl) => tbl.productId.equals(productId) & tbl.unitId.equals(unitId)))
          .getSingleOrNull();

      if (existing == null) {
        if (!isAddition) {
          throw Exception('Stok tidak mencukupi untuk pengurangan manual');
        }
        await _db.into(_db.inventory).insert(
              InventoryCompanion.insert(
                productId: productId,
                unitId: unitId,
                quantity: Value(quantity),
              ),
            );
      } else {
        final newQty = existing.quantity + delta;
        if (newQty < 0) {
          throw Exception('Stok tidak mencukupi (tersisa ${existing.quantity})');
        }
        await _db.update(_db.inventory).replace(
              existing.copyWith(quantity: newQty),
            );
      }

      await _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              productId: productId,
              unitId: unitId,
              quantity: delta,
              type: isAddition ? 'manual_in' : 'manual_out',
              notes: Value(notes ?? (isAddition ? 'Penambahan Stok Manual' : 'Pengurangan Stok Manual')),
            ),
          );
    });
  }
}
