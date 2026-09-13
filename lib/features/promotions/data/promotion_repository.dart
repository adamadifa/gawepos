import 'package:drift/drift.dart';
import 'package:posmobile/core/database/app_database.dart';

class PromotionRepository {
  final AppDatabase _db;

  PromotionRepository(this._db);

  // Ambil semua data promosi (diurutkan dari yang terbaru dibuat)
  Future<List<Promotion>> getAllPromotions() async {
    return await (_db.select(_db.promotions)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // Ambil semua promosi yang sedang aktif hari ini dan statusnya true
  Future<List<Promotion>> getActivePromotions() async {
    final now = DateTime.now();
    return await (_db.select(_db.promotions)
          ..where((t) =>
              t.isActive.equals(true) &
              t.startDate.isSmallerOrEqualValue(now) &
              t.endDate.isBiggerOrEqualValue(now))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
          ]))
        .get();
  }

  // Ambil promosi berdasarkan ID
  Future<Promotion?> getPromotionById(int id) async {
    return await (_db.select(_db.promotions)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  // Tambah promosi baru
  Future<int> insertPromotion(PromotionsCompanion promotion) async {
    return await _db.into(_db.promotions).insert(promotion);
  }

  // Update promosi
  Future<bool> updatePromotion(PromotionsCompanion promotion) async {
    return await _db.update(_db.promotions).replace(promotion);
  }

  // Toggle status aktif/non-aktif
  Future<int> togglePromotionActive(int id, bool isActive) async {
    return await (_db.update(_db.promotions)..where((t) => t.id.equals(id)))
        .write(PromotionsCompanion(
      isActive: Value(isActive),
    ));
  }

  // Hapus promosi
  Future<int> deletePromotion(int id) async {
    return await (_db.delete(_db.promotions)..where((t) => t.id.equals(id))).go();
  }

  // Ambil histori promosi berdasarkan Order ID
  Future<List<OrderPromotion>> getPromotionsByOrderId(int orderId) async {
    return await (_db.select(_db.orderPromotions)
          ..where((t) => t.orderId.equals(orderId)))
        .get();
  }
}
